import Foundation

public struct CheckoutOffer {
    public let name: String
    public let total: Decimal
    public let days: [Int]
    public let eligiblePrimeSpend: Decimal
    public let extraPoints: Decimal
    public let cashback: Decimal
    public let benefitDay: Int

    public init(name: String, total: Decimal, days: [Int], eligiblePrimeSpend: Decimal = 0,
                extraPoints: Decimal = 0, cashback: Decimal = 0, benefitDay: Int = 0) {
        self.name = name; self.total = total; self.days = days
        self.eligiblePrimeSpend = eligiblePrimeSpend; self.extraPoints = extraPoints
        self.cashback = cashback; self.benefitDay = benefitDay
    }
}

extension DecisionEngine {
    public static func checkout(_ offers: [CheckoutOffer], reaisPerThousand: Decimal, monthlyRate: Double) throws -> Comparison {
        guard (2...100).contains(offers.count) else { throw CalculationError.invalid("Confirme de 2 a 100 ofertas para comparar.") }
        let options = try offers.map { offer in
            guard !offer.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  offer.total > 0, !offer.total.isNaN, offer.cashback >= 0,
                  offer.cashback <= offer.total, !offer.cashback.isNaN,
                  cents(offer.cashback) == offer.cashback else {
                throw CalculationError.invalid("Revise os preços e benefícios. Zero não é uma oferta grátis.")
            }
            let normal = try earnedPoints(eligibleSpend: offer.eligiblePrimeSpend, reaisPerPoint: Decimal(string: "2.50")!)
            let points = try pointValue(points: normal + offer.extraPoints, reaisPerThousand: reaisPerThousand)
            _ = try pointValue(points: offer.extraPoints, reaisPerThousand: reaisPerThousand)
            let flows = try installments(total: offer.total, days: offer.days) + [
                CashFlow("Pontos normais + bônus extra confirmado", amount: -points, day: offer.benefitDay, kind: .benefit),
                CashFlow("Cashback confirmado", amount: -offer.cashback, day: offer.benefitDay, kind: .benefit)
            ]
            return try option(offer.name, flows: flows, rate: monthlyRate)
        }
        return Comparison(options: options)
    }
}
