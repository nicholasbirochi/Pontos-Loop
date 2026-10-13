import Foundation

public enum CalculationError: Error, LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

public enum FlowKind: String, Codable { case payment, benefit, opportunity }

public struct CashFlow: Codable, Equatable {
    public let label: String
    public let amount: Decimal
    public let day: Int
    public let kind: FlowKind
    public init(_ label: String, amount: Decimal, day: Int, kind: FlowKind = .payment) {
        self.label = label; self.amount = amount; self.day = day; self.kind = kind
    }
}

public struct OptionResult: Codable {
    public let name: String
    public let flows: [CashFlow]
    public let presentCost: Double
    public var cashOutlay: Decimal {
        flows.filter { $0.kind == .payment }.reduce(0) { $0 + $1.amount }
    }
}

public struct Comparison {
    public let options: [OptionResult]
    public var ordered: [OptionResult] { options.sorted { $0.presentCost < $1.presentCost } }
    public var difference: Double { ordered[1].presentCost - ordered[0].presentCost }
    public var recommendation: String {
        difference <= 0.01 ? "Empate econômico" : ordered[0].name
    }
}

public enum DecisionEngine {
    public static func number(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    public static func cents(_ value: Decimal) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, 2, .plain)
        return result
    }

    private static func nonnegative(_ value: Decimal, _ label: String) throws {
        guard !value.isNaN, number(value).isFinite, value >= 0 else {
            throw CalculationError.invalid("\(label) deve ser um número maior ou igual a zero.")
        }
    }

    public static func presentValue(_ flows: [CashFlow], monthlyRate: Double) throws -> Double {
        guard monthlyRate.isFinite, monthlyRate > -1, monthlyRate <= 1 else {
            throw CalculationError.invalid("O rendimento mensal deve ser maior que -100% e até 100%.")
        }
        guard flows.allSatisfy({ $0.day >= 0 && $0.day <= 36_600 &&
            !$0.amount.isNaN && number($0.amount).isFinite }) else {
            throw CalculationError.invalid("Revise os valores e os prazos, entre 0 e 36.600 dias.")
        }
        let result = flows.reduce(0.0) {
            $0 + number($1.amount) / pow(1 + monthlyRate, Double($1.day) / 30)
        }
        guard result.isFinite else { throw CalculationError.invalid("Resultado fora do intervalo suportado.") }
        return result
    }

    public static func option(_ name: String, flows: [CashFlow], rate: Double) throws -> OptionResult {
        OptionResult(name: name, flows: flows, presentCost: try presentValue(flows, monthlyRate: rate))
    }

    // O ajuste de centavos fica na última parcela; a soma será exatamente o total informado.
    public static func installments(total: Decimal, days: [Int]) throws -> [CashFlow] {
        try nonnegative(total, "Total")
        guard cents(total) == total else {
            throw CalculationError.invalid("O total deve ter no máximo duas casas decimais.")
        }
        guard !days.isEmpty, days.count <= 120, days == days.sorted(),
              days.allSatisfy({ $0 >= 0 && $0 <= 36_600 }) else {
            throw CalculationError.invalid("Informe de 1 a 120 vencimentos válidos e ordenados.")
        }
        let unit = cents(total / Decimal(days.count))
        let last = total - unit * Decimal(days.count - 1)
        guard last >= 0 else {
            throw CalculationError.invalid("O valor é muito pequeno para essa quantidade de parcelas.")
        }
        return days.enumerated().map { index, day in
            CashFlow("Parcela \(index + 1)", amount: index == days.count - 1 ? last : unit, day: day)
        }
    }

    public static func pointValue(points: Decimal, reaisPerThousand: Decimal) throws -> Decimal {
        try nonnegative(points, "Pontos")
        try nonnegative(reaisPerThousand, "Valor do milheiro")
        return points * reaisPerThousand / 1000
    }

    public static func earnedPoints(eligibleSpend: Decimal, reaisPerPoint: Decimal) throws -> Decimal {
        try nonnegative(eligibleSpend, "Compra elegível")
        guard !reaisPerPoint.isNaN, number(reaisPerPoint).isFinite, reaisPerPoint > 0 else {
            throw CalculationError.invalid("O gasto por ponto deve ser maior que zero.")
        }
        // Estimativa contínua. O banco pode arredondar/agrupar de outra forma.
        return eligibleSpend / reaisPerPoint
    }

    public static func purchase(referencePrice: Decimal, pixPrice: Decimal, cardTotal: Decimal,
                                days: [Int], eligibleSpend: Decimal, reaisPerPoint: Decimal,
                                reaisPerThousand: Decimal, rewardsEnabled: Bool,
                                cashback: Decimal, benefitDay: Int, monthlyRate: Double) throws -> Comparison {
        try nonnegative(referencePrice, "Preço de referência")
        try nonnegative(pixPrice, "Preço no Pix")
        try nonnegative(cashback, "Cashback")
        guard referencePrice > 0 else { throw CalculationError.invalid("O preço deve ser maior que zero.") }
        guard eligibleSpend <= cardTotal else {
            throw CalculationError.invalid("A base elegível não pode superar o total no cartão.")
        }
        var cardFlows = try installments(total: cardTotal, days: days)
        if rewardsEnabled {
            let points = try earnedPoints(eligibleSpend: eligibleSpend, reaisPerPoint: reaisPerPoint)
            let value = try pointValue(points: points, reaisPerThousand: reaisPerThousand)
            cardFlows.append(CashFlow("Pontos estimados", amount: -value, day: benefitDay, kind: .benefit))
        }
        if cashback > 0 {
            cardFlows.append(CashFlow("Cashback adicional", amount: -cashback, day: benefitDay, kind: .benefit))
        }
        return Comparison(options: [
            try option("Pagar no Pix", flows: [CashFlow("Pix hoje", amount: pixPrice, day: 0)], rate: monthlyRate),
            try option("Pagar no cartão", flows: cardFlows, rate: monthlyRate)
        ])
    }

    // Pode ficar abaixo de 0% ou acima de 100%; não truncar e criar um equilíbrio inexistente.
    public static func breakEvenDiscount(referencePrice: Decimal, cardPresentCost: Double) throws -> Double {
        guard referencePrice > 0, !referencePrice.isNaN, cardPresentCost.isFinite else {
            throw CalculationError.invalid("Revise o preço e o custo do cartão.")
        }
        return 100 * (1 - cardPresentCost / number(referencePrice))
    }

    // Só incluir recompensas que mudam entre as opções. Pontos já ganhos ficam de fora.
    public static func anticipation(remaining: [CashFlow], quote: Decimal, paymentDay: Int,
                                    incrementalPoints: Decimal, reaisPerThousand: Decimal,
                                    bonusDay: Int, monthlyRate: Double) throws -> Comparison {
        try nonnegative(quote, "Oferta de quitação")
        guard cents(quote) == quote else {
            throw CalculationError.invalid("A oferta deve ter no máximo duas casas decimais.")
        }
        guard !remaining.isEmpty, remaining.allSatisfy({ $0.kind == .payment && $0.amount >= 0 }),
              let earliest = remaining.map(\.day).min(), paymentDay >= 0, paymentDay <= earliest else {
            throw CalculationError.invalid("A quitação precisa ocorrer até o primeiro vencimento.")
        }
        let bonus = try pointValue(points: incrementalPoints, reaisPerThousand: reaisPerThousand)
        guard incrementalPoints == 0 || bonusDay >= paymentDay else {
            throw CalculationError.invalid("O bônus não pode ficar disponível antes do pagamento.")
        }
        return Comparison(options: [
            try option("Manter os vencimentos", flows: remaining, rate: monthlyRate),
            try option("Antecipar pagamento", flows: [
                CashFlow("Quitação", amount: quote, day: paymentDay),
                CashFlow("Bônus incremental", amount: -bonus, day: bonusDay, kind: .benefit)
            ], rate: monthlyRate)
        ])
    }

    // Pontos gastos também têm custo econômico. Não tratar o desconto como dinheiro gratuito.
    public static func redemption(bill: Decimal, billDay: Int, pointsSpent: Decimal,
                                  offeredDiscount: Decimal, alternativeValuePerThousand: Decimal,
                                  monthlyRate: Double) throws -> Comparison {
        try nonnegative(bill, "Fatura")
        try nonnegative(offeredDiscount, "Desconto")
        guard cents(bill) == bill, cents(offeredDiscount) == offeredDiscount else {
            throw CalculationError.invalid("Fatura e desconto devem ter no máximo duas casas decimais.")
        }
        guard offeredDiscount <= bill, pointsSpent > 0 else {
            throw CalculationError.invalid("Informe pontos positivos e desconto que não supere a fatura.")
        }
        let opportunity = try pointValue(points: pointsSpent, reaisPerThousand: alternativeValuePerThousand)
        return Comparison(options: [
            try option("Pagar e guardar os pontos", flows: [
                CashFlow("Fatura", amount: bill, day: billDay)
            ], rate: monthlyRate),
            try option("Usar os pontos na fatura", flows: [
                CashFlow("Fatura restante", amount: bill - offeredDiscount, day: billDay),
                CashFlow("Valor dos pontos utilizados hoje", amount: opportunity, day: 0, kind: .opportunity)
            ], rate: monthlyRate)
        ])
    }
}
