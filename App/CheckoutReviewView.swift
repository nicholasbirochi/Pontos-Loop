import SwiftUI
import DecisionCore

struct CheckoutBatch: Identifiable {
    let id = UUID()
    let attachments: [ChatAttachment]
}

enum CheckoutCard: String, CaseIterable {
    case choose = "Confirme o meio de pagamento"
    case pix = "Pix", inter = "Inter Prime", itau = "Itaú", mercado = "Cartão Mercado Livre", other = "Outro cartão"
}

struct CheckoutRow: Identifiable {
    let id = UUID()
    var included = true
    var count = 0
    var total = "0"
    var pix = false
}

struct CheckoutSource: Identifiable {
    let id: UUID
    let name: String
    let text: String
    var preview: Data?
    var continuationOf: UUID?
    var advertised = false
    var card: CheckoutCard = .choose
    var principal = "0"
    var cashback = "0"
    var rows: [CheckoutRow]
    var note = ""

    static func read(_ attachments: [ChatAttachment]) -> [CheckoutSource] {
        let extracted = attachments.map { ExtractedOffers.read($0.text) }
        let bases = Set(extracted.flatMap(\.installments).filter { $0.count == 1 }.map(\.total))
        let sharedBase = bases.count == 1 ? bases.first : nil
        let number: (Decimal) -> String = { $0.formatted(.number.locale(Locale(identifier: "pt_BR")).grouping(.never).precision(.fractionLength(2))) }
        var sources: [CheckoutSource] = []
        for (index, pair) in zip(attachments, extracted).enumerated() {
            let (attachment, read) = pair
            let text = attachment.text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            let advertisement = text.contains("mais vendido") && !text.contains("escolha as parcelas")
            let inter = text.contains("banco inter")
            let itau = text.contains("itau"), mercado = text.contains("mercad")
            let pixOnly = !read.pixPrices.isEmpty && read.installments.isEmpty
            let selected = attachment.image?.selectedPayment
            let card: CheckoutCard = advertisement ? (read.pixPrices.isEmpty ? .choose : .pix) : pixOnly ? .pix : inter && !itau ? .inter : selected == .itau ? .itau
                : selected == .mercado ? .mercado : itau && !mercado ? .itau : mercado && !itau ? .mercado : .choose
            var rows = read.pixPrices.map { CheckoutRow(count: 1, total: number($0), pix: true) }
                + read.installments.map { CheckoutRow(count: $0.count, total: number($0.total)) }
            if advertisement {
                rows = !read.pixPrices.isEmpty ? read.pixPrices.map { CheckoutRow(count: 1, total: number($0), pix: true) }
                    : attachment.image?.advertisedPrice.map { [CheckoutRow(included: false, count: 1, total: number($0))] } ?? []
            }
            let note = advertisement ? (rows.isEmpty ? "Não identifiquei um preço principal com segurança. Confira a imagem antes de incluir a oferta."
                : "Preço anunciado preenchido. Confirme se este também é o preço final no Pix; o ícone do Pix sozinho não confirma preço nem desconto.")
                : rows.isEmpty ? "Não encontrei um preço legível. Este print não impede comparar os demais." : ""
            if rows.isEmpty { rows = [CheckoutRow(included: false)] }
            let base = read.installments.first(where: { $0.count == 1 })?.total ?? sharedBase ?? 0
            var source = CheckoutSource(id: attachment.id, name: "Print \(index + 1) · \(attachment.name)", text: attachment.text,
                                        preview: attachment.image?.preview, advertised: advertisement,
                                        card: card, principal: number(base), rows: rows, note: note)
            if !advertisement, !inter, !itau, !mercado, !pixOnly, attachment.kind == .image,
               let previous = sources.last, attachments[index - 1].kind == .image, !previous.advertised,
               !read.installments.isEmpty, previous.rows.contains(where: { $0.included && !$0.pix }),
               read.installments.allSatisfy({ offer in previous.rows.allSatisfy { $0.count != offer.count || $0.total == number(offer.total) } }) {
                let overlap = read.installments.filter { offer in previous.rows.contains { $0.count == offer.count && $0.total == number(offer.total) } }.count
                let previousEnd = previous.rows.filter(\.included).map(\.count).max() ?? 0
                let nextStart = read.installments.map(\.count).min() ?? 0
                if overlap >= 2 || (nextStart == previousEnd + 1 && nextStart > 1) {
                    source.continuationOf = previous.continuationOf ?? previous.id
                    source.card = previous.card
                    source.principal = previous.principal
                }
            }
            sources.append(source)
        }
        return sources
    }

    static func leader(_ index: Int, in sources: [CheckoutSource]) -> Int {
        if let id = sources[index].continuationOf, let parent = sources.firstIndex(where: { $0.id == id }), parent < index {
            return leader(parent, in: sources)
        }
        return index
    }

    static func plans(_ sources: [CheckoutSource]) throws -> [(source: Int, row: CheckoutRow)] {
        var plans: [(source: Int, row: CheckoutRow)] = []
        for (index, source) in sources.enumerated() {
            let root = leader(index, in: sources)
            for row in source.rows where row.included {
                let total = try BrazilianInput.decimal(row.total, label: "total final")
                let pix = row.pix || sources[root].card == .pix
                let same = plans.filter { $0.source == root && ($0.row.pix || sources[root].card == .pix) == pix && (pix || $0.row.count == row.count) }
                if let previous = same.first {
                    guard try BrazilianInput.decimal(previous.row.total, label: "total final") == total else {
                        throw CalculationError.invalid("Os prints do mesmo cartão têm totais diferentes para \(row.count)x. Confira as imagens ou separe a continuação.")
                    }
                    continue
                }
                plans.append((root, row))
            }
        }
        return plans
    }

}

struct CheckoutReviewView: View {
    var compared: (Comparison, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sources: [CheckoutSource]
    @State private var monthlyRate = "0"
    @State private var thousandValue = "0"
    @State private var firstDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var benefitDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var anticipationSource = ""
    @State private var anticipationQuote = "0"
    @State private var extraPoints = "0"
    @State private var anticipationCashback = "0"
    @State private var paymentDate = Date()
    @State private var error: String?
    @State private var previewSource: CheckoutSource?

    init(attachments: [ChatAttachment], compared: @escaping (Comparison, String) -> Void) {
        self.compared = compared
        _sources = State(initialValue: CheckoutSource.read(attachments))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Uma compra. Todas as ofertas.").font(.system(.title2, design: .rounded).bold())
                    Text("Os prints de continuação usam o mesmo cartão. Parcelas repetidas entram uma única vez. Toque na imagem para conferir; os valores já estão preenchidos.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Envie a tela inicial de cada cartão seguida de suas continuações, na ordem.").font(.caption).foregroundStyle(.secondary)
                    Text("Cartão desconhecido não impede comparar preços. Confirme Inter Prime para estimar seus pontos; cashback ‘até’ um valor só entra quando você confirmar o benefício.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(sources.indices, id: \.self) { index in
                        let source = sources[index]
                        let root = CheckoutSource.leader(index, in: sources)
                        VStack(alignment: .leading, spacing: 12) {
                            if source.advertised, let row = source.rows.first, row.count == 1 {
                                Text("Preço anunciado: R$ \(row.total)").font(.headline)
                                if source.card != .pix {
                                    Button("Confirmar este preço como Pix") {
                                        sources[index].card = .pix
                                        sources[index].rows[0].included = true
                                    }.buttonStyle(.bordered).accessibilityIdentifier("confirmAdvertisedPix")
                                } else { Label("Pix confirmado", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                                if source.card != .pix { Text(source.note).font(.caption).foregroundStyle(.secondary) }
                            }
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 14) {
                                    if !source.note.isEmpty && !source.advertised { Text(source.note).font(.caption).foregroundStyle(.secondary) }
                                    if root != index {
                                        Label("Continuação de \(sources[root].name). Cartão e benefícios são compartilhados.", systemImage: "link")
                                            .font(.caption).foregroundStyle(.secondary)
                                        Button("Tratar este print como oferta separada") { sources[index].continuationOf = nil }
                                    }
                                    Picker("Meio de pagamento", selection: $sources[root].card) {
                                        ForEach(CheckoutCard.allCases, id: \.self) { card in Text(card.rawValue).tag(card) }
                                    }.accessibilityIdentifier("checkoutCard")
                                    if sources[root].card == .inter {
                                        field("Compra elegível para pontos Prime", text: $sources[root].principal)
                                        Text("Pontos normais = base elegível ÷ R$ 2,50, sem depender de antecipar. Juros não ampliam essa base.")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    if sources[root].card != .pix { field(sources[root].card == .inter ? "Cashback confirmado (sem pontos Prime) em R$" : "Cashback/benefício confirmado em R$", text: $sources[root].cashback) }
                                    ForEach($sources[index].rows) { $row in
                                        VStack(alignment: .leading, spacing: 10) {
                                            Toggle(row.pix ? "Incluir Pix deste print" : "Incluir esta oferta", isOn: $row.included)
                                            if sources[root].card != .pix && !row.pix { Stepper("Parcelas: \(row.count)x", value: $row.count, in: 0...36) }
                                            field(sources[root].card == .pix || row.pix ? "Preço final no Pix" : "Total final de todas as parcelas", text: $row.total)
                                        }.padding(13).background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 14))
                                    }
                                    Button("Adicionar oferta") { sources[index].rows.append(CheckoutRow()) }.buttonStyle(.bordered)
                                    DisclosureGroup("Conferir texto lido") { Text(source.text).font(.caption).textSelection(.enabled) }
                                }.padding(.top, 12)
                            } label: {
                                HStack(spacing: 12) {
                                    if source.preview != nil {
                                        Button { previewSource = source } label: {
                                            preview(source).frame(width: 54, height: 94).clipped()
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }.buttonStyle(.plain).accessibilityLabel("Ampliar imagem do \(source.name)")
                                    }
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(source.name)
                                        Text("\(source.rows.filter(\.included).count) \(source.rows.filter(\.included).count == 1 ? "oferta" : "ofertas") · \(sources[root].card == .choose ? "confirmar cartão uma vez" : sources[root].card.rawValue)")
                                            .font(.caption).foregroundStyle(.secondary)
                                        if root != index { Label("Continua o print \(root + 1)", systemImage: "link").font(.caption).foregroundStyle(AppTheme.accent) }
                                    }
                                }
                            }
                        }.padding(17).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20))
                    }

                    DisclosureGroup("Datas, rendimento e pontos") {
                        VStack(alignment: .leading, spacing: 12) {
                            DatePicker("Primeiro vencimento das parcelas", selection: $firstDate, in: Date()..., displayedComponents: .date)
                            DatePicker("Disponibilidade dos benefícios", selection: $benefitDate, in: Date()..., displayedComponents: .date)
                            field("Rendimento líquido mensal (%)", text: $monthlyRate)
                            field("Valor de 1.000 pontos no seu resgate (R$)", text: $thousandValue)
                            Text("Rendimento e valor dos pontos começam em zero. Os vencimentos seguintes são mensais; ajuste a primeira data para esta compra. Benefícios são estimados nessa data única.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.top, 12)
                    }
                    DisclosureGroup("Incluir antecipação real do Inter") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Compra que será antecipada", selection: $anticipationSource) {
                                Text("Escolha um print do Inter Prime").tag("")
                                ForEach(sources.filter { $0.continuationOf == nil && $0.card == .inter }) { source in Text(source.name).tag(source.id.uuidString) }
                            }
                            field("Oferta de quitação do Inter (R$)", text: $anticipationQuote)
                            field("Somente pontos extras da antecipação", text: $extraPoints)
                            field("Cashback confirmado que permanece ao antecipar (R$)", text: $anticipationCashback)
                            DatePicker("Pagamento da quitação", selection: $paymentDate, in: Date()..., displayedComponents: .date)
                            Text("Copie a oferta do app Inter. Não deduzo o desconto ou o bônus pelos prints da loja. Pontos normais entram uma vez, mais este bônus extra.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(.top, 12)
                    }
                    if let error { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.orange) }
                    Button(action: compare) {
                        Label("Confirmar e comparar no chat", systemImage: "checkmark.bubble")
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }.buttonStyle(.borderedProminent).accessibilityIdentifier("compareCheckout")
                }.padding(22).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
            .background(AppTheme.canvas).navigationTitle("Conferir ofertas")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            #endif
            .toolbar { Button("Fechar") { dismiss() } }
        }
        .sheet(item: $previewSource) { source in
            NavigationStack {
                ScrollView { preview(source).padding().frame(maxWidth: 700).frame(maxWidth: .infinity) }
                    .navigationTitle(source.name)
                    .toolbar { Button("Voltar às ofertas") { previewSource = nil } }
            }
            .preferredColorScheme(.dark)
            #if os(macOS)
            .frame(minWidth: 500, minHeight: 700)
            #endif
        }
        .preferredColorScheme(.dark).tint(AppTheme.accent)
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 740)
        #endif
    }

    @ViewBuilder private func preview(_ source: CheckoutSource) -> some View {
        if let data = source.preview {
            #if os(iOS)
            if let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit() }
            #else
            if let image = NSImage(data: data) { Image(nsImage: image).resizable().scaledToFit() }
            #endif
        }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.medium))
            TextField("0", text: text).textFieldStyle(.roundedBorder).accessibilityLabel(label)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        }
    }

    private func compare() {
        do {
            let rate = DecisionEngine.number(try BrazilianInput.decimal(monthlyRate, label: "rendimento")) / 100
            let thousand = try BrazilianInput.decimal(thousandValue, label: "valor do milheiro")
            let benefitDay = try LocalSchedule.day(benefitDate)
            var offers: [CheckoutOffer] = []
            for plan in try CheckoutSource.plans(sources) {
                let source = sources[plan.source], row = plan.row
                let principal = source.card == .inter ? try BrazilianInput.decimal(source.principal, label: "compra elegível Prime") : 0
                guard source.card != .inter || principal > 0 else { throw CalculationError.invalid("Informe o valor elegível da compra para calcular os pontos normais do Inter Prime.") }
                let cashback = source.card == .pix ? 0 : try BrazilianInput.decimal(source.cashback, label: "benefício confirmado")
                let isPix = source.card == .pix || row.pix
                let days = isPix ? [0] : try LocalSchedule.days(first: firstDate, count: row.count)
                let total = try BrazilianInput.decimal(row.total, label: "total final")
                guard isPix || source.card != .inter || principal <= total else { throw CalculationError.invalid("A base Prime não pode superar o total da compra parcelada.") }
                let cardName = source.card == .choose ? "Cartão não identificado" : source.card.rawValue
                let prints = sources.indices.filter { CheckoutSource.leader($0, in: sources) == plan.source }.map { String($0 + 1) }.joined(separator: ", ")
                offers.append(CheckoutOffer(name: "\(isPix ? "Pix" : cardName)" + (isPix ? "" : " · \(row.count)x") + " · prints \(prints)",
                                            total: total, days: days, eligiblePrimeSpend: isPix ? 0 : principal, cashback: isPix ? 0 : cashback, benefitDay: benefitDay))
            }
            let quote = try BrazilianInput.decimal(anticipationQuote, label: "quitação Inter")
            if quote > 0 {
                guard let source = sources.first(where: { $0.id.uuidString == anticipationSource && $0.card == .inter }) else {
                    throw CalculationError.invalid("Escolha qual compra Inter será antecipada.")
                }
                let paymentDay = try LocalSchedule.day(paymentDate)
                guard paymentDay <= (try LocalSchedule.day(firstDate)), benefitDay >= paymentDay else {
                    throw CalculationError.invalid("Quitação deve ser até o vencimento e benefícios após o pagamento.")
                }
                let principal = try BrazilianInput.decimal(source.principal, label: "base Prime")
                guard principal > 0 else { throw CalculationError.invalid("Informe a base elegível dos pontos normais na compra Inter.") }
                offers.append(CheckoutOffer(name: "Inter Prime · antecipação", total: quote, days: [paymentDay],
                                            eligiblePrimeSpend: principal,
                                            extraPoints: try BrazilianInput.decimal(extraPoints, label: "bônus extra"),
                                            cashback: try BrazilianInput.decimal(anticipationCashback, label: "cashback da antecipação"), benefitDay: benefitDay))
            } else {
                guard quote == 0, try BrazilianInput.decimal(extraPoints, label: "bônus extra") == 0,
                      try BrazilianInput.decimal(anticipationCashback, label: "cashback da antecipação") == 0 else {
                    throw CalculationError.invalid("Informe a quitação real antes de incluir bônus de antecipação.")
                }
            }
            let comparison = try DecisionEngine.checkout(offers, reaisPerThousand: thousand, monthlyRate: rate)
            let best = comparison.ordered[0]
            let count = best.flows.filter { $0.kind == .payment }.count
            var lines = ["Menor custo encontrado: \(Self.money(best.presentCost)), em \(count)x. Total pago: \(Self.money(DecisionEngine.number(best.cashOutlay)))."]
            if let next = comparison.ordered.first(where: { $0.presentCost - best.presentCost > 0.01 }) {
                lines.append("A próxima faixa de custo começa em \(Self.money(next.presentCost)): \(Self.money(next.presentCost - best.presentCost)) a mais.")
            }
            lines.append("\nComparei \(comparison.options.count) ofertas. Estas têm os menores custos:")
            for (index, option) in comparison.ordered.prefix(5).enumerated() {
                lines.append("\(index + 1). \(option.name): \(Self.money(option.presentCost)) em reais de hoje; total pago \(Self.money(DecisionEngine.number(option.cashOutlay))).")
            }
            let tied = comparison.ordered.filter { $0.presentCost - comparison.ordered[0].presentCost <= 0.01 }
            lines.append(tied.count > 1 ? "\nEmpate econômico entre: " + tied.map(\.name).joined(separator: ", ") + "." : "\nA mais vantajosa entre as ofertas confirmadas é \(comparison.ordered[0].name), com vantagem de \(Self.money(comparison.difference)) sobre a segunda opção.")
            if quote == 0 { lines.append("Antecipação do Inter ainda não comparada: falta a oferta real de quitação e seu bônus extra.") }
            if !offers.contains(where: { $0.name.hasPrefix("Pix") }) { lines.append("Pix ainda não comparado: falta o preço final dessa modalidade.") }
            if sources.indices.contains(where: { sources[CheckoutSource.leader($0, in: sources)].card == .choose && sources[$0].rows.contains(where: \.included) }) {
                lines.append("Cartões não identificados entram pelo preço, sem presumir pontos ou cashback. Você pode confirmar o banco na revisão.")
            }
            if let inter = offers.first(where: { $0.eligiblePrimeSpend > 0 }) {
                lines.append("Inter Prime: \(try DecisionEngine.earnedPoints(eligibleSpend: inter.eligiblePrimeSpend, reaisPerPoint: Decimal(string: "2.50")!)) pontos normais estimados pela compra, inclusive em 1x, sem depender de antecipar.")
            }
            if thousand == 0 { lines.append("Valor do milheiro em zero: os pontos ainda não reduzem o custo em reais.") }
            lines.append("Pontos normais só nas compras elegíveis do Inter Prime confirmado, uma vez por alternativa. Itaú e Mercado Livre usam apenas os benefícios em reais que você informou. O ranking usa rendimento líquido de \(monthlyRate)% a.m. e as datas da revisão.")
            compared(comparison, lines.joined(separator: "\n")); dismiss()
        } catch { self.error = error.localizedDescription }
    }

    private static func money(_ value: Double) -> String { value.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR"))) }
}
