import Foundation
import Vision
import ImageIO
import CoreText

enum PhotoReadError: LocalizedError {
    case tooLarge, invalidImage, noText
    var errorDescription: String? {
        switch self {
        case .tooLarge: return "Escolha uma imagem de até 20 MB. Um print recortado costuma funcionar melhor."
        case .invalidImage: return "Não consegui abrir essa imagem. Tente uma foto ou um print em outro formato."
        case .noText: return "Não consegui ler os valores. Tente um print mais nítido, com o preço e as parcelas visíveis."
        }
    }
}

enum PhotoTextRecognizer {
    enum Payment: String { case itau, mercado }
    struct Reading {
        let text: String
        var preview: Data?
        var selectedPayment: Payment?
        var advertisedPrice: Decimal?
    }

    static func read(_ data: Data) async throws -> String {
        try await inspect(data).text
    }

    static func inspect(_ data: Data) async throws -> Reading {
        guard data.count <= 20 * 1024 * 1024 else { throw PhotoReadError.tooLarge }
        let reading = try await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 2400
                  ] as CFDictionary) else { throw PhotoReadError.invalidImage }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let supported = try request.supportedRecognitionLanguages()
            request.recognitionLanguages = ["pt-BR", "en-US"].filter { supported.contains($0) }
            request.automaticallyDetectsLanguage = true
            request.customWords = ["Pix", "parcelas", "sem juros"]
            try VNImageRequestHandler(cgImage: image).perform([request])
            let observations = try (request.results ?? []).compactMap { observation -> (text: String, box: CGRect)? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                return (try currencyText(candidate, image: image), observation.boundingBox)
            }
            var assigned = Set<Int>()
            var lines: [(text: String, box: CGRect)] = []
            for (index, observation) in observations.enumerated() where observation.text.range(of: #"^\s*[0-9]{1,2}\s*[x×]"#, options: .regularExpression) != nil {
                var row = [observation]
                assigned.insert(index)
                for (other, total) in observations.enumerated() where other != index && !assigned.contains(other) {
                    if total.text.range(of: #"^R\$\s*[0-9.,]+\s*[>›＞]?$"#, options: .regularExpression) != nil,
                       total.box.minX > observation.box.maxX,
                       abs(total.box.midY - observation.box.midY) < max(total.box.height, observation.box.height) * 1.2 {
                        row.append(total); assigned.insert(other)
                    }
                }
                lines.append((row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " "), observation.box))
            }
            lines += observations.enumerated().filter { !assigned.contains($0.offset) }.map(\.element)
            lines.sort { $0.box.midY > $1.box.midY }
            var rows: [[(text: String, box: CGRect)]] = []
            for observation in lines {
                if let first = rows.last?.first,
                   abs(first.box.midY - observation.box.midY) < max(first.box.height, observation.box.height) * 0.65 {
                    rows[rows.count - 1].append(observation)
                } else { rows.append([observation]) }
            }
            let rendered = rows.map { row in
                row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ")
            }
            let text = String(rendered.joined(separator: "\n").prefix(30_000))
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PhotoReadError.noText }
            let previewImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 900
            ] as CFDictionary)
            let preview = NSMutableData()
            if let previewImage, let destination = CGImageDestinationCreateWithData(preview, "public.jpeg" as CFString, 1, nil) {
                CGImageDestinationAddImage(destination, previewImage, [kCGImageDestinationLossyCompressionQuality: 0.75] as CFDictionary)
                if !CGImageDestinationFinalize(destination) { preview.length = 0 }
            }
            let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            let prices = observations.filter { $0.text.range(of: #"^R\$\s*[0-9.,]+(?:\s|$)"#, options: .regularExpression) != nil }
                .sorted { $0.box.height > $1.box.height }
            var advertised: Decimal?
            if folded.contains("mais vendido"), !folded.contains("escolha as parcelas"), let price = prices.first,
               prices.dropFirst().allSatisfy({ $0.box.height < price.box.height * 0.9 }),
               let range = price.text.range(of: #"[0-9]+(?:[.,][0-9]+)*"#, options: .regularExpression) {
                let raw = String(price.text[range])
                let grouped = raw.contains(",") || raw.range(of: #"^[0-9]+(?:\.[0-9]{3})+$"#, options: .regularExpression) != nil
                let normalized = grouped ? raw.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") : raw
                if normalized.range(of: #"^[0-9]+(?:\.[0-9]{1,2})?$"#, options: .regularExpression) != nil {
                    advertised = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
                }
            }
            return Reading(text: text, preview: preview.length > 0 ? preview as Data : nil,
                           selectedPayment: selectedPayment(observations, image: image), advertisedPrice: advertised)
        }.value
        try Task.checkCancellation()
        return reading
    }

    private static func selectedPayment(_ observations: [(text: String, box: CGRect)], image: CGImage) -> Payment? {
        let labels = observations.filter { $0.text.count < 65 }.map {
            (text: $0.text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR")), box: $0.box)
        }
        guard let itau = labels.first(where: { $0.text.contains("itau") }),
              let mercado = labels.first(where: { $0.text.contains("mercad") && !$0.text.contains("cashback") }),
              abs(itau.box.midY - mercado.box.midY) < max(itau.box.height, mercado.box.height) * 3,
              abs(itau.box.midX - mercado.box.midX) > 0.2 else { return nil }
        func background(_ box: CGRect) -> Int? {
            let rect = CGRect(x: box.minX * Double(image.width), y: (1 - box.maxY) * Double(image.height),
                              width: box.width * Double(image.width), height: box.height * Double(image.height)).integral
            guard let crop = image.cropping(to: rect) else { return nil }
            var pixels = [UInt8](repeating: 0, count: crop.width * crop.height)
            let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
                guard let context = CGContext(data: bytes.baseAddress, width: crop.width, height: crop.height, bitsPerComponent: 8,
                                              bytesPerRow: crop.width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
                context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height)); return true
            }
            guard drawn else { return nil }
            var histogram = [Int](repeating: 0, count: 256)
            for value in pixels { histogram[Int(value)] += 1 }
            guard histogram[230...255].reduce(0, +) > pixels.count / 2 else { return nil }
            return (230...255).max { histogram[$0] < histogram[$1] }
        }
        guard let left = background(itau.box), let right = background(mercado.box), abs(left - right) >= 7,
              max(left, right) >= 252 else { return nil }
        // shortcut: reconhece abas claras com contraste legível; outros layouts pedem uma confirmação por grupo.
        return left > right ? .itau : .mercado
    }

    private static func currencyText(_ candidate: VNRecognizedText, image: CGImage) throws -> String {
        var text = candidate.string
        let regex = try NSRegularExpression(pattern: #"R\$\s*([0-9][0-9.,°\"'’]*)"#)
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let range = Range(match.range(at: 1), in: text),
                  !text[range].contains(","),
                  let box = try candidate.boundingBox(for: range)?.boundingBox else { continue }
            let rect = CGRect(x: box.minX * Double(image.width), y: (1 - box.maxY) * Double(image.height),
                              width: box.width * Double(image.width), height: box.height * Double(image.height)).insetBy(dx: -2, dy: -2).integral
            guard let crop = image.cropping(to: rect) else { continue }
            let w = crop.width, h = crop.height
            var pixels = [UInt8](repeating: 255, count: w * h)
            let drawn = pixels.withUnsafeMutableBytes { bytes -> Bool in
                guard let context = CGContext(data: bytes.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                              space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
                context.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
                return true
            }
            guard drawn else { throw PhotoReadError.invalidImage }
            guard let darkest = pixels.min(), let lightest = pixels.max(), Int(lightest) - Int(darkest) > 40 else { continue }
            let threshold = (Int(darkest) + Int(lightest)) / 2
            var glyphs: [CGRect] = []
            for x in 0..<w {
                let ys = (0..<h).filter { Int(pixels[$0 * w + x]) < threshold }
                guard let first = ys.first, let last = ys.last else { continue }
                let column = CGRect(x: x, y: first, width: 1, height: last - first + 1)
                if let previous = glyphs.last, previous.maxX == Double(x) { glyphs[glyphs.count - 1] = previous.union(column) }
                else { glyphs.append(column) }
            }
            let tallest = glyphs.map(\.height).max() ?? 0
            glyphs.removeAll { $0.height < tallest * 0.3 || $0.width < 2 }
            guard glyphs.count >= 3 else { continue }
            let cents = glyphs.suffix(2)
            guard cents.allSatisfy({ $0.height < tallest * 0.82 }),
                  glyphs.dropLast(2).contains(where: { $0.height > tallest * 0.9 }) else { continue }
            let cut = Int(cents.first!.minX) - 1
            guard cut > 0,
                  let wholeImage = crop.cropping(to: CGRect(x: 0, y: 0, width: cut, height: h)),
                  let centsImage = crop.cropping(to: CGRect(x: cut, y: 0, width: w - cut, height: h)) else { continue }
            let whole = try enlargedDigits(wholeImage).replacingOccurrences(of: #"R\s*\$\s*"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            let fraction = try enlargedDigits(centsImage).trimmingCharacters(in: .whitespacesAndNewlines)
            let validWhole = whole.range(of: #"^[0-9]+(?:\.[0-9]{3})*$"#, options: .regularExpression) != nil
            let validCents = fraction.range(of: #"^[0-9]{2}$"#, options: .regularExpression) != nil
            // Só corrigir com os dois recortes legíveis; valor incerto precisa de revisão.
            let replacement = validWhole && validCents ? whole + "," + fraction : "[valor ilegível]"
            text.replaceSubrange(range, with: replacement)
        }
        return text
    }

    private static func enlargedDigits(_ image: CGImage) throws -> String {
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 255, count: w * h)
        let grayImage = pixels.withUnsafeMutableBytes { bytes -> CGImage? in
            guard let context = CGContext(data: bytes.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return context.makeImage()
        }
        guard let grayImage else { throw PhotoReadError.invalidImage }
        let threshold = (Int(pixels.min() ?? 0) + Int(pixels.max() ?? 255)) / 2
        var ink = CGRect.null
        for y in 0..<h { for x in 0..<w where Int(pixels[y * w + x]) < threshold {
            ink = ink.union(CGRect(x: x, y: y, width: 1, height: 1))
        } }
        guard !ink.isNull, let image = grayImage.cropping(to: ink.insetBy(dx: -2, dy: -2).intersection(CGRect(x: 0, y: 0, width: w, height: h))) else { return "" }
        let scale = min(4, max(1, 1600 / max(image.width, image.height)))
        let height = image.height * scale, prefix = Int(Double(height) * 1.3)
        guard let context = CGContext(data: nil, width: image.width * scale + prefix, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw PhotoReadError.invalidImage }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: image.width * scale + prefix, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: prefix, y: 0, width: image.width * scale, height: height))
        // Dois dígitos isolados (06/90, 89/68) admitem rotação; o prefixo fixa a orientação.
        context.textPosition = CGPoint(x: 2, y: Double(height) * 0.1)
        let label = NSAttributedString(string: "R$", attributes: [.init(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, Double(height) * 0.9, nil)])
        CTLineDraw(CTLineCreateWithAttributedString(label), context)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate; request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        guard let enlarged = context.makeImage() else { throw PhotoReadError.invalidImage }
        try VNImageRequestHandler(cgImage: enlarged).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            .replacingOccurrences(of: #"R\s*\$\s*"#, with: "", options: .regularExpression)
    }
}
