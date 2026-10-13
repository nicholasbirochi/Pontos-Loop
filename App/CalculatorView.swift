import SwiftUI
import Charts
import DecisionCore

private let accent = AppTheme.accent
private let brazil = Locale(identifier: "pt_BR")
private func money(_ value: Double) -> String {
    value.formatted(.currency(code: "BRL").locale(brazil))
}
private func percent(_ value: Double) -> String {
    value.formatted(.number.locale(brazil).precision(.fractionLength(2))) + "%"
}

struct CalculatorView: View {
    @Binding var input: InputState
    @Binding var scenarios: [SavedScenario]
    var openAssistant: () -> Void
    var openHistory: () -> Void
    @FocusState private var editingNumber: Bool
    @State private var showSave = false
    @State private var scenarioName = ""

    private func decimal(_ value: String, _ label: String) throws -> Decimal {
        try BrazilianInput.decimal(value, label: label)
    }
    private func calculate(_ count: Int? = nil) throws -> Comparison {
        try input.calculate(count)
    }

    private var result: Result<Comparison, Error> { Result { try calculate() } }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        hero
                        modePicker
                        if case .success(let comparison) = result {
                            recommendation(comparison)
                        }
                        if geometry.size.width > 820 {
                            HStack(alignment: .top, spacing: 24) {
                                inputs.frame(maxWidth: 420)
                                output.frame(maxWidth: .infinity)
                            }
                        } else {
                            inputs
                            output
                        }
                        Text("Estimativa com as condições informadas. Benefícios em pontos têm valor estimado; o cálculo considera dinheiro disponível e pagamento integral da fatura.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(20).frame(maxWidth: 1120)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(AppTheme.canvas)
            .navigationTitle("CompraClara")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            #endif
            .toolbar {
                ToolbarItemGroup {
                    Button { openHistory() } label: { Label("Histórico", systemImage: "clock") }
                    Button {
                        scenarioName = input.mode.rawValue
                        showSave = true
                    } label: { Label("Salvar", systemImage: "bookmark") }
                    .disabled({ if case .failure = result { return true }; return false }())
                    .accessibilityIdentifier("saveScenario")
                }
            }
            .tint(accent)

            .alert("Salvar simulação", isPresented: $showSave) {
                TextField("Nome", text: $scenarioName)
                Button("Salvar") {
                    let name = scenarioName.trimmingCharacters(in: .whitespacesAndNewlines)
                    scenarios.insert(SavedScenario(name: name.isEmpty ? input.mode.rawValue : name, input: input), at: 0)
                    scenarios = Array(scenarios.prefix(100))
                    HistoryStore.save(scenarios)
                }
                Button("Cancelar", role: .cancel) {}
            }
            #if os(iOS)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Concluir") { editingNumber = false }
                }
            }
            #endif
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("DECIDA COM CLAREZA", systemImage: "sparkle")
                    .font(.caption.weight(.semibold)).tracking(1.2)
                Spacer()
                Image(systemName: "creditcard.fill")
                    .font(.title2).foregroundStyle(AppTheme.silver)
                    .accessibilityHidden(true)
            }
            Text("Seu dinheiro.\nSua melhor escolha.")
                .font(.system(.title, design: .rounded).weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("Pix ou cartão? A gente faz as contas.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
        }
        .foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [AppTheme.ink, Color(red: 0.11, green: 0.12, blue: 0.14)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var modePicker: some View {
        Picker("O que você quer comparar?", selection: $input.mode) {
            ForEach(CalculatorMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("scenarioPicker")
    }

    private var inputs: some View {
        VStack(spacing: 18) {
            panel("Condições da operação") {
                switch input.mode {
                case .purchase:
                    numberField("Preço de referência", text: $input.referencePrice, unit: "R$")
                    numberField("Desconto no Pix", text: $input.pixDiscount, unit: "%")
                    HStack {
                        ForEach(["0", "3", "5", "7", "10"], id: \.self) { value in
                            Button(value + "%") { input.pixDiscount = value }.buttonStyle(.bordered)
                        }
                    }.controlSize(.small)
                    numberField("Total no cartão, incluindo juros e taxas", text: $input.cardTotal, unit: "R$")
                    Button("Usar preço de referência no cartão") {
                        input.cardTotal = input.referencePrice
                        input.eligibleSpend = input.referencePrice
                    }.font(.caption)
                    Stepper("Quantidade de parcelas: \(input.installmentCount)",
                            value: $input.installmentCount, in: 1...36)
                    DatePicker("Primeiro vencimento", selection: $input.firstDate,
                               in: Date()..., displayedComponents: .date)
                    Text("Informe o total real cobrado. Se houver juros, inclua-os no total. O cronograma usa parcelas mensais iguais, com ajuste de centavos na última.")
                        .font(.caption).foregroundStyle(.secondary)
                case .anticipation:
                    numberField("Soma das parcelas restantes", text: $input.remainingTotal, unit: "R$")
                    Stepper("Parcelas restantes: \(input.remainingCount)",
                            value: $input.remainingCount, in: 1...36)
                    DatePicker("Próximo vencimento", selection: $input.firstDate,
                               in: Date()..., displayedComponents: .date)
                    numberField("Valor da oferta de quitação", text: $input.quote, unit: "R$")
                    DatePicker("Pagamento da quitação", selection: $input.paymentDate,
                               in: Date()..., displayedComponents: .date)
                    numberField("Pontos extras pela antecipação", text: $input.incrementalPoints, unit: "pts")
                    numberField("Valor estimado de 1.000 pontos", text: $input.reaisPerThousand, unit: "R$")
                    numberField("Bônus disponível em", text: $input.bonusDay, unit: "dias")
                    Text("Para antecipar uma fatura inteira, use 1 parcela. Copie a oferta do banco e conte apenas os pontos adicionais. A data é a do pagamento efetivo, que pode ser o vencimento da fatura.")
                        .font(.caption).foregroundStyle(.secondary)
                case .redemption:
                    numberField("Valor da fatura", text: $input.bill, unit: "R$")
                    numberField("Vencimento em", text: $input.billDays, unit: "dias")
                    numberField("Pontos que serão utilizados", text: $input.pointsSpent, unit: "pts")
                    numberField("Desconto oferecido na fatura", text: $input.redemptionDiscount, unit: "R$")
                    numberField("Valor alternativo de 1.000 pontos hoje", text: $input.alternativeValue, unit: "R$")
                    Text("Compare o resgate com o valor líquido que esses pontos teriam em outro uso que você realmente faria. O desconto de R$ 15 é apenas um exemplo editável.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            panel("Rendimento do dinheiro") {
                numberField("Rendimento líquido mensal", text: $input.monthlyRate, unit: "% a.m.")
                HStack {
                    ForEach(["0", "0,5", "0,8", "1"], id: \.self) { value in
                        Button(value + "%") { input.monthlyRate = value }.buttonStyle(.bordered)
                    }
                }.controlSize(.small)
                Text("Use 0% se o dinheiro não ficar investido. Informe a taxa após impostos e custos, com liquidez para pagar as parcelas. 0,8% é uma hipótese, não uma taxa atual de investimento.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if input.mode == .purchase {
                panel("Pontos e cashback") {
                    Toggle("Considerar pontos da compra", isOn: $input.rewardsEnabled)
                    if input.rewardsEnabled {
                        numberField("Gasto para ganhar 1 ponto", text: $input.reaisPerPoint, unit: "R$")
                        numberField("Valor estimado de 1.000 pontos", text: $input.reaisPerThousand, unit: "R$")
                        numberField("Valor da compra elegível a pontos", text: $input.eligibleSpend, unit: "R$")
                        Button("Usar exemplo de pontos") {
                            input.reaisPerPoint = "2,50"
                            input.reaisPerThousand = "20,00"
                            input.eligibleSpend = input.referencePrice
                        }.font(.caption)
                        Text("Exemplo editável: 1 ponto a cada R$ 2,50 e R$ 20 por mil pontos. Use os valores do seu programa e do resgate que pretende fazer.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    numberField("Cashback adicional confirmado", text: $input.cashback, unit: "R$")
                    numberField("Benefícios utilizáveis em", text: $input.benefitDay, unit: "dias")
                    Text("Informe cashback somente se ele acumular com os pontos. O prazo é uma aproximação única para todos os benefícios da compra.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private var output: some View {
        switch result {
        case .failure(let error):
            panel("Revise a simulação") {
                Label(error.localizedDescription, systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
            }
        case .success(let comparison):
            VStack(spacing: 18) {
                panel("Comparação em reais de hoje") {
                    ForEach(comparison.options, id: \.name) { option in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.name).font(.subheadline.weight(.semibold))
                                Text("Desembolso: \(money(DecisionEngine.number(option.cashOutlay)))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(money(option.presentCost)).font(.headline).monospacedDigit()
                        }
                    }
                    Chart(comparison.options, id: \.name) { option in
                        BarMark(x: .value("Opção", option.name), y: .value("Custo presente", option.presentCost))
                            .foregroundStyle(option.name == comparison.ordered[0].name ? accent : Color.gray.opacity(0.45))
                    }.frame(height: 170)
                    .accessibilityLabel("Custos econômicos das opções. Os valores também estão escritos acima.")
                    Text("O custo econômico desconta pagamentos futuros pelo rendimento informado e considera os benefícios. Ele pode ser diferente do valor que sai da conta.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if input.mode == .purchase {
                    equilibrium(comparison)
                }
                if input.mode == .anticipation {
                    bonusThreshold(comparison)
                }
                if input.mode == .redemption {
                    redemptionMetrics
                }
                panel("Memória do cálculo") {
                    ForEach(comparison.options, id: \.name) { option in
                        DisclosureGroup(option.name) {
                            ForEach(Array(option.flows.enumerated()), id: \.offset) { _, flow in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(flow.label).font(.caption)
                                        Text("Daqui a \(flow.day) dias").font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(money(DecisionEngine.number(flow.amount))).font(.caption).monospacedDigit()
                                }.padding(.vertical, 4)
                            }
                        }
                    }
                    ShareLink(item: summary(comparison)) {
                        Label("Compartilhar resumo", systemImage: "square.and.arrow.up")
                    }.buttonStyle(.bordered)
                }
            }
        }
    }

    private func recommendation(_ comparison: Comparison) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(comparison.difference <= 0.01 ? "QUASE IGUAIS" : "A ESCOLHA MAIS VANTAJOSA",
                  systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.bold)).tracking(0.8).foregroundStyle(accent)
            Text(comparison.recommendation)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .accessibilityIdentifier("recommendation")
            Text(comparison.difference <= 0.01 ? "As duas opções ficam praticamente no mesmo valor." :
                    "Vantagem estimada de \(money(comparison.difference)) em reais de hoje.")
                .font(.subheadline).foregroundStyle(.secondary)
            Divider()
            ForEach(comparison.options, id: \.name) { option in
                HStack {
                    Text(option.name).font(.subheadline)
                    Spacer()
                    Text(money(option.presentCost)).font(.subheadline.bold()).monospacedDigit()
                }
            }
            Button(action: openAssistant) {
                Label("Noah, me explica?", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.bordered).accessibilityIdentifier("explainResult")
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(accent.opacity(0.3)))
        .shadow(color: accent.opacity(0.06), radius: 12, y: 5)
    }

    @ViewBuilder private func equilibrium(_ comparison: Comparison) -> some View {
        if let price = try? decimal(input.referencePrice, "preço"),
           let threshold = try? DecisionEngine.breakEvenDiscount(
                referencePrice: price, cardPresentCost: comparison.options[1].presentCost) {
            panel("Quando o Pix começa a compensar") {
                Text(percent(threshold)).font(.system(.largeTitle, design: .rounded).weight(.bold)).foregroundStyle(accent)
                Text(threshold < 0 ? "O cartão custa mais que o preço de referência, mesmo sem desconto no Pix." :
                    threshold > 100 ? "Não há desconto viável de 0% a 100% que supere esses benefícios estimados do cartão. Confira os valores." :
                    "Acima desse desconto, o Pix tem menor custo. Abaixo dele, o cartão tem menor custo.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Divider()
                Text("Variação do prazo").font(.subheadline.weight(.semibold))
                ForEach([1, 3, 6, 10, 12], id: \.self) { count in
                    if let row = try? calculate(count),
                       let limit = try? DecisionEngine.breakEvenDiscount(
                            referencePrice: price, cardPresentCost: row.options[1].presentCost) {
                        HStack {
                            Text("\(count)x")
                            Spacer()
                            Text(percent(limit)).monospacedDigit()
                        }.font(.subheadline)
                    }
                }
                Text("Mantém o mesmo total no cartão em todos os prazos. Se a loja mudar o preço com a quantidade de parcelas, simule cada oferta separadamente.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func bonusThreshold(_ comparison: Comparison) -> some View {
        if let quote = try? decimal(input.quote, "oferta"),
           let milheiro = try? decimal(input.reaisPerThousand, "milheiro"),
           let payDay = try? LocalSchedule.day(input.paymentDate),
           let bonusDay = try? BrazilianInput.day(input.bonusDay, label: "prazo"),
           let rateDecimal = try? decimal(input.monthlyRate, "rendimento") {
            let rate = DecisionEngine.number(rateDecimal) / 100
            let quotePV = DecisionEngine.number(quote) / pow(1 + rate, Double(payDay) / 30)
            let requiredPV = max(0, quotePV - comparison.options[0].presentCost)
            let requiredValue = requiredPV * pow(1 + rate, Double(bonusDay) / 30)
            panel("Bônus necessário para empatar") {
                Text(money(requiredValue)).font(.title.weight(.bold)).foregroundStyle(accent)
                if milheiro > 0 {
                    Text("Aproximadamente \((requiredValue * 1000 / DecisionEngine.number(milheiro)).rounded(.up).formatted(.number.locale(brazil).precision(.fractionLength(0)))) pontos extras.")
                } else {
                    Text("Com valor dos pontos igual a zero, nenhum bônus em pontos cobre uma diferença positiva.")
                }
                Text("Valor do bônus na data informada. Se a quitação já tiver menor custo, o mínimo será zero.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var redemptionMetrics: some View {
        if let points = try? decimal(input.pointsSpent, "pontos"), points > 0,
           let discount = try? decimal(input.redemptionDiscount, "desconto") {
            panel("Valor deste resgate") {
                Text("\(money(DecisionEngine.number(discount / points * 1000))) / 1.000 pts")
                    .font(.title2.weight(.bold)).foregroundStyle(accent)
                Text("Compare com o seu valor alternativo. Se o desconto só reduzir uma fatura futura, seu valor em reais de hoje será menor quando houver rendimento positivo.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func summary(_ comparison: Comparison) -> String {
        let options = comparison.options.map { "\($0.name): custo econômico \(money($0.presentCost))" }.joined(separator: "\n")
        return "Compra Clara\n\(comparison.recommendation)\n\(options)\nDiferença: \(money(comparison.difference))\nRendimento líquido mensal: \(input.monthlyRate)%\nEstimativa segundo as condições informadas."
    }

    private func numberField(_ title: String, text: Binding<String>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.weight(.medium))
            HStack {
                TextField("0", text: text)
                    .textFieldStyle(.plain)
                    .font(.title3.monospacedDigit())
                    .focused($editingNumber)
                    #if os(iOS)
                    .keyboardType(.numbersAndPunctuation)
                    #endif
                    .accessibilityLabel(title)
                    .accessibilityValue(text.wrappedValue + " " + unit)
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
            .padding(14).background(AppTheme.canvas)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.system(.headline, design: .rounded))
            content()
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.08)))
    }
}
