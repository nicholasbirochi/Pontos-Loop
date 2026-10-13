import Foundation
import UniformTypeIdentifiers
import CoreGraphics
import CoreText
import AVFoundation

@main
struct ChatAttachmentCheck {
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("loop-attachment-check-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let offer = "Pix R$ 950,00\n10x de R$ 100,00"
        let text = try await ChatAttachmentReader.read(data: Data(offer.utf8), type: .plainText, name: "oferta.txt")
        assert(text.text == offer && text.kind == .document)
        let long = try await ChatAttachmentReader.read(data: Data(String(repeating: "a", count: 30_001).utf8), type: .plainText, name: "longo.txt")
        assert(long.text.count == 30_000 && !long.note.isEmpty)
        let pdfURL = directory.appendingPathComponent("oferta.pdf")
        var box = CGRect(x: 0, y: 0, width: 600, height: 800)
        let context = CGContext(pdfURL as CFURL, mediaBox: &box, nil)!
        context.beginPDFPage(nil)
        context.textPosition = CGPoint(x: 50, y: 700)
        CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: "Pix R$ 950,00", attributes: [.font: CTFontCreateWithName("Helvetica" as CFString, 24, nil)])), context)
        context.endPDFPage(); context.closePDF()
        let pdf = try await ChatAttachmentReader.read(data: Data(contentsOf: pdfURL), type: .pdf, name: "oferta.pdf")
        assert(pdf.text.contains("950,00"))
        for (data, type) in [(Data(), UTType.plainText), (Data([0, 1]), UTType.pdf), (Data([0]), UTType.zip), (Data(count: 21 * 1024 * 1024), UTType.plainText)] {
            do {
                _ = try await ChatAttachmentReader.read(data: data, type: type, name: "inválido")
                assertionFailure("Arquivo inválido deveria ser rejeitado")
            } catch is ChatAttachmentError { }
        }
        let voice = VoiceInput()
        for frames in [0, 61 * 8_000] {
            let url = directory.appendingPathComponent("audio-\(frames).wav")
            do {
                let format = AVAudioFormat(standardFormatWithSampleRate: 8_000, channels: 1)!
                let file = try AVAudioFile(forWriting: url, settings: format.settings)
                if frames > 0 {
                    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
                    buffer.frameLength = AVAudioFrameCount(frames)
                    try file.write(from: buffer)
                }
            }
            do {
                _ = try await voice.transcribeFile(at: url)
                assertionFailure("Áudio vazio ou longo deveria ser rejeitado")
            } catch { assert(error.localizedDescription.contains(frames == 0 ? "vazio" : "60 segundos")) }
        }
        voice.cancel()
        assert(!voice.isRecording && !voice.isTranscribing && voice.seconds == 0)
        let playback = ChatAudioPlayer()
        playback.toggle(ChatAttachment(name: "cancelar.wav", kind: .audio, text: "", audio: Data([1]), duration: 1))
        playback.stop()
        try await Task.sleep(for: .milliseconds(100))
        assert(playback.playingID == nil && playback.preparingID == nil && playback.errorMessage == nil)
        if let path = CommandLine.arguments.dropFirst().first {
            let url = URL(fileURLWithPath: path)
            let file = try AVAudioFile(forReading: url)
            assert(file.length > 0)
            playback.toggle(ChatAttachment(name: url.lastPathComponent, kind: .audio, text: "", audio: try Data(contentsOf: url), duration: Double(file.length) / file.fileFormat.sampleRate))
            for _ in 0..<12 { try await Task.sleep(for: .seconds(1)) }
            assert(playback.preparingID == nil, "A reprodução não pode prender o chat esperando a saída de áudio")
            print(playback.errorMessage ?? "Reprodução terminou ou iniciou sem bloquear o executor da interface.")
            playback.stop()
        }
        print("OK: TXT/PDF, limites, áudio vazio/longo e cancelamento da reprodução verificados sem acessar microfone.")
    }
}
