import SwiftUI
import DecisionCore

private struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let fromUser: Bool
}

struct AssistantView: View {
    let input: InputState
    var openPhoto: () -> Void
    @State private var question = ""
    @State private var messages: [ChatMessage] = []
    @FocusState private var editing: Bool
    private let suggestions = ["Qual opção vale mais a pena?", "O que é custo econômico?", "Como funcionam os pontos?", "E se eu antecipar?"]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        introduction
                        Button(action: openPhoto) {
                            Label("Comparar uma foto", systemImage: "photo")
                                .frame(maxWidth: .infinity, minHeight: 32)
                        }.buttonStyle(.bordered)
                        if messages.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("PODE PERGUNTAR").font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button { send(suggestion) } label: {
                                        HStack {
                                            Text(suggestion).multilineTextAlignment(.leading)
                                            Spacer()
                                            Image(systemName: "arrow.up.left")
                                        }
                                        .font(.subheadline.weight(.medium)).padding(16)
                                        .background(AppTheme.card, in: RoundedRectangle(cornerRadius: 16))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                        ForEach(messages) { message in
                            HStack {
                                if message.fromUser { Spacer(minLength: 32) }
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(message.fromUser ? "VOCÊ" : "NOAH")
                                        .font(.caption2.weight(.bold)).tracking(1)
                                    Text(message.text).font(.body).textSelection(.enabled)
                                }
                                .padding(17)
                                .foregroundStyle(message.fromUser ? .white : .primary)
                                .background(message.fromUser ? AppTheme.button : AppTheme.card,
                                            in: RoundedRectangle(cornerRadius: 20))
                                if !message.fromUser { Spacer(minLength: 20) }
                            }
                            .id(message.id)
                            .accessibilityElement(children: .combine)
                        }
                    }.padding(20).frame(maxWidth: 720).frame(maxWidth: .infinity)
                }
                .onChange(of: messages.count) { _, _ in
                    if let id = messages.last?.id {
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
                .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            }
            .background(AppTheme.canvas)
            .navigationTitle("Converse com o Noah")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                Button("Nova conversa", systemImage: "square.and.pencil") { messages = []; question = "" }
                    .disabled(messages.isEmpty)
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title).foregroundStyle(AppTheme.silver)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
            Text("Oi, eu sou o Noah.")
                .font(.system(.title, design: .rounded).weight(.bold))
            Text("Explico sua comparação em palavras simples. Você também pode importar uma foto da oferta.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
            Label("Sem internet · conversa só nesta sessão", systemImage: "lock.shield")
                .font(.caption)
        }
        .foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.ink, in: RoundedRectangle(cornerRadius: 28))
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Pergunte de um jeito simples…", text: $question, axis: .vertical)
                .lineLimit(1...4).padding(14).background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 18))
                .focused($editing).onSubmit { send(question) }
                .accessibilityIdentifier("chatQuestion")
                .onChange(of: question) { _, value in
                    if value.count > 500 { question = String(value.prefix(500)) }
                }
            Button { send(question) } label: {
                Image(systemName: "arrow.up").font(.headline)
                    .frame(width: 48, height: 48)
                    .foregroundStyle(.white).background(AppTheme.button, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Enviar pergunta")
            .accessibilityIdentifier("sendQuestion")
            .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }.padding(16).background(AppTheme.card)
    }

    private func send(_ text: String) {
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !clean.isEmpty else { return }
        let answer = SimpleAssistant.reply(to: clean, comparison: try? input.calculate())
        messages.append(ChatMessage(text: clean, fromUser: true))
        messages.append(ChatMessage(text: answer, fromUser: false))
        messages = Array(messages.suffix(100))
        question = ""
        editing = false
    }
}
