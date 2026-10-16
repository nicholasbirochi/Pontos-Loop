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
        return zip(attachments, extracted).enumerated().map { index, pair in
            let (attachment, read) = pair
            let text = attachment.text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            let advertisement = text.contains("mais vendido") && !text.contains("escolha as parcelas")
            let inter = text.contains("banco inter")
            let itau = text.contains("itau"), mercado = text.contains("mercad")
            let pixOnly = !read.pixPrices.isEmpty && read.installments.isEmpty
            let card: CheckoutCard = pixOnly ? .pix : inter && !itau ? .inter : itau && !mercado ? .itau : .choose
            var rows = read.pixPrices.map { CheckoutRow(count: 1, total: number($0), pix: true) }
                + read.installments.map { CheckoutRow(count: $0.count, total: number($0.total)) }
            if advertisement { for index in rows.indices { rows[index].included = false } }
            let note = advertisement ? "Anúncio: ofertas excluídas inicialmente. O checkout pode ter outros preços."
                : rows.isEmpty ? "Não encontrei um preço legível. Este print não impede comparar os demais." : ""
            if rows.isEmpty { rows = [CheckoutRow(included: false)] }
            let base = read.installments.first(where: { $0.count == 1 })?.total ?? sharedBase ?? 0
            return CheckoutSource(id: attachment.id, name: "Print \(index + 1) · \(attachment.name)", text: attachment.text,
                                  card: card, principal: number(base), rows: rows, note: note)
        }
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

    init(attachments: [ChatAttachment], compared: @escaping (Comparison, String) -> Void) {
        self.compared = compared
        _sources = State(initialValue: CheckoutSource.read(attachments))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Uma compra. Todas as ofertas.").font(.system(.title2, design: .rounded).bold())
                    Text("Os preços e parcelas já estão preenchidos. Toque em comparar para receber o resumo; abra um print apenas se precisar corrigir algo ou incluir benefícios do cartão.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Cartão desconhecido não impede comparar preços. Confirme Inter Prime para estimar seus pontos; cashback ‘até’ um valor só entra quando você confirmar o benefício.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach($sources) { $source in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 14) {
                                if !source.note.isEmpty { Text(source.note).font(.caption).foregroundStyle(.secondary) }
                                Picker("Meio de pagamento", selection: $source.card) {
                                    ForEach(CheckoutCard.allCases, id: \.self) { card in Text(card.rawValue).tag(card) }
                                }.accessibilityIdentifier("checkoutCard")
                                if source.card == .inter {
                                    field("Compra elegível para pontos Prime", text: $source.principal)
                                    Text("Pontos normais = base elegível ÷ R$ 2,50, sem depender de antecipar. Juros não ampliam essa base.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                if source.card != .pix { field(source.card == .inter ? "Cashback confirmado (sem pontos Prime) em R$" : "Cashback/benefício confirmado em R$", text: $source.cashback) }
                                ForEach($source.rows) { $row in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Toggle(row.pix ? "Incluir Pix deste print" : "Incluir esta oferta", isOn: $row.included)
                                        if source.card != .pix && !row.pix { Stepper("Parcelas: \(row.count)x", value: $row.count, in: 0...36) }
                                        field(source.card == .pix || row.pix ? "Preço final no Pix" : "Total final de todas as parcelas", text: $row.total)
                                    }.padding(13).background(AppTheme.canvas, in: RoundedRectangle(cornerRadius: 14))
                                }
                                Button("Adicionar oferta") { source.rows.append(CheckoutRow()) }.buttonStyle(.bordered)
                                DisclosureGroup("Conferir texto lido") { Text(source.text).font(.caption).textSelection(.enabled) }
                            }.padding(.top, 12)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(source.name)
                                Text("\(source.rows.filter(\.included).count) ofertas · \(source.card == .choose ? "cartão opcional" : source.card.rawValue)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(17).background(AppTheme.card, in: RoundedRectangle(cornerRadius: 20))
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
                                ForEach(sources.filter { $0.card == .inter }) { source in Text(source.name).tag(source.id.uuidString) }
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
        .preferredColorScheme(.dark).tint(AppTheme.accent)
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 740)
        #endif
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
            for (index, source) in sources.enumerated() where source.rows.contains(where: \.included) {
                let principal = source.card == .inter ? try BrazilianInput.decimal(source.principal, label: "compra elegível Prime") : 0
                guard source.card != .inter || principal > 0 else { throw CalculationError.invalid("Informe o valor elegível da compra para calcular os pontos normais do Inter Prime.") }
                let cashback = source.card == .pix ? 0 : try BrazilianInput.decimal(source.cashback, label: "benefício confirmado")
                for row in source.rows where row.included {
                    let isPix = source.card == .pix || row.pix
                    let days = isPix ? [0] : try LocalSchedule.days(first: firstDate, count: row.count)
                    let total = try BrazilianInput.decimal(row.total, label: "total final")
                    guard isPix || source.card != .inter || principal <= total else { throw CalculationError.invalid("A base Prime não pode superar o total da compra parcelada.") }
                    let cardName = source.card == .choose ? "Cartão não identificado" : source.card.rawValue
                    offers.append(CheckoutOffer(name: "\(isPix ? "Pix" : cardName) · print \(index + 1)" + (isPix ? "" : " · \(row.count)x"),
                                                total: total, days: days, eligiblePrimeSpend: isPix ? 0 : principal, cashback: isPix ? 0 : cashback, benefitDay: benefitDay))
                }
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
            if sources.contains(where: { $0.card == .choose && $0.rows.contains(where: \.included) }) {
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
