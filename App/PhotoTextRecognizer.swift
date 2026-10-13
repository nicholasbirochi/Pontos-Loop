import Foundation
import Vision
import ImageIO

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
    static func read(_ data: Data) async throws -> String {
        guard data.count <= 20 * 1024 * 1024 else { throw PhotoReadError.tooLarge }
        let text = try await Task.detached(priority: .userInitiated) {
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
            let observations = (request.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            var rows: [[VNRecognizedTextObservation]] = []
            for observation in observations {
                if let last = rows.last, let first = last.first,
                   abs(first.boundingBox.midY - observation.boundingBox.midY) < max(first.boundingBox.height, observation.boundingBox.height) * 0.65 {
                    rows[rows.count - 1].append(observation)
                } else { rows.append([observation]) }
            }
            let lines = rows.map { row in
                row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            }
            let text = String(lines.joined(separator: "\n").prefix(30_000))
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PhotoReadError.noText }
            return text
        }.value
        try Task.checkCancellation()
        return text
    }
}
