import AVFoundation
import Speech
import SwiftUI

struct VoiceClip {
    let url: URL
    let transcript: String
    let duration: TimeInterval
    var note = ""
}

@MainActor
final class VoiceInput: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var seconds = 0
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var permissionGates: [UUID: VoicePermissionGate] = [:]
    private var recognitionID: UUID?
    private var recognitionContinuation: CheckedContinuation<String, Error>?
    private var recognitionTimeout: Task<Void, Never>?
    private var recordingURL: URL?
    private var startedAt: Date?
    private var timer: Task<Void, Never>?
    private var startID = UUID()
    #if os(iOS)
    private var interruptionObserver: NSObjectProtocol?
    #endif

    override init() {
        super.init()
        #if os(iOS)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance(), queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            Task { @MainActor in self?.discardInterruptedRecording() }
        }
        #endif
    }

    deinit {
        timer?.cancel()
        recognitionTimeout?.cancel()
        recognitionTask?.cancel()
        recorder?.stop()
        if let recordingURL { try? FileManager.default.removeItem(at: recordingURL) }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        #endif
    }

    func start() async {
        guard !isRecording, !isTranscribing else { return }
        discardPendingRecording()
        errorMessage = nil
        let id = UUID()
        startID = id
        var activatedAudioSession = false
        var newURL: URL?
        do {
            try Task.checkCancellation()
            guard try await requestMicrophonePermission() else {
                throw VoiceInputError.permission(microphonePermissionMessage())
            }
            try Task.checkCancellation()
            guard startID == id else { return }
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            activatedAudioSession = true
            #endif
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice-\(UUID().uuidString).m4a")
            newURL = url
            let audioRecorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ])
            audioRecorder.delegate = self
            guard audioRecorder.prepareToRecord(), audioRecorder.record(forDuration: 60) else {
                throw VoiceInputError.recording
            }
            recorder = audioRecorder
            recordingURL = url
            startedAt = Date()
            seconds = 0
            isRecording = true
            timer = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard let self, self.isRecording else { return }
                    self.seconds = min(60, Int(Date().timeIntervalSince(self.startedAt ?? Date())))
                    if self.seconds >= 60 { self.stopRecording() }
                }
            }
        } catch {
            #if os(iOS)
            if activatedAudioSession {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
            #endif
            if let newURL { try? FileManager.default.removeItem(at: newURL) }
            if startID == id, !(error is CancellationError) { errorMessage = error.localizedDescription }
        }
    }

    func finish() async -> VoiceClip? {
        guard let url = recordingURL else { return nil }
        let duration = min(60, startedAt.map { Date().timeIntervalSince($0) } ?? 0)
        stopRecording()
        guard let audio = try? AVAudioFile(forReading: url), audio.length > 0,
              audio.fileFormat.sampleRate > 0,
              Double(audio.length) / audio.fileFormat.sampleRate <= 60 else {
            errorMessage = VoiceInputError.emptyAudio.localizedDescription
            discardPendingRecording()
            return nil
        }
        isTranscribing = true
        defer { isTranscribing = false }
        do {
            let transcript = try await transcribeFile(at: url)
            recordingURL = nil
            startedAt = nil
            return VoiceClip(url: url, transcript: transcript, duration: duration)
        } catch {
            if error is CancellationError {
                try? FileManager.default.removeItem(at: url)
                if recordingURL == url { recordingURL = nil; startedAt = nil }
                return nil
            }
            recordingURL = nil
            startedAt = nil
            return VoiceClip(url: url, transcript: "", duration: duration, note: error.localizedDescription)
        }
    }

    func cancel() {
        startID = UUID()
        stopRecording()
        for gate in permissionGates.values { gate.resolve(.failure(CancellationError())) }
        if let id = recognitionID { finishRecognition(id, with: .failure(CancellationError())) }
        discardPendingRecording()
        seconds = 0
        errorMessage = nil
    }

    func transcribeFile(at url: URL) async throws -> String {
        try Task.checkCancellation()
        let audio = try AVAudioFile(forReading: url)
        guard audio.fileFormat.sampleRate > 0 else { throw VoiceInputError.emptyAudio }
        guard audio.length > 0 else { throw VoiceInputError.emptyAudio }
        guard Double(audio.length) / audio.fileFormat.sampleRate <= 60 else {
            throw VoiceInputError.tooLong
        }
        guard try await requestSpeechPermission() else {
            throw VoiceInputError.permission(speechPermissionMessage())
        }
        try Task.checkCancellation()
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt_BR")),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            throw VoiceInputError.unavailable
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                recognitionID = id
                recognitionContinuation = continuation
                recognitionTimeout = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(30))
                    guard !Task.isCancelled else { return }
                    self?.finishRecognition(id, with: .failure(VoiceInputError.timeout))
                }
                recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    guard let error else {
                        guard let result, result.isFinal else { return }
                        Task { @MainActor in
                            self?.finishRecognition(id, with: .success(result.bestTranscription.formattedString))
                        }
                        return
                    }
                    Task { @MainActor in self?.finishRecognition(id, with: .failure(error)) }
                }
            }
        } onCancel: {
            Task { @MainActor in self.finishRecognition(id, with: .failure(CancellationError())) }
        }
    }

    private func finishRecognition(_ id: UUID, with result: Result<String, Error>) {
        guard recognitionID == id, let continuation = recognitionContinuation else { return }
        recognitionID = nil
        recognitionContinuation = nil
        recognitionTimeout?.cancel()
        recognitionTimeout = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        continuation.resume(with: result)
    }

    private func discardPendingRecording() {
        if let recordingURL { try? FileManager.default.removeItem(at: recordingURL) }
        recordingURL = nil
        startedAt = nil
    }

    private func discardInterruptedRecording() {
        stopRecording()
        discardPendingRecording()
        seconds = 0
        errorMessage = "A gravação foi interrompida e descartada. Toque no microfone para tentar novamente."
    }

    private func stopRecording() {
        timer?.cancel()
        timer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func requestMicrophonePermission() async throws -> Bool {
        if AVAudioApplication.shared.recordPermission == .granted { return true }
        guard AVAudioApplication.shared.recordPermission == .undetermined else { return false }
        return try await requestPermission(kind: .microphone) { callback in
            AVAudioApplication.requestRecordPermission(completionHandler: callback)
        }
    }

    private func requestSpeechPermission() async throws -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .notDetermined:
            return try await requestPermission(kind: .speech) { callback in
                SFSpeechRecognizer.requestAuthorization { callback($0 == .authorized) }
            }
        default: return false
        }
    }

    private func requestPermission(kind: VoicePermissionKind,
                                   start: (@escaping @Sendable (Bool) -> Void) -> Void) async throws -> Bool {
        try Task.checkCancellation()
        let gate = VoicePermissionGate()
        permissionGates[gate.id] = gate
        defer { permissionGates[gate.id] = nil }
        do {
            return try await gate.wait(timeout: .seconds(30), start: start)
        } catch is VoicePermissionTimedOut {
            throw VoiceInputError.permissionTimedOut(kind)
        }
    }

    private func speechPermissionMessage() -> String {
        #if os(macOS)
        return "Ative Reconhecimento de Fala em Ajustes do Sistema > Privacidade e Segurança > Reconhecimento de Fala."
        #else
        return "Permita o reconhecimento de fala nos Ajustes para transcrever."
        #endif
    }

    private func microphonePermissionMessage() -> String {
        #if os(macOS)
        return "Permita o acesso ao microfone em Ajustes do Sistema > Privacidade e Segurança > Microfone."
        #else
        return "Permita o acesso ao microfone nos Ajustes para gravar."
        #endif
    }
}

extension VoiceInput: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            guard self.recorder === recorder else { return }
            self.isRecording = false
            self.timer?.cancel()
            if !flag {
                self.discardPendingRecording()
                self.seconds = 0
                self.errorMessage = VoiceInputError.recording.localizedDescription
            }
        }
    }
}

private enum VoiceInputError: LocalizedError {
    case permission(String), permissionTimedOut(VoicePermissionKind), unavailable, recording, emptyAudio, tooLong, timeout
    var errorDescription: String? {
        switch self {
        case .permission(let message): return message
        case .permissionTimedOut(let kind): return kind.message
        case .unavailable: return "O reconhecimento offline em português do Brasil não está disponível neste dispositivo. A gravação não será enviada para a internet."
        case .recording: return "Não foi possível gravar o áudio. Verifique a permissão do microfone e tente novamente."
        case .emptyAudio: return "O áudio está vazio. Grave novamente antes de transcrever."
        case .tooLong: return "O áudio precisa ter no máximo 60 segundos."
        case .timeout: return "Não foi possível concluir a transcrição offline. Tente novamente."
        }
    }
}

enum VoicePermissionKind: Equatable {
    case microphone, speech
    var message: String {
        #if os(macOS)
        return self == .microphone
            ? "A permissão do microfone demorou. Confira Ajustes do Sistema > Privacidade e Segurança > Microfone."
            : "A permissão de fala demorou. Confira Ajustes do Sistema > Privacidade e Segurança > Reconhecimento de Fala."
        #else
        return self == .microphone
            ? "A permissão do microfone demorou. Confira Ajustes > Privacidade e Segurança > Microfone."
            : "A permissão de fala demorou. Confira Ajustes > Privacidade e Segurança > Reconhecimento de Fala."
        #endif
    }
}

struct VoicePermissionTimedOut: LocalizedError {
    var errorDescription: String? { "A solicitação de permissão expirou." }
}

@MainActor
final class VoicePermissionGate {
    let id = UUID()
    private var continuation: CheckedContinuation<Bool, Error>?
    private var result: Result<Bool, Error>?
    private var timeoutTask: Task<Void, Never>?
    private(set) var completionCount = 0

    func wait(timeout: Duration = .seconds(30),
              start: (@escaping @Sendable (Bool) -> Void) -> Void) async throws -> Bool {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if let result { continuation.resume(with: result); return }
                self.continuation = continuation
                timeoutTask = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: timeout) } catch { return }
                    self?.resolve(.failure(VoicePermissionTimedOut()))
                }
                guard !Task.isCancelled else {
                    resolve(.failure(CancellationError()))
                    return
                }
                start { [weak self] granted in
                    Task { @MainActor in self?.resolve(.success(granted)) }
                }
            }
        } onCancel: {
            Task { @MainActor in self.resolve(.failure(CancellationError())) }
        }
    }

    func resolve(_ result: Result<Bool, Error>) {
        guard self.result == nil else { return }
        self.result = result
        completionCount += 1
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation?.resume(with: result)
        continuation = nil
    }
}
