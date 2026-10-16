import Foundation

public struct InstallmentOffer: Equatable, Identifiable {
    public let count: Int
    public let amount: Decimal
    public let hasInterest: Bool?
    public let quotedTotal: Decimal?
    public init(count: Int, amount: Decimal, hasInterest: Bool? = nil, quotedTotal: Decimal? = nil) {
        self.count = count; self.amount = amount; self.hasInterest = hasInterest; self.quotedTotal = quotedTotal
    }
    public var total: Decimal { quotedTotal ?? amount * Decimal(count) }
    public var id: String { "\(count)-\(amount)-\(total)-\(hasInterest.map(String.init) ?? "unknown")" }
}

/// Lê somente ofertas explícitas. Valores ambíguos ficam para revisão humana.
public struct ExtractedOffers {
    public let installments: [InstallmentOffer]
    public let pixPrices: [Decimal]

    public static func read(_ text: String) -> ExtractedOffers {
        var text = String(text.prefix(30_000))
        text = text.replacingOccurrences(of: "×", with: "x")
        // Centavos sobrescritos podem chegar colados ao grupo de milhar ou separados por espaço.
        text = text.replacingOccurrences(of: #"(R\$\s*[0-9]{1,3}(?:\.[0-9]{3})+)([0-9]{2})(?![0-9.,])"#, with: "$1,$2", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(R\$\s*[0-9]+(?:\.[0-9]{3})*)[ \t]+([0-9]{2})(?![0-9.,xX%])"#, with: "$1,$2", options: .regularExpression)
        let amount = #"(?:[0-9]+(?:\.[0-9]{3})*(?:,[0-9]{2})?|[0-9]+\.[0-9]{2})"#
        let installmentsPattern = #"(?i)\b([0-9]{1,3})\s*(?:x|parcelas?)\s*(?:de|por)?\s*(?:R\$\s*)?("# + amount + #")(?![0-9.,])"#
        let regex = try! NSRegularExpression(pattern: installmentsPattern)
        let source = text as NSString
        var installments: [InstallmentOffer] = []
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            guard let count = Int(source.substring(with: match.range(at: 1))), (1...36).contains(count),
                  let value = decimal(source.substring(with: match.range(at: 2))), value > 0 else { continue }
            let end = min(source.length, NSMaxRange(match.range) + 70)
            let snippet = source.substring(with: NSRange(location: match.range.location, length: end - match.range.location)).components(separatedBy: .newlines).first ?? ""
            let folded = snippet.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            let without = folded.contains("sem juros")
            let withFee = folded.contains("com juros")
            let interest: Bool? = without == withFee ? nil : withFee
            var pricePart = snippet
            if let cutoff = pricePart.range(of: #"(?i)\b(?:at[eé]|cashback|receba)\b"#, options: .regularExpression) {
                pricePart = String(pricePart[..<cutoff.lowerBound])
            }
            let totals = try! NSRegularExpression(pattern: #"(?i)R\$\s*("# + amount + #")(?![0-9.,])"#).matches(in: pricePart, range: NSRange(location: 0, length: (pricePart as NSString).length))
            var quoted: Decimal?
            if totals.count == 2, let candidate = decimal((pricePart as NSString).substring(with: totals[1].range(at: 1))) {
                let tolerance = Decimal(count) / 100
                let regularDifference = candidate - value * Decimal(count)
                let joinedCentsDifference = candidate - value / 100 * Decimal(count)
                let raw = source.substring(with: match.range(at: 2))
                if regularDifference >= -tolerance && regularDifference <= tolerance ||
                    (!raw.contains(",") && !raw.contains(".") && joinedCentsDifference >= -tolerance && joinedCentsDifference <= tolerance) {
                    quoted = candidate
                } else {
                    let tail = (snippet as NSString).substring(from: NSMaxRange(totals[1].range))
                    // Total conflitante não pode virar um custo calculado a partir de OCR incorreto.
                    guard tail.range(of: #"(?i)^\s*(?:de\s+)?cashback"#, options: .regularExpression) != nil else { continue }
                }
            }
            let offer = InstallmentOffer(count: count, amount: quoted.map { DecisionEngine.cents($0 / Decimal(count)) } ?? value, hasInterest: interest, quotedTotal: quoted)
            if !installments.contains(offer) { installments.append(offer) }
        }
        let currency = try! NSRegularExpression(pattern: #"(?i)R\$\s*("# + amount + #")(?![0-9.,])|([0-9]+(?:\.[0-9]{3})*,[0-9]{2})(?![0-9.,])"#)
        var prices: [Decimal] = []
        let lines = text.components(separatedBy: .newlines)
        for (index, original) in lines.enumerated() {
            var line = original
            if original.lowercased().contains("pix"), !original.contains("R$"), index > 0,
               lines[index - 1].contains("R$"), !lines[index - 1].contains("%") {
                line = lines[index - 1] + " " + original
            }
            let normalized = line.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            let words = normalized.components(separatedBy: CharacterSet.alphanumerics.inverted)
            guard (words.contains("pix") || normalized.contains("a vista")), !line.contains("%"), line.range(of: #"-\s*(?:R\$)?\s*[0-9]"#, options: .regularExpression) == nil,
                  !normalized.contains("cashback"), !normalized.contains("economize"), !normalized.contains("desconto") else { continue }
            let matches = currency.matches(in: line, range: NSRange(location: 0, length: (line as NSString).length))
            guard matches.count == 1 else { continue }
            let match = matches[0]
            let range = match.range(at: 1).location == NSNotFound ? match.range(at: 2) : match.range(at: 1)
            if let value = decimal((line as NSString).substring(with: range)), value >= 0, !prices.contains(value) {
                prices.append(value)
            }
        }
        return ExtractedOffers(installments: installments, pixPrices: prices)
    }

    private static func decimal(_ text: String) -> Decimal? {
        let value = text.contains(",") ? text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") : text
        // Um ponto seguido de três dígitos é separador de milhar.
        let normalized = !text.contains(",") && text.range(of: #"^[0-9]+(?:\.[0-9]{3})+$"#, options: .regularExpression) != nil
            ? text.replacingOccurrences(of: ".", with: "") : value
        guard let result = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), !result.isNaN else { return nil }
        return result
    }
}
