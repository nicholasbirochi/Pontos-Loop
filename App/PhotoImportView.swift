import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import DecisionCore

struct PhotoImportView: View {
    @Binding var input: InputState
    var applied: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var editingFields: Bool
    @State private var photos: [PhotosPickerItem] = []
    @State private var showFile = false
    @State private var reading = false
    @State private var readTask: Task<Void, Never>?
    @State private var text = ""
    @State private var offers = ExtractedOffers.read("")
    @State private var selectedOffer: String = ""
    @State private var pix = "0"
    @State private var withInterest = false
    @State private var principal = "0"
    @State private var total = "0"
    @State private var count = 0
    @State private var firstDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Mande o print. Confira os valores.")
                        .font(.system(.title2, design: .rounded).bold())
                    Text("Escolha até \(ChatAttachmentReader.maxCount) fotos: por exemplo, uma do Pix e outra das parcelas. A leitura acontece neste aparelho.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    #if os(iOS)
                    PhotosPicker(selection: $photos, maxSelectionCount: ChatAttachmentReader.maxCount, matching: .images) {
                        Label("Escolher fotos", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.borderedProminent).disabled(reading)
                    #endif
                    Button { showFile = true } label: {
                        Label("Selecionar arquivo", systemImage: "folder")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }.buttonStyle(.bordered).disabled(reading)
                    if reading { ProgressView("Lendo os valores…").frame(maxWidth: .infinity) }
                    if let error { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.orange) }
                    if !text.isEmpty {
                        Label("Confira antes de comparar", systemImage: "checkmark.shield")
                            .font(.headline)
                        if offers.installments.count > 1 {
                            Picker("Qual parcelamento?", selection: $selectedOffer) {
                                Text("Escolha uma oferta").tag("")
                                ForEach(offers.installments) { offer in
                                    Text("\(offer.count)x de \(money(offer.amount))" + (offer.hasInterest.map { $0 ? " · com juros" : " · sem juros" } ?? "")).tag(offer.id)
                                }
                            }
                            .onChange(of: selectedOffer) { _, id in
                                if let offer = offers.installments.first(where: { $0.id == id }) {
                                    total = number(offer.total); count = offer.count; withInterest = offer.hasInterest ?? false
                                }
                            }
                        }
                        if offers.pixPrices.count > 1 {
                            Text("Encontrei mais de um preço à vista. Toque no correto:").font(.subheadline)
                            ForEach(Array(offers.pixPrices.enumerated()), id: \.offset) { _, price in
                                Button(money(price)) { pix = number(price) }.buttonStyle(.bordered)
                            }
                        }
                        if offers.installments.isEmpty && offers.pixPrices.isEmpty {
                            Text("Li o texto, mas não identifiquei uma oferta com segurança. Digite os valores abaixo.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        field("Preço no Pix", value: $pix)
                        field("Total no cartão", value: $total)
                        Toggle("Esta oferta do cartão tem juros", isOn: $withInterest)
                        if withInterest { field("Valor da compra sem juros (base elegível)", value: $principal) }
                        Stepper("Parcelas: \(count)x", value: $count, in: 0...36)
                        DatePicker("Primeiro vencimento", selection: $firstDate, in: Date()..., displayedComponents: .date)
                        Text("O total sugerido usa o valor final anunciado quando reconhecido; caso contrário, usa parcelas × valor de cada parcela. Confira juros, taxas e a última parcela. O rendimento e o valor monetário dos pontos começam em 0. Pontos normais do Prime são estimados sobre a compra elegível; confira também se esta oferta tem juros.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button(action: apply) {
                            Label("Usar e comparar", systemImage: "checkmark")
                                .frame(maxWidth: .infinity, minHeight: 38)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(reading || pix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || total.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("applyPhoto")
                        DisclosureGroup("Ver texto lido") {
                            Text(text).font(.caption).textSelection(.enabled)
                        }
                    } else {
                        Text("Funciona melhor com ofertas como “10x de R$ 100,00” e “Pix R$ 950,00”. Fotos desfocadas e listas de parcelas diferentes podem precisar de preenchimento manual.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(22).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
            .background(AppTheme.canvas)
            .navigationTitle("Ler uma oferta")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            #endif
            .toolbar { Button("Fechar") { dismiss() } }
            #if os(iOS)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Concluir") { editingFields = false }
                }
            }
            #endif
        }
        .preferredColorScheme(.dark)
        .tint(AppTheme.accent)
        #if os(macOS)
        .frame(minWidth: 600, minHeight: 680)
        #endif
        .onDisappear { readTask?.cancel() }
        .onChange(of: photos) { _, items in
            guard !items.isEmpty else { return }
            begin {
                var texts: [String] = []
                for item in items.prefix(ChatAttachmentReader.maxCount) {
                    try Task.checkCancellation()
                    guard let data = try await item.loadTransferable(type: Data.self) else { throw PhotoReadError.invalidImage }
                    texts.append(try await PhotoTextRecognizer.read(data))
                }
                return texts.joined(separator: "\n\n")
            }
        }
        .fileImporter(isPresented: $showFile, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            switch result {
            case .failure(let failure): error = failure.localizedDescription
            case .success(let urls):
                guard !urls.isEmpty, urls.count <= ChatAttachmentReader.maxCount else { error = "Escolha de 1 a \(ChatAttachmentReader.maxCount) imagens por vez."; return }
                begin {
                    var texts: [String] = []
                    for url in urls {
                        try Task.checkCancellation()
                        let access = url.startAccessingSecurityScopedResource()
                        defer { if access { url.stopAccessingSecurityScopedResource() } }
                        let data = try await Task.detached {
                            if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 20 * 1024 * 1024 { throw PhotoReadError.tooLarge }
                            return try Data(contentsOf: url, options: .mappedIfSafe)
                        }.value
                        texts.append(try await PhotoTextRecognizer.read(data))
                    }
                    return texts.joined(separator: "\n\n")
                }
            }
        }
    }

    private func begin(_ load: @escaping () async throws -> String) {
        readTask?.cancel()
        reading = true; error = nil
        text = ""; offers = ExtractedOffers.read("")
        pix = "0"; total = "0"; principal = "0"; withInterest = false; selectedOffer = ""
        readTask = Task {
            do {
                let recognized = try await load()
                try Task.checkCancellation()
                text = String(recognized.prefix(30_000))
                offers = ExtractedOffers.read(text)
                selectedOffer = ""; pix = "0"; total = "0"; count = 0
                if offers.pixPrices.count == 1 { pix = number(offers.pixPrices[0]) }
                if offers.installments.count == 1 {
                    let offer = offers.installments[0]
                    total = number(offer.total); count = offer.count; withInterest = offer.hasInterest ?? false; selectedOffer = offer.id
                }
            } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
            if !Task.isCancelled { reading = false }
        }
    }

    private func apply() {
        do {
            var reviewed = InputState()
            reviewed.mode = .fourCases
            reviewed.directPixPrice = pix
            reviewed.cardTotal = withInterest ? principal : total
            reviewed.interestTotal = withInterest ? total : "0"
            reviewed.interestCount = withInterest ? count : 0
            reviewed.installmentCount = withInterest ? 0 : count
            reviewed.firstDate = firstDate
            reviewed.monthlyRate = "0"
            reviewed.rewardsEnabled = false
            reviewed.cashback = "0"
            _ = try reviewed.calculate()
            input = reviewed
            applied(); dismiss()
        } catch { self.error = error.localizedDescription }
    }

    private func number(_ value: Decimal) -> String {
        value.formatted(.number.locale(Locale(identifier: "pt_BR")).grouping(.never).precision(.fractionLength(2)))
    }
    private func money(_ value: Decimal) -> String {
        value.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
    }
    private func field(_ title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.bold())
            HStack {
                Text("R$").foregroundStyle(.secondary)
                TextField("Digite ou corrija", text: value)
                    .focused($editingFields)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .accessibilityLabel(title)
            }.padding(14).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
