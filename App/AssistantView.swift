import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import DecisionCore
#if os(macOS)
import AppKit
#endif

private struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let fromUser: Bool
    var attachments: [ChatAttachment] = []
}

struct AssistantView: View {
    let input: InputState
    @State private var question = ""
    @State private var messages: [ChatMessage] = []
    @State private var attachments: [ChatAttachment] = []
    @State private var photos: [PhotosPickerItem] = []
    @State private var checkoutBatch: CheckoutBatch?
    @State private var checkoutComparison: Comparison?
    @State private var checkoutSummary = ""
    @State private var dropTargeted = false
    @State private var showFile = false
    @State private var reading = false
    @State private var startingVoice = false
    @State private var capturing = false
    @State private var readTask: Task<Void, Never>?
    @State private var error: String?
    @StateObject private var voice = VoiceInput()
    @StateObject private var playback = ChatAudioPlayer()
    @FocusState private var editing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let suggestions = ["Diagnóstico dos 4 cenários", "Já ganho pontos na fatura?", "Como usar uma foto?"]
    private var busy: Bool { reading || startingVoice || voice.isRecording || voice.isTranscribing || capturing }
    private var canSend: Bool { !busy && (!question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if messages.isEmpty { introduction } else { conversationHeader }
                        ForEach(messages) { message in bubble(message) }
                        Color.clear.frame(height: 1).id("chatBottom")
                    }
                    .padding(24).frame(maxWidth: 780).frame(maxWidth: .infinity)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { proxy.scrollTo("chatBottom", anchor: .bottom) }
                }
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
                .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            }
            .background(AppTheme.canvas)
            .navigationTitle("Noah")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                Button("Nova conversa", systemImage: "square.and.pencil", action: clear)
                    .disabled(messages.isEmpty && attachments.isEmpty && question.isEmpty && !busy)
                    .accessibilityIdentifier("newChat")
            }
        }
        #if os(iOS)
        .fileImporter(isPresented: $showFile, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): loadFiles(urls)
            case .failure(let failure): error = failure.localizedDescription
            }
        }
        #endif
        .onChange(of: photos) { _, items in
            guard !items.isEmpty else { return }
            loadMany {
                var results: [ChatAttachment] = []
                for (index, item) in items.enumerated() {
                    try Task.checkCancellation()
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw PhotoReadError.invalidImage }
                    results.append(try await ChatAttachmentReader.read(data: data, type: .image, name: "Foto \(index + 1)"))
                }
                return results
            }
        }
        .onDrop(of: [UTType.fileURL, .image], isTargeted: $dropTargeted, perform: receiveDrop)
        .overlay {
            if dropTargeted {
                Label("Solte até 4 prints aqui", systemImage: "photo.stack")
                    .font(.title2.bold()).padding(30).background(AppTheme.ink, in: RoundedRectangle(cornerRadius: 25))
                    .overlay(RoundedRectangle(cornerRadius: 25).stroke(AppTheme.silver, lineWidth: 2))
                    .allowsHitTesting(false)
            }
        }
        .sheet(item: $checkoutBatch) { batch in
            CheckoutReviewView(attachments: batch.attachments) { comparison, summary in
                checkoutComparison = comparison; checkoutSummary = summary
                messages.append(ChatMessage(text: summary, fromUser: false))
            }
        }
        .onChange(of: voice.errorMessage) { _, value in if let value { error = value } }
        .onChange(of: playback.errorMessage) { _, value in if let value { error = value } }
        .onChange(of: input) { _, _ in checkoutComparison = nil; checkoutSummary = "" }
        .onChange(of: voice.isRecording) { old, new in
            if old && !new && capturing {
                if voice.errorMessage == nil { finishRecording() } else { capturing = false }
            }
        }
        .onDisappear {
            capturing = false; readTask?.cancel(); reading = false
            voice.cancel(); playback.stop()
        }
        .alert("Não foi possível concluir", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil; voice.errorMessage = nil }
        } message: { Text(error ?? "") }
    }

    private var avatar: some View {
        Image(systemName: "waveform.path")
            .font(.system(size: 27, weight: .semibold)).foregroundStyle(AppTheme.silver)
            .frame(width: 58, height: 58)
            .background(LinearGradient(colors: [.white.opacity(0.15), .white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 21))
            .overlay(RoundedRectangle(cornerRadius: 21).strokeBorder(.white.opacity(0.12)))
            .accessibilityHidden(true)
    }

    private var localStatus: some View {
        Label("Neste aparelho", systemImage: "lock.shield")
            .font(.caption.weight(.medium)).foregroundStyle(AppTheme.silver)
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(.white.opacity(0.06), in: Capsule())
    }

    private var conversationHeader: some View {
        HStack(spacing: 12) {
            avatar.scaleEffect(0.8).frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text("Seu próximo passo, mais claro.").font(.headline)
                Text("Noah · assistente do Pontos Loop").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { avatar; Spacer(); localStatus }
            VStack(alignment: .leading, spacing: 10) {
                Text("Vamos fazer uma\nboa escolha?")
                    .font(.system(.title, design: .rounded).bold())
                Text("Sou o Noah. Me conte sua dúvida, grave um áudio ou mande uma oferta para comparar.")
                    .font(.subheadline).foregroundStyle(AppTheme.silver).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                #if os(iOS)
                PhotosPicker(selection: $photos, maxSelectionCount: max(1, 4 - attachments.count), matching: .images) { Label("Fotos", systemImage: "photo.stack") }.accessibilityLabel("Comparar uma foto")
                #else
                Button { chooseFiles() } label: { Label("Fotos", systemImage: "photo.stack") }.accessibilityLabel("Comparar uma foto")
                #endif
                Button { chooseFiles() } label: { Label("Arquivo", systemImage: "paperclip") }
            }
            .buttonStyle(.bordered).controlSize(.large).font(.subheadline).disabled(busy)
            Text("Respostas locais sobre a calculadora. Os valores dos anexos passam pela sua revisão.")
                .font(.caption).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                Text("POR ONDE COMEÇAR").font(.caption2.bold()).tracking(1.5).foregroundStyle(.secondary)
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button { send(suggestion) } label: {
                                HStack(spacing: 10) {
                                    Text(suggestion)
                                    Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                                }
                                .font(.subheadline.weight(.medium)).padding(15)
                                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain).disabled(busy)
                        }
                    }
                }.scrollIndicators(.hidden)
            }
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [AppTheme.card, AppTheme.ink], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 30))
        .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(.white.opacity(0.07)))
    }

    private func bubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if message.fromUser { Spacer(minLength: 26) }
            if !message.fromUser {
                Image(systemName: "waveform.path").font(.caption.bold()).foregroundStyle(AppTheme.silver)
                    .frame(width: 29, height: 29).background(AppTheme.card, in: Circle()).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text(message.fromUser ? "VOCÊ" : "NOAH").font(.caption2.bold()).tracking(1.4).foregroundStyle(.secondary)
                ForEach(message.attachments) { attached in attachmentCard(attached, draft: false) }
                if message.attachments.contains(where: { $0.kind != .audio || hasOffer($0.text) }) {
                    Button("Conferir e comparar estas ofertas") { checkoutBatch = CheckoutBatch(attachments: message.attachments) }
                        .buttonStyle(.bordered).accessibilityIdentifier("reviewChatOffer")
                }
                if !message.text.isEmpty { Text(message.text).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
            }
            .font(.body).padding(18)
            .background(message.fromUser ? AppTheme.button.opacity(0.8) : AppTheme.card, in: RoundedRectangle(cornerRadius: 23))
            .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(.white.opacity(message.fromUser ? 0.10 : 0.04)))
            if !message.fromUser { Spacer(minLength: 18) }
        }
        .id(message.id).transition(.opacity.combined(with: .move(edge: message.fromUser ? .trailing : .leading)))
    }

    private func attachmentCard(_ item: ChatAttachment, draft: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if item.audio != nil {
                    Button { playback.toggle(item) } label: {
                        Image(systemName: playback.preparingID == item.id ? "hourglass" : playback.playingID == item.id ? "stop.fill" : "play.fill")
                            .frame(width: 44, height: 44).background(.white.opacity(0.09), in: Circle())
                    }.buttonStyle(.plain).accessibilityLabel(playback.preparingID == item.id ? "Cancelar reprodução" : playback.playingID == item.id ? "Parar áudio" : "Reproduzir áudio")
                } else {
                    Image(systemName: item.symbol).font(.title3).frame(width: 44, height: 44)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name).font(.subheadline.bold()).lineLimit(2)
                    Text(item.kind == .audio ? "Áudio · \(Int(item.duration)) s" : "Texto lido neste aparelho")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if draft {
                    Button { playback.stop(); attachments.removeAll { $0.id == item.id } } label: {
                        Image(systemName: "xmark").frame(width: 44, height: 44)
                    }.buttonStyle(.plain).accessibilityLabel("Remover anexo")
                }
            }
            if !item.note.isEmpty { Text(item.note).font(.caption).foregroundStyle(.secondary) }
            if item.kind == .audio && draft {
                Text("Confira a transcrição antes de enviar:").font(.caption).foregroundStyle(.secondary)
                TextField("Transcrição do áudio", text: Binding(get: { attachments.first(where: { $0.id == item.id })?.text ?? "" }, set: { value in if let index = attachments.firstIndex(where: { $0.id == item.id }) { attachments[index].text = String(value.prefix(4_000)) } }), axis: .vertical)
                    .textFieldStyle(.plain).lineLimit(2...4).font(.subheadline)
                    .accessibilityIdentifier("voiceTranscript")
            } else {
                DisclosureGroup(item.kind == .audio ? "Ver transcrição" : "Ver texto lido") {
                    Text(item.text).font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }.font(.caption)
            }

        }
        .padding(12).background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 17))
    }

    private var composer: some View {
        VStack(spacing: 10) {
            if attachments.count == 1, let first = attachments.first { attachmentCard(first, draft: true) }
            else if attachments.count > 1 {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(attachments) { attachmentCard($0, draft: true).frame(width: 270) }
                    }
                }.scrollIndicators(.hidden)
            }
            if !attachments.isEmpty { Text("\(attachments.count)/4 anexos · envie para conferir e comparar").font(.caption).foregroundStyle(.secondary) }
            if busy {
                HStack(spacing: 10) {
                    if voice.isRecording {
                        Image(systemName: "record.circle.fill").foregroundStyle(.red)
                        Text("Gravando · \(voice.seconds)s / 60s").monospacedDigit()
                        Spacer()
                        Button("Cancelar") { capturing = false; voice.cancel() }.buttonStyle(.plain)
                        Button("Concluir", action: finishRecording).buttonStyle(.borderedProminent)
                    } else {
                        ProgressView().controlSize(.small)
                        Text(voice.isTranscribing ? "Transcrevendo no aparelho…" : startingVoice ? "Preparando microfone…" : "Lendo seu anexo…")
                        Spacer()
                        Button("Cancelar") { readTask?.cancel(); reading = false; voice.cancel() }.buttonStyle(.plain)
                    }
                }.font(.caption).padding(.vertical, 5).accessibilityIdentifier("chatProgress")
            }
            TextField("Pergunte ou conte sua situação…", text: $question, axis: .vertical)
                .textFieldStyle(.plain).lineLimit(1...5).font(.body)
                .padding(.horizontal, 6).padding(.top, 7)
                .focused($editing).onSubmit { if canSend { send(question) } }
                .accessibilityIdentifier("chatQuestion")
                .onChange(of: question) { _, value in if value.count > 500 { question = String(value.prefix(500)) } }
            HStack(spacing: 10) {
                Menu {
                    #if os(iOS)
                    PhotosPicker(selection: $photos, maxSelectionCount: max(1, 4 - attachments.count), matching: .images) { Label("Foto da biblioteca", systemImage: "photo") }
                    #else
                    Button { chooseFiles() } label: { Label("Foto ou print", systemImage: "photo") }
                    #endif
                    Button { chooseFiles() } label: { Label("Arquivo ou áudio", systemImage: "doc.badge.plus") }
                } label: {
                    Image(systemName: "plus").font(.title3.weight(.medium)).frame(width: 44, height: 44)
                        .background(.white.opacity(0.055), in: Circle())
                }
                .menuStyle(.borderlessButton).fixedSize().disabled(busy || attachments.count >= 4)
                .accessibilityLabel("Anexar foto ou arquivo").accessibilityIdentifier("chatAttachments")
                Button {
                    playback.stop(); startingVoice = true
                    Task { await voice.start(); capturing = voice.isRecording; startingVoice = false }
                } label: {
                    Image(systemName: "mic").font(.title3).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).disabled(busy || attachments.count >= 4).accessibilityLabel("Gravar áudio de até 1 minuto").accessibilityIdentifier("chatMicrophone")
                Spacer(minLength: 0)
                Text(question.count > 400 ? "\(question.count)/500" : "Texto, voz e arquivos")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Button { send(question) } label: {
                    Image(systemName: "arrow.up").font(.headline)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(canSend ? AppTheme.canvas : AppTheme.silver.opacity(0.4))
                        .background(canSend ? AppTheme.silver : AppTheme.button.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain).disabled(!canSend)
                .accessibilityLabel("Enviar pergunta").accessibilityIdentifier("sendQuestion")
            }
        }
        .padding(16).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 27))
        .overlay(RoundedRectangle(cornerRadius: 27).strokeBorder(.white.opacity(editing ? 0.19 : 0.09)))
        .frame(maxWidth: 732).padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 12)
        .frame(maxWidth: .infinity).background(AppTheme.canvas.opacity(0.97))
    }

    private func hasOffer(_ text: String) -> Bool {
        let offers = ExtractedOffers.read(text)
        return !offers.pixPrices.isEmpty || !offers.installments.isEmpty
    }

    private func send(_ text: String) {
        guard !busy else { return }
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !clean.isEmpty || !attachments.isEmpty else { return }
        let attached = attachments
        let spoken = attached.filter { $0.kind == .audio }.map(\.text).joined(separator: "\n")
        let query = [clean, spoken].filter { !$0.isEmpty }.joined(separator: "\n")
        let answer: String
        let needsReview = attached.contains { $0.kind != .audio || hasOffer($0.text) }
        if needsReview {
            checkoutComparison = nil; checkoutSummary = ""
            answer = "Recebi os anexos. Confirme o cartão selecionado, os preços e as parcelas na revisão. Vou comparar as ofertas de cada banco e o Pix e trazer o diagnóstico aqui na conversa."
        } else if !attached.isEmpty && spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            answer = clean.isEmpty
                ? "Recebi seu áudio para reprodução, mas a transcrição não está disponível. Escreva sua pergunta para eu conseguir responder."
                : "O áudio ficou sem transcrição; vou responder à pergunta escrita.\n\n" + SimpleAssistant.reply(to: clean, comparison: checkoutComparison ?? (try? input.calculate()))
        } else if checkoutComparison != nil && query.range(of: "(?i)melhor|vantajos|diagn[oó]stico|cen[aá]rio|compar|vale|op[cç][aã]o", options: .regularExpression) != nil {
            answer = checkoutSummary
        } else {
            answer = SimpleAssistant.reply(to: query, comparison: checkoutComparison ?? (try? input.calculate()), diagnostics: checkoutComparison == nil ? try? input.diagnoseFourCases() : nil)
        }
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
            messages.append(ChatMessage(text: clean, fromUser: true, attachments: attached))
            messages.append(ChatMessage(text: answer, fromUser: false))
            while messages.count > 100 || messages.reduce(0, { $0 + $1.attachments.reduce(0, { $0 + ($1.audio?.count ?? 0) }) }) > 40 * 1024 * 1024 { messages.removeFirst() }
            attachments = []; question = ""
        }
        editing = false
        if needsReview { checkoutBatch = CheckoutBatch(attachments: attached) }
    }

    private func load(_ action: @escaping () async throws -> ChatAttachment) {
        loadMany { [try await action()] }
    }

    private func loadMany(_ action: @escaping () async throws -> [ChatAttachment]) {
        readTask?.cancel(); reading = true; error = nil
        readTask = Task {
            do {
                let result = try await action()
                try Task.checkCancellation()
                guard attachments.count + result.count <= 4 else { throw CalculationError.invalid("Envie até 4 anexos por mensagem. Remova algum antes de adicionar mais.") }
                playback.stop(); attachments.append(contentsOf: result); photos = []
            } catch { if !Task.isCancelled && !(error is CancellationError) { self.error = error.localizedDescription } }
            if !Task.isCancelled { reading = false }
        }
    }

    private func chooseFiles() {
        #if os(macOS)
        guard !showFile else { return }
        showFile = true
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowsOtherFileTypes = true
        panel.allowedContentTypes = [.item]
        panel.prompt = "Anexar"
        panel.message = "Escolha até 4 imagens, PDFs com texto, TXT ou áudios de até 1 minuto."
        let completed: (NSApplication.ModalResponse) -> Void = { response in
            showFile = false
            if response == .OK { loadFiles(panel.urls) }
        }
        if let window = NSApp.keyWindow { panel.beginSheetModal(for: window, completionHandler: completed) }
        else { panel.begin(completionHandler: completed) }
        #else
        showFile = true
        #endif
    }

    private func loadFiles(_ urls: [URL]) {
        guard !urls.isEmpty, urls.count + attachments.count <= 4 else { error = "Envie até 4 anexos por mensagem."; return }
        loadMany {
            var results: [ChatAttachment] = []
            for url in urls { results.append(try await readFile(url)) }
            return results
        }
    }

    private func readFile(_ url: URL) async throws -> ChatAttachment {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let (data, type) = try await Task.detached {
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey, .isRegularFileKey])
                guard values.isRegularFile == true else { throw ChatAttachmentError.unsupported }
                guard let size = values.fileSize, size <= 20 * 1024 * 1024 else { throw ChatAttachmentError.tooLarge }
                guard let type = values.contentType ?? UTType(filenameExtension: url.pathExtension) else { throw ChatAttachmentError.unsupported }
                return (try Data(contentsOf: url, options: .mappedIfSafe), type)
            }.value
            if type.conforms(to: .audio) {
                let audio = try AVAudioFile(forReading: url)
                guard audio.length > 0, audio.fileFormat.sampleRate > 0 else { throw ChatAttachmentError.unreadable }
                let duration = Double(audio.length) / audio.fileFormat.sampleRate
                guard duration <= 60 else { throw ChatAttachmentError.unsupported }
                var result = ChatAttachment(name: url.lastPathComponent, kind: .audio, text: "", audio: data, duration: duration)
                do { result.text = try await voice.transcribeFile(at: url) }
                catch is CancellationError { throw CancellationError() }
                catch { result.note = error.localizedDescription + " Você pode enviar o áudio e escrever a pergunta junto." }
                return result
            }
            return try await ChatAttachmentReader.read(data: data, type: type, name: url.lastPathComponent)
    }

    private func receiveDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !busy, !providers.isEmpty, providers.count + attachments.count <= 4 else {
            error = "Solte até 4 arquivos por mensagem."; return false
        }
        loadMany {
            var results: [ChatAttachment] = []
            for (index, provider) in providers.enumerated() {
                try Task.checkCancellation()
                let file = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                guard let type = file ? UTType.fileURL.identifier : provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true }) else { throw ChatAttachmentError.unsupported }
                let data: Data = try await withCheckedThrowingContinuation { continuation in
                    provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
                        if let data { continuation.resume(returning: data) }
                        else { continuation.resume(throwing: error ?? ChatAttachmentError.unreadable) }
                    }
                }
                if file {
                    guard let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL else { throw ChatAttachmentError.unsupported }
                    results.append(try await readFile(url))
                } else {
                    results.append(try await ChatAttachmentReader.read(data: data, type: .image, name: "Print \(index + 1)"))
                }
            }
            return results
        }
        return true
    }

    private func finishRecording() {
        guard capturing else { return }
        capturing = false
        load {
            guard let clip = await voice.finish() else { throw CancellationError() }
            defer { try? FileManager.default.removeItem(at: clip.url) }
            return ChatAttachment(name: "Mensagem de voz", kind: .audio, text: clip.transcript,
                                  note: clip.note, audio: try Data(contentsOf: clip.url), duration: clip.duration)
        }
    }

    private func clear() {
        capturing = false; readTask?.cancel(); reading = false
        voice.cancel(); playback.stop(); photos = []; checkoutComparison = nil; checkoutSummary = ""
        messages = []; attachments = []; question = ""
    }
}
