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
        print("OK: quatro imagens lidas localmente, Pix separado e totais finais com centavos preservados.")
    }
}
