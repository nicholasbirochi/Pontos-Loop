import Foundation
import DecisionCore

enum CalculatorMode: String, Codable, CaseIterable, Identifiable {
    case fourCases = "4 cenários"
    case purchase = "Compra", anticipation = "Antecipar", redemption = "Pontos"
    var id: String { rawValue }
}

struct InputState: Codable, Equatable {
    var mode: CalculatorMode = .fourCases
    var referencePrice = "0"
    var directPixPrice: String? = "0"
    var pixDiscount = "0"
    var cardTotal = "0"
    var installmentCount = 0
    var firstDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    var monthlyRate = "0"
    var reaisPerPoint = "0"
    var reaisPerThousand = "0"
    var eligibleSpend = "0"
    var rewardsEnabled = false
    var cashback = "0"
    var benefitDay = "0"
    var remainingTotal = "0"
    var remainingCount = 0
    var quote = "0"
    var paymentDate = Date()
    var incrementalPoints = "0"
    var bonusDay = "0"
    var bill = "0"
    var billDays = "0"
    var pointsSpent = "0"
    var redemptionDiscount = "0"
    var alternativeValue = "0"

    var interestTotal: String? = "0"
    var interestCount: Int? = 0

    static func restore() -> InputState {
        guard let data = UserDefaults.standard.data(forKey: "compra-clara-draft-v1"),
              let result = try? JSONDecoder().decode(InputState.self, from: data) else { return InputState() }
        return result
    }
    func persist() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "compra-clara-draft-v1")
        }
    }
}

enum BrazilianInput {
    static func decimal(_ raw: String, label: String) throws -> Decimal {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[+-]?(?:[0-9]+(?:[.,][0-9]+)?|[0-9]{1,3}(?:\.[0-9]{3})+(?:,[0-9]+)?)$"#
        guard input.range(of: pattern, options: .regularExpression) != nil else {
            throw CalculationError.invalid("Preencha \(label) com um número válido.")
        }
        let grouped = input.range(of: #"^[+-]?[0-9]{1,3}(?:\.[0-9]{3})+$"#,
                                  options: .regularExpression) != nil
        let normalized = input.contains(",") || grouped
            ? input.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            : input
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              !value.isNaN else { throw CalculationError.invalid("Revise \(label).") }
        return value
    }
    static func day(_ raw: String, label: String) throws -> Int {
        let value = try decimal(raw, label: label)
        let d = DecisionEngine.number(value)
        guard d >= 0, d <= 36_600, d.rounded() == d else {
            throw CalculationError.invalid("\(label) deve ser inteiro entre 0 e 36.600.")
        }
        return Int(d)
    }
}

enum LocalSchedule {
    static func day(_ date: Date) throws -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? -1
        guard days >= 0 else { throw CalculationError.invalid("Escolha uma data a partir de hoje.") }
        return days
    }
    static func days(first: Date, count: Int) throws -> [Int] {
        guard (1...120).contains(count) else { throw CalculationError.invalid("Quantidade inválida.") }
        return try (0..<count).map {
            guard let date = Calendar.current.date(byAdding: .month, value: $0, to: first) else {
                throw CalculationError.invalid("Não foi possível calcular o vencimento.")
            }
            return try day(date)
        }
    }
}

struct SavedScenario: Codable, Identifiable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var name: String
    var input: InputState
}

enum HistoryStore {
    static func load() -> [SavedScenario] {
        guard let data = UserDefaults.standard.data(forKey: "compra-clara-history-v1"),
              let result = try? JSONDecoder().decode([SavedScenario].self, from: data) else { return [] }
        return result
    }
    static func save(_ scenarios: [SavedScenario]) {
        if let data = try? JSONEncoder().encode(scenarios) {
            UserDefaults.standard.set(data, forKey: "compra-clara-history-v1")
        }
    }
}

extension InputState {
    func calculate(_ count: Int? = nil) throws -> Comparison {
        let input = self
        func decimal(_ value: String, _ label: String) throws -> Decimal {
            try BrazilianInput.decimal(value, label: label)
        }
        let rate = DecisionEngine.number(try decimal(input.monthlyRate, "rendimento")) / 100
        switch input.mode {
        case .fourCases:
            guard let comparison = try diagnoseFourCases().comparison else {
                throw CalculationError.invalid("Preencha pelo menos 2 cenários para comparar. Zero significa não informado.")
            }
            return comparison
        case .purchase:
            let card = try decimal(input.cardTotal, "total no cartão")
            let pix: Decimal
            let price: Decimal
            if let direct = input.directPixPrice {
                pix = try decimal(direct, "preço no Pix")
                guard DecisionEngine.cents(pix) == pix else {
                    throw CalculationError.invalid("O preço no Pix deve ter no máximo duas casas decimais.")
                }
                price = max(card, pix)
            } else {
                price = try decimal(input.referencePrice, "preço de referência")
                let discount = try decimal(input.pixDiscount, "desconto no Pix")
                guard discount >= 0, discount <= 100 else {
                    throw CalculationError.invalid("O desconto deve ficar entre 0% e 100%.")
                }
                pix = DecisionEngine.cents(price * (1 - discount / 100))
            }
            guard card > 0, pix > 0 else {
                throw CalculationError.invalid("Preencha o preço no Pix e o total no cartão. Zero significa não informado.")
            }
            return try DecisionEngine.purchase(
                referencePrice: price,
                pixPrice: pix,
                cardTotal: card,
                days: try LocalSchedule.days(first: input.firstDate, count: count ?? input.installmentCount),
                eligibleSpend: input.rewardsEnabled ? decimal(input.eligibleSpend, "base elegível") : 0,
                reaisPerPoint: input.rewardsEnabled ? decimal(input.reaisPerPoint, "gasto por ponto") : 1,
                reaisPerThousand: input.rewardsEnabled ? decimal(input.reaisPerThousand, "valor do milheiro") : 0,
                rewardsEnabled: input.rewardsEnabled,
                cashback: try decimal(input.cashback, "cashback adicional"),
                benefitDay: try BrazilianInput.day(input.benefitDay, label: "prazo dos benefícios"),
                monthlyRate: rate)
        case .anticipation:
            guard try decimal(input.remainingTotal, "saldo") > 0,
                  decimal(input.quote, "oferta de quitação") > 0 else {
                throw CalculationError.invalid("Informe o saldo e a oferta de quitação. Zero significa não informado.")
            }
            let remaining = try DecisionEngine.installments(
                total: decimal(input.remainingTotal, "saldo das parcelas"),
                days: LocalSchedule.days(first: input.firstDate, count: input.remainingCount))
            return try DecisionEngine.anticipation(
                remaining: remaining, quote: decimal(input.quote, "oferta de quitação"),
                paymentDay: LocalSchedule.day(input.paymentDate),
                incrementalPoints: decimal(input.incrementalPoints, "pontos extras"),
                reaisPerThousand: decimal(input.reaisPerThousand, "valor do milheiro"),
                bonusDay: BrazilianInput.day(input.bonusDay, label: "prazo do bônus"),
                monthlyRate: rate)
        case .redemption:
            return try DecisionEngine.redemption(
                bill: decimal(input.bill, "fatura"),
                billDay: BrazilianInput.day(input.billDays, label: "prazo da fatura"),
                pointsSpent: decimal(input.pointsSpent, "pontos utilizados"),
                offeredDiscount: decimal(input.redemptionDiscount, "desconto oferecido"),
                alternativeValuePerThousand: decimal(input.alternativeValue, "valor alternativo do milheiro"),
                monthlyRate: rate)
        }
    }

}

extension InputState {
    func diagnoseFourCases() throws -> FourCaseReport {
        func value(_ raw: String, _ label: String) throws -> Decimal {
            try BrazilianInput.decimal(raw, label: label)
        }
        return try DecisionEngine.fourCases(
            principal: value(cardTotal, "valor da compra"),
            pixPrice: value(directPixPrice ?? "0", "preço Pix"),
            noInterestDays: installmentCount == 0 ? [] : LocalSchedule.days(first: firstDate, count: installmentCount),
            interestTotal: value(interestTotal ?? "0", "total com juros"),
            interestDays: (interestCount ?? 0) == 0 ? [] : LocalSchedule.days(first: firstDate, count: interestCount ?? 0),
            anticipationQuote: value(quote, "oferta de antecipação"),
            anticipationDay: LocalSchedule.day(paymentDate), firstDueDay: LocalSchedule.day(firstDate),
            extraPoints: value(incrementalPoints, "pontos extras"),
            reaisPerThousand: value(reaisPerThousand, "valor de mil pontos"),
            normalPointDay: BrazilianInput.day(benefitDay, label: "prazo dos pontos normais"),
            anticipatedPointDay: BrazilianInput.day(bonusDay, label: "prazo dos pontos antecipados"),
            monthlyRate: DecisionEngine.number(value(monthlyRate, "rendimento")) / 100)
    }
}
