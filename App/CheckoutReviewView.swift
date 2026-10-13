import SwiftUI
import DecisionCore

struct CheckoutBatch: Identifiable {
    let id = UUID()
    let attachments: [ChatAttachment]
}

private enum CheckoutCard: String, CaseIterable {
    case choose = "Confirme o meio de pagamento"
    case pix = "Pix", inter = "Inter Prime", itau = "Itaú", mercado = "Cartão Mercado Livre", other = "Outro cartão"
}

private struct CheckoutRow: Identifiable {
    let id = UUID()
    var included = true
    var count = 0
    var total = "0"
    var pix = false
}

private struct CheckoutSource: Identifiable {
    let id: UUID
    let name: String
    let text: String
    var card: CheckoutCard = .choose
    var principal = "0"
    var cashback = "0"
    var rows: [CheckoutRow]
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
        _sources = State(initialValue: attachments.enumerated().map { index, attachment in
            let read = ExtractedOffers.read(attachment.text)
            let pixOnly = !read.pixPrices.isEmpty && read.installments.isEmpty
            var rows = read.pixPrices.map { CheckoutRow(count: 1, total: Self.number($0), pix: true) }
                + read.installments.map { CheckoutRow(count: $0.count, total: Self.number($0.total)) }
            if rows.isEmpty { rows = [CheckoutRow()] }
            return CheckoutSource(id: attachment.id, name: "Print \(index + 1) · \(attachment.name)", text: attachment.text,
                                  card: pixOnly ? .pix : .choose,
                                  principal: read.installments.first(where: { $0.count == 1 }).map { Self.number($0.total) } ?? "0", rows: rows)
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Uma compra. Todas as ofertas.").font(.system(.title2, design: .rounded).bold())
                    Text("1. Confirme o cartão selecionado em cada print.\n2. Confira o total e as parcelas de cada oferta.\n3. Compare para receber o diagnóstico aqui no chat.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("O print pode mostrar dois cartões no cabeçalho. Escolha o que estava selecionado. Cashback ‘até’ um valor depende de condições: informe somente o benefício confirmado.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach($sources) { $source in
                        DisclosureGroup(source.name) {
                            VStack(alignment: .leading, spacing: 14) {
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
                guard source.card != .choose else { throw CalculationError.invalid("Confirme o meio de pagamento no print \(index + 1).") }
                let principal = source.card == .inter ? try BrazilianInput.decimal(source.principal, label: "compra elegível Prime") : 0
                guard source.card != .inter || principal > 0 else { throw CalculationError.invalid("Informe o valor elegível da compra para calcular os pontos normais do Inter Prime.") }
                let cashback = source.card == .pix ? 0 : try BrazilianInput.decimal(source.cashback, label: "benefício confirmado")
                for row in source.rows where row.included {
                    let isPix = source.card == .pix || row.pix
                    let days = isPix ? [0] : try LocalSchedule.days(first: firstDate, count: row.count)
                    let total = try BrazilianInput.decimal(row.total, label: "total final")
                    guard isPix || source.card != .inter || principal <= total else { throw CalculationError.invalid("A base Prime não pode superar o total da compra parcelada.") }
                    offers.append(CheckoutOffer(name: "\(isPix ? "Pix" : source.card.rawValue) · print \(index + 1)" + (isPix ? "" : " · \(row.count)x"),
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
            var lines = ["Comparei as ofertas que você confirmou:"]
            for (index, option) in comparison.ordered.enumerated() {
                lines.append("\(index + 1). \(option.name): \(Self.money(option.presentCost)) em reais de hoje; total pago \(Self.money(DecisionEngine.number(option.cashOutlay))).")
            }
            let tied = comparison.ordered.filter { $0.presentCost - comparison.ordered[0].presentCost <= 0.01 }
            lines.append(tied.count > 1 ? "\nEmpate econômico entre: " + tied.map(\.name).joined(separator: ", ") + "." : "\nA mais vantajosa entre as ofertas confirmadas é \(comparison.ordered[0].name), com vantagem de \(Self.money(comparison.difference)) sobre a segunda opção.")
            if quote == 0 { lines.append("Antecipação do Inter ainda não comparada: falta a oferta real de quitação e seu bônus extra.") }
            if thousand == 0 { lines.append("Valor do milheiro em zero: os pontos ainda não reduzem o custo em reais.") }
            lines.append("Pontos normais só nas compras elegíveis do Inter Prime confirmado, uma vez por alternativa. Itaú e Mercado Livre usam apenas os benefícios em reais que você informou. O ranking usa rendimento líquido de \(monthlyRate)% a.m. e as datas da revisão.")
            compared(comparison, lines.joined(separator: "\n")); dismiss()
        } catch { self.error = error.localizedDescription }
    }

    private static func number(_ value: Decimal) -> String {
        value.formatted(.number.locale(Locale(identifier: "pt_BR")).grouping(.never).precision(.fractionLength(2)))
    }
    private static func money(_ value: Double) -> String { value.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR"))) }
}
