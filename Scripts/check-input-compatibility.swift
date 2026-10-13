import Foundation

@main
struct InputCompatibilityCheck {
    static func main() throws {
        let initial = InputState()
        for field in Mirror(reflecting: initial).children {
            if let value = field.value as? String { assert(value == "0", "Padrão não zerado: \(field.label ?? "campo")") }
        }
        assert(initial.installmentCount == 0 && initial.remainingCount == 0)
        var legacy = InputState()
        legacy.mode = .purchase
        legacy.directPixPrice = nil
        legacy.installmentCount = 2
        legacy.referencePrice = "1000,00"
        legacy.cardTotal = "1000,00"
        legacy.pixDiscount = "5"
        let data = try JSONEncoder().encode(legacy)
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        assert(!object.keys.contains("directPixPrice"))
        let restored = try JSONDecoder().decode(InputState.self, from: data)
        assert(restored.directPixPrice == nil)
        let restoredComparison = try restored.calculate()
        assert(restoredComparison.options[0].presentCost == 950)
        var direct = restored
        direct.referencePrice = ""
        direct.directPixPrice = "940,00"
        let directComparison = try direct.calculate()
        assert(directComparison.options[0].presentCost == 940)
        let saved = try JSONDecoder().decode(InputState.self, from: JSONEncoder().encode(direct))
        assert(saved.directPixPrice == "940,00")
        direct.directPixPrice = "0"
        do {
            _ = try direct.calculate()
            assertionFailure("Preço Pix não preenchido não pode ser uma compra grátis")
        } catch CalculationError.invalid { }
        direct.directPixPrice = "940,001"
        do {
            _ = try direct.calculate()
            assertionFailure("Pix com mais de dois centavos deveria falhar")
        } catch CalculationError.invalid { }
        print("OK: cenários antigos continuam calculando; preço Pix direto é salvo e validado.")
    }
}
