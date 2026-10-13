import Foundation
import UniformTypeIdentifiers
import PDFKit
import AVFoundation

struct ChatAttachment: Identifiable {
    enum Kind { case image, document, audio }
    let id = UUID()
    let name: String
    let kind: Kind
    var text: String
    var note: String = ""
    var audio: Data?
    var duration: TimeInterval = 0
    var symbol: String {
        switch kind {
        case .image: return "photo.fill"
        case .document: return "doc.text.fill"
        case .audio: return "waveform"
        }
    }
}

enum ChatAttachmentError: LocalizedError {
    case tooLarge, unsupported, unreadable, scannedPDF
    var errorDescription: String? {
        switch self {
        case .tooLarge: return "Escolha um arquivo de até 20 MB."
        case .unsupported: return "Envie uma imagem, PDF com texto, TXT ou áudio de até 1 minuto."
        case .unreadable: return "Não consegui ler este arquivo. Tente outro formato ou copie o texto na mensagem."
        case .scannedPDF: return "Este PDF não tem texto selecionável. Envie um print das páginas com a oferta."
        }
    }
}

enum ChatAttachmentReader {

    static func read(data: Data, type: UTType, name: String) async throws -> ChatAttachment {
        guard data.count <= 20 * 1024 * 1024 else { throw ChatAttachmentError.tooLarge }
        try Task.checkCancellation()
        if type.conforms(to: .image) {
            return ChatAttachment(name: name, kind: .image, text: try await PhotoTextRecognizer.read(data))
        }
        let result = try await Task.detached(priority: .userInitiated) {
            let text: String
            var note = ""
            if type.conforms(to: .pdf) {
                guard let document = PDFDocument(data: data), !document.isLocked else { throw ChatAttachmentError.unreadable }
                // shortcut: só texto nas primeiras 20 páginas; usar OCR de PDF quando houver demanda.
                text = (0..<min(document.pageCount, 20)).compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
                if document.pageCount > 20 { note = "Leitura limitada às primeiras 20 páginas." }
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ChatAttachmentError.scannedPDF }
            } else if type.conforms(to: .plainText) {
                guard let decoded = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else { throw ChatAttachmentError.unreadable }
                text = decoded
            } else { throw ChatAttachmentError.unsupported }
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ChatAttachmentError.unreadable }
            if text.count > 30_000 { note += (note.isEmpty ? "" : " ") + "Texto limitado a 30 mil caracteres." }
            return ChatAttachment(name: name, kind: .document, text: String(text.prefix(30_000)), note: note)
        }.value
        try Task.checkCancellation()
        return result
    }
}

@MainActor
final class ChatAudioPlayer: ObservableObject {
    @Published private(set) var playingID: UUID?
    @Published private(set) var preparingID: UUID?
    @Published var errorMessage: String?
    private var player: AVPlayer?
    private var temporaryURL: URL?
    private var ended: NSObjectProtocol?
    private var status: NSKeyValueObservation?
    private var itemStatus: NSKeyValueObservation?
    private var preparation: Task<Void, Never>?
    private var timeout: Task<Void, Never>?
    private var generation = UUID()

    deinit {
        preparation?.cancel(); timeout?.cancel()
        if let ended { NotificationCenter.default.removeObserver(ended) }
        if let temporaryURL { try? FileManager.default.removeItem(at: temporaryURL) }
    }

    func toggle(_ attachment: ChatAttachment) {
        errorMessage = nil
        if playingID == attachment.id || preparingID == attachment.id { stop(); return }
        stop()
        guard let data = attachment.audio else { return }
        let token = generation
        preparingID = attachment.id
        preparation = Task { [self] in
            let suffix = URL(fileURLWithPath: attachment.name).pathExtension
            let ext = suffix.range(of: "^[a-zA-Z0-9]+$", options: .regularExpression) != nil ? suffix : "m4a"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("PontosLoop-play-\(UUID()).\(ext)")
            do {
                try await Task.detached { try data.write(to: url, options: .atomic) }.value
                guard !Task.isCancelled, generation == token else { try? FileManager.default.removeItem(at: url); return }
                temporaryURL = url
                #if os(iOS)
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
                #endif
                // AVPlayer inicia de forma assíncrona; AVAudioPlayer.play bloqueou o HAL no Mac de teste.
                let item = AVPlayerItem(url: url)
                let next = AVPlayer(playerItem: item)
                player = next
                ended = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                    Task { @MainActor in if self?.generation == token { self?.stop() } }
                }
                itemStatus = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                    guard item.status == .failed else { return }
                    Task { @MainActor in self?.failed(token) }
                }
                status = next.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
                    guard player.timeControlStatus == .playing else { return }
                    Task { @MainActor in
                        guard let self, self.generation == token else { return }
                        self.preparingID = nil; self.playingID = attachment.id; self.timeout?.cancel()
                    }
                }
                timeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(10)) } catch { return }
                    self?.failed(token)
                }
                next.play()
            } catch {
                try? FileManager.default.removeItem(at: url)
                if !Task.isCancelled { failed(token) }
            }
        }
    }

    private func failed(_ token: UUID) {
        guard generation == token else { return }
        stop()
        errorMessage = "Não consegui reproduzir este áudio. Confira a saída de som e tente novamente."
    }

    func stop() {
        generation = UUID()
        preparation?.cancel(); preparation = nil
        timeout?.cancel(); timeout = nil
        status = nil; itemStatus = nil
        if let ended { NotificationCenter.default.removeObserver(ended) }
        ended = nil
        player?.pause(); player = nil
        if let temporaryURL { try? FileManager.default.removeItem(at: temporaryURL) }
        temporaryURL = nil
        playingID = nil; preparingID = nil
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}
