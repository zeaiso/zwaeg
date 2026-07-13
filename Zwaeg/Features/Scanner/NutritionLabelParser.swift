import Foundation
import UIKit
import Vision

/// Per-100g values read off a nutrition facts table by the label scanner.
struct NutritionFacts {
    var kcal: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?

    var isUsable: Bool {
        kcal != nil || protein != nil || carbs != nil || fat != nil
    }
}

/// Heuristic parser for OCR lines of European nutrition tables (de/en/fr/it).
/// Values usually appear in the per-100g column first, so the first plausible
/// number after a nutrient word wins; "davon ..." sublines are skipped.
enum NutritionLabelParser {

    // MARK: - OCR

    /// Runs on-device text recognition and returns the lines top to bottom.
    static func recognizeLines(in image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return await withCheckedContinuation { continuation in
            // perform() can throw after the completion handler already ran;
            // both paths execute on the same queue, so a flag suffices to
            // keep the continuation from resuming twice.
            var resumed = false
            func finish(_ lines: [String]) {
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: lines)
            }
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                finish(lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["de-DE", "en-US", "fr-FR", "it-IT"]
            DispatchQueue.global(qos: .userInitiated).async {
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
                do {
                    try handler.perform([request])
                } catch {
                    finish([])
                }
            }
        }
    }

    // MARK: - Parsing

    static func parse(lines: [String]) -> NutritionFacts {
        let normalized = lines.map(normalize)
        return NutritionFacts(
            kcal: kcalValue(in: normalized),
            protein: value(for: ["eiweiss", "protein", "proteine"],
                           excluding: [], in: normalized),
            carbs: value(for: ["kohlenhydrat", "carbohydrate", "glucide", "carboidrat"],
                         excluding: ["zucker", "sugar", "sucre", "zuccher"], in: normalized),
            fat: value(for: ["fett", "fat", "grasses", "grassi", "lipide"],
                       excluding: ["gesattigt", "saturated", "satur", "fettsauren"], in: normalized))
    }

    /// Lowercased, umlauts and accents flattened, decimal comma to point.
    private static func normalize(_ line: String) -> String {
        line.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de"))
            .replacingOccurrences(of: "ß", with: "ss")
            .replacingOccurrences(of: ",", with: ".")
    }

    /// The kcal figure next to the unit, or a plausible number on the energy line.
    private static func kcalValue(in lines: [String]) -> Double? {
        for line in lines {
            if let value = firstMatch(#"(\d+(?:\.\d+)?)\s*kcal"#, in: line), value > 0, value <= 900 {
                return value
            }
        }
        for line in lines where line.contains("energ") || line.contains("brennwert") {
            let candidates = numbers(in: line).filter { $0 > 0 && $0 <= 900 }
            // A kJ figure would be ~4x larger; the smallest plausible number is the kcal one.
            if let value = candidates.min() { return value }
        }
        return nil
    }

    private static func value(for keywords: [String], excluding: [String],
                              in lines: [String]) -> Double? {
        for (index, line) in lines.enumerated() {
            guard keywords.contains(where: line.contains),
                  !excluding.contains(where: line.contains) else { continue }
            // The value is on the same line or, with table columns, on the next one.
            for candidate in [line, lines.indices.contains(index + 1) ? lines[index + 1] : ""] {
                if let value = numbers(in: candidate).first(where: { $0 >= 0 && $0 <= 100 }) {
                    return value
                }
            }
        }
        return nil
    }

    private static func numbers(in line: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: #"\d+(?:\.\d+)?"#) else { return [] }
        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, range: range).compactMap {
            Range($0.range, in: line).flatMap { Double(line[$0]) }
        }
    }

    private static func firstMatch(_ pattern: String, in line: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return Double(line[range])
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
