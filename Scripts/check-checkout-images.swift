import AppKit
import Foundation

@main struct CheckoutImageCheck {
    static func main() async throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "/private/tmp/pontos-loop-checkout-demo")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let texts = [
            ["Oferta ilustrativa", "R$ 900,00", "no Pix"],
            ["Oferta ilustrativa Inter", "1x R$ 1.000,00", "2x R$ 510,00 R$ 1.020,00", "3x R$ 350,00 R$ 1.050,01"],
            ["Oferta ilustrativa Mercado", "1x R$ 1.000,00", "6x R$ 180,00 R$ 1.080,00", "Até R$ 10,00 de cashback"],
            ["Oferta ilustrativa Itau", "1x R$ 1.000,00", "12x R$ 100,00 R$ 1.200,00"]
        ]
        for (index, lines) in texts.enumerated() {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1200, pixelsHigh: 700, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
            NSColor.white.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1200, height: 700)).fill()
            for (row, line) in lines.enumerated() {
                (line as NSString).draw(at: NSPoint(x: 70, y: 560 - row * 130), withAttributes: [.font: NSFont.systemFont(ofSize: 45), .foregroundColor: NSColor.black])
            }
            NSGraphicsContext.restoreGraphicsState()
            let data = bitmap.representation(using: .png, properties: [:])!
            try data.write(to: directory.appendingPathComponent("oferta-\(index + 1).png"))
            let text = try await PhotoTextRecognizer.read(data)
            let read = ExtractedOffers.read(text)
            if index == 0 { assert(read.pixPrices == [900], text) }
            if index == 1 { assert(read.installments.count == 3 && read.installments.last?.total == Decimal(string: "1050.01"), text) }
            if index == 2 { assert(read.installments.count == 2 && read.installments.last?.total == 1080, text) }
            if index == 3 { assert(read.installments.count == 2 && read.installments.last?.count == 12, text) }
        }
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1200, pixelsHigh: 700, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.white.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1200, height: 700)).fill()
        func draw(_ text: String, _ x: Int, _ y: Int, _ size: CGFloat, _ color: NSColor = .black) {
            (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: color])
        }
        for (index, row) in [("1x", "624", "90", "", ""), ("2x", "326", "06", "652", "11"), ("3×", "236", "89", "710", "68")].enumerated() {
            let y = 540 - index * 170
            let prefix = row.0 + " R$ "
            let wholeX = 70 + Int((prefix as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 46)]).width.rounded(.up))
            let centsX = wholeX + Int((row.1 as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 46)]).width.rounded(.up)) + 2
            draw(prefix, 70, y, 46); draw(row.1, wholeX, y, 46); draw(row.2, centsX, y + 21, 26)
            if !row.3.isEmpty {
                let total = "R$ " + row.3
                let totalCentsX = 750 + Int((total as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 34)]).width.rounded(.up)) + 2
                draw(total, 750, y - 15, 34, .gray); draw(row.4, totalCentsX, y + 1, 20, .gray)
                draw("Só R$ 10 a mais por parcela", 70, y - 42, 21, .gray)
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        let data = bitmap.representation(using: .png, properties: [:])!
        try data.write(to: directory.appendingPathComponent("centavos-elevados.png"))
        let text = try await PhotoTextRecognizer.read(data)
        let read = ExtractedOffers.read(text)
        assert(read.installments.map(\.total) == [Decimal(string: "624.90")!, Decimal(string: "652.11")!, Decimal(string: "710.68")!], text)
        print("OK: quatro imagens regulares e centavos elevados (90, 06, 89) lidos; totais deslocados e arredondamento preservados.")
    }
}
