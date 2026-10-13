import AppKit
import Foundation

@main
struct PhotoImportCheck {
    static func main() async throws {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1200, pixelsHigh: 700,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1200, height: 700)).fill()
        let lines = ["Oferta de compra", "Pix R$ 950,00", "10x de R$ 100,00", "Total no cartão R$ 1.000,00"]
        for (index, line) in lines.enumerated() {
            (line as NSString).draw(at: NSPoint(x: 80, y: 550 - index * 130), withAttributes: [
                .font: NSFont.systemFont(ofSize: 54, weight: .medium), .foregroundColor: NSColor.black
            ])
        }
        NSGraphicsContext.restoreGraphicsState()
        let data = bitmap.representation(using: .png, properties: [:])!
        if CommandLine.arguments.count > 1 {
            try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        }
        let text = try await PhotoTextRecognizer.read(data)
        assert(text.contains("950,00"), "Preço Pix não reconhecido: \(text)")
        assert(text.lowercased().contains("10x"), "Quantidade não reconhecida: \(text)")
        assert(text.contains("100,00"), "Valor da parcela não reconhecido: \(text)")
        do {
            _ = try await PhotoTextRecognizer.read(Data([0, 1, 2]))
            assertionFailure("Imagem inválida deveria ser recusada")
        } catch PhotoReadError.invalidImage { }
        do {
            _ = try await PhotoTextRecognizer.read(Data(count: 21 * 1024 * 1024))
            assertionFailure("Imagem grande deveria ser recusada")
        } catch PhotoReadError.tooLarge { }
        print("OK: OCR local leu Pix, quantidade e valor da parcela; recusou dados inválidos e imagem acima de 20 MB.")
    }
}
