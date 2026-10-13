import Foundation

public enum PurchaseCase: String, CaseIterable, Identifiable {
    case noInterest = "Parcelar sem juros"
    case withInterest = "Parcelar a compra com juros"
    case pix = "Pix com desconto"
    case anticipate = "Antecipar + pontos extras"
    public var id: String { rawValue }
}

public struct CaseDiagnosis: Identifiable {
    public let kind: PurchaseCase
    public let option: OptionResult?
    public let normalPoints: Decimal
    public let extraPoints: Decimal
    public let explanation: String
    public var id: String { kind.id }
}

public struct FourCaseReport {
    public let cases: [CaseDiagnosis]
    public let pointValueIsMissing: Bool
    public var comparison: Comparison? {
        let options = cases.compactMap(\.option)
        return options.count >= 2 ? Comparison(options: options) : nil
    }
    public var summary: String {
        let locale = Locale(identifier: "pt_BR")
        func money(_ value: Double) -> String { value.formatted(.currency(code: "BRL").locale(locale)) }
        var lines = ["Diagnóstico dos 4 cenários:"]
        for item in cases {
            if let option = item.option {
                let points = (item.normalPoints + item.extraPoints).formatted(.number.locale(locale).precision(.fractionLength(0...2)))
                lines.append("• \(item.kind.rawValue): \(money(option.presentCost)) em reais de hoje; \(points) pontos estimados. \(item.explanation)")
            } else {
                lines.append("• \(item.kind.rawValue): \(item.explanation)")
            }
        }
        if let comparison {
            let tied = comparison.ordered.filter { $0.presentCost - comparison.ordered[0].presentCost <= 0.01 }
            if tied.count > 1 {
                lines.append("\nEmpate econômico entre: " + tied.map(\.name).joined(separator: ", ") + ".")
            } else {
                lines.append("\nEntre os cenários preenchidos, o menor custo é: \(comparison.recommendation). Vantagem de \(money(comparison.difference)) sobre a segunda opção.")
            }
        } else {
            lines.append("\nPreencha pelo menos 2 cenários para eu indicar o menor custo.")
        }
        if pointValueIsMissing { lines.append("O valor dos pontos está zerado: o ranking ainda não desconta seu benefício em reais.") }
        lines.append("Pontos normais entram uma vez nas opções elegíveis de cartão. Antecipar soma somente o bônus extra informado, sem duplicar os pontos da compra.")
        return lines.joined(separator: "\n")
    }
}

extension DecisionEngine {
    /// Compara ofertas para a mesma compra; não representa financiamento de fatura.
    public static func fourCases(principal: Decimal, pixPrice: Decimal,
                                 noInterestDays: [Int], interestTotal: Decimal, interestDays: [Int],
                                 anticipationQuote: Decimal, anticipationDay: Int, firstDueDay: Int,
                                 extraPoints: Decimal, reaisPerThousand: Decimal,
                                 normalPointDay: Int, anticipatedPointDay: Int,
                                 monthlyRate: Double) throws -> FourCaseReport {
        _ = try presentValue([], monthlyRate: monthlyRate)
        guard cents(principal) == principal else { throw CalculationError.invalid("O valor da compra deve ter no máximo duas casas decimais.") }
        let ordinary = try earnedPoints(eligibleSpend: principal, reaisPerPoint: Decimal(string: "2.50")!)
        let normalValue = try pointValue(points: ordinary, reaisPerThousand: reaisPerThousand)
        let extraValue = try pointValue(points: extraPoints, reaisPerThousand: reaisPerThousand)
        var diagnoses: [CaseDiagnosis] = []
        for kind in PurchaseCase.allCases {
            do {
                let flows: [CashFlow]
                let note: String
                switch kind {
                case .noInterest:
                    guard principal > 0, !noInterestDays.isEmpty else { throw CalculationError.invalid("Informe o valor da compra e as parcelas sem juros.") }
                    flows = try installments(total: principal, days: noInterestDays) + [
                        CashFlow("Pontos normais da compra", amount: -normalValue, day: normalPointDay, kind: .benefit)
                    ]
                    note = "Pontos normais estimados sobre a compra elegível."
                case .withInterest:
                    guard principal > 0, interestTotal > 0, !interestDays.isEmpty else { throw CalculationError.invalid("Informe o valor da compra, o total com juros e suas parcelas.") }
                    guard interestTotal >= principal else { throw CalculationError.invalid("O total com juros não pode ser menor que o valor da compra sem juros.") }
                    flows = try installments(total: interestTotal, days: interestDays) + [
                        CashFlow("Pontos normais da compra", amount: -normalValue, day: normalPointDay, kind: .benefit)
                    ]
                    note = "Juros não geram pontos extras; a base é a compra elegível."
                case .pix:
                    guard pixPrice > 0 else { throw CalculationError.invalid("Informe o preço final no Pix; zero significa não informado.") }
                    guard cents(pixPrice) == pixPrice else { throw CalculationError.invalid("Use no máximo duas casas no preço Pix.") }
                    flows = [CashFlow("Pix hoje", amount: pixPrice, day: 0)]
                    note = "Pagamento hoje, sem os pontos de uma compra no cartão."
                case .anticipate:
                    guard principal > 0, anticipationQuote > 0 else { throw CalculationError.invalid("Informe o valor da compra e a oferta real de quitação do Inter.") }
                    guard cents(anticipationQuote) == anticipationQuote,
                          anticipationDay >= 0, anticipationDay <= firstDueDay,
                          anticipatedPointDay >= anticipationDay else { throw CalculationError.invalid("Revise centavos e datas: a quitação deve ser até o vencimento, com pontos disponíveis após pagar.") }
                    flows = [
                        CashFlow("Quitação antecipada", amount: anticipationQuote, day: anticipationDay),
                        CashFlow("Pontos normais da compra", amount: -normalValue, day: anticipatedPointDay, kind: .benefit),
                        CashFlow("Bônus extra da antecipação", amount: -extraValue, day: anticipatedPointDay, kind: .benefit)
                    ]
                    note = extraPoints > 0 ? "Pontos normais + apenas o bônus extra da oferta." : "Pontos normais mantidos; nenhum bônus extra informado."
                }
                let result = try option(kind.rawValue, flows: flows, rate: monthlyRate)
                diagnoses.append(CaseDiagnosis(kind: kind, option: result,
                    normalPoints: kind == .pix ? 0 : ordinary,
                    extraPoints: kind == .anticipate ? extraPoints : 0, explanation: note))
            } catch {
                diagnoses.append(CaseDiagnosis(kind: kind, option: nil, normalPoints: 0, extraPoints: 0,
                                               explanation: error.localizedDescription))
            }
        }
        return FourCaseReport(cases: diagnoses, pointValueIsMissing: reaisPerThousand == 0)
    }
}
