import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let manager = FileManager.default
try manager.createDirectory(at: root, withIntermediateDirectories: true)
func icon(size: Int, filename: String) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    NSColor(srgbRed: 0.031, green: 0.035, blue: 0.043, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
    let points: [NSPoint] = [
        NSPoint(x: 0.00000, y: 120.83000),
        NSPoint(x: 53.29800, y: 120.83000),
        NSPoint(x: 53.58150, y: 119.35420),
        NSPoint(x: 1.02150, y: 108.45620),
        NSPoint(x: 2.04290, y: 102.61020),
        NSPoint(x: 54.60290, y: 113.96220),
        NSPoint(x: 55.05700, y: 111.91860),
        NSPoint(x: 5.39200, y: 90.34960),
        NSPoint(x: 7.54880, y: 84.38990),
        NSPoint(x: 57.32780, y: 105.33390),
        NSPoint(x: 58.34930, y: 103.85840),
        NSPoint(x: 14.24730, y: 71.10740),
        NSPoint(x: 18.78790, y: 63.95570),
        NSPoint(x: 62.60690, y: 96.70570),
        NSPoint(x: 63.91220, y: 94.94630),
        NSPoint(x: 29.40220, y: 51.12730),
        NSPoint(x: 37.85960, y: 44.25920),
        NSPoint(x: 72.08560, y: 86.03520),
        NSPoint(x: 73.56150, y: 84.72980),
        NSPoint(x: 53.63850, y: 34.04280),
        NSPoint(x: 65.72850, y: 28.93440),
        NSPoint(x: 84.51650, y: 78.59940),
        NSPoint(x: 85.99230, y: 78.14538),
        NSPoint(x: 85.99230, y: 23.08838),
        NSPoint(x: 105.29030, y: 23.08838),
        NSPoint(x: 105.29030, y: 125.02838),
        NSPoint(x: 0.00030, y: 125.02838)
    ]
    let symbol = NSBezierPath()
    for (index, point) in points.enumerated() {
        let positioned = NSPoint(x: 206.7 + point.x * 5.8, y: 1024 - (70 + point.y * 5.8))
        if index == 0 { symbol.move(to: positioned) } else { symbol.line(to: positioned) }
    }
    symbol.close()
    NSColor(srgbRed: 0.647, green: 0.659, blue: 0.682, alpha: 1).setFill()
    symbol.fill()
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(filename))
}
try icon(size: 1024, filename: "Icon-1024.png")
var images: [[String: String]] = [["filename": "Icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"]]
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "Icon-mac-\(size)@\(scale)x.png"
        try icon(size: size * scale, filename: name)
        images.append(["filename": name, "idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x"])
    }
}
let json: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    .write(to: root.appendingPathComponent("Contents.json"))
