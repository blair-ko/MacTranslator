import AppKit
import Foundation
import Vision

enum OCRError: LocalizedError {
    case cancelled
    case imageLoadFailed
    case noTextFound
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        case .imageLoadFailed:
            return "無法載入截圖影像"
        case .noTextFound:
            return "截圖中未偵測到任何文字"
        case .recognitionFailed(let msg):
            return "OCR 辨識失敗：\(msg)"
        }
    }
}

final class OCRService: Sendable {
    static let shared = OCRService()

    /// 呼叫 macOS 原生互動式區域截圖並進行 Vision OCR 文字辨識
    func captureScreenAndRecognize() async throws -> String {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mactranslator_ocr_\(UUID().uuidString).png")

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        let captured = await runInteractiveScreenCapture(to: tempURL.path)
        guard captured, FileManager.default.fileExists(atPath: tempURL.path) else {
            throw OCRError.cancelled
        }

        guard let nsImage = NSImage(contentsOf: tempURL),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.imageLoadFailed
        }

        return try await recognizeText(from: cgImage)
    }

    /// 從剪貼簿圖片進行 OCR 辨識
    func recognizeFromClipboardImage() async throws -> String {
        guard let image = NSImage(pasteboard: NSPasteboard.general),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.imageLoadFailed
        }
        return try await recognizeText(from: cgImage)
    }

    private func runInteractiveScreenCapture(to filePath: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            // -i: 互動式選取範圍, -x: 靜音不播放快門聲
            process.arguments = ["-i", "-x", filePath]

            process.terminationHandler = { proc in
                continuation.resume(returning: proc.terminationStatus == 0)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    func recognizeText(from cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                let lines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let fullText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if fullText.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: fullText)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            if #available(macOS 13.0, *) {
                request.automaticallyDetectsLanguage = true
            }
            request.recognitionLanguages = ["zh-Hant", "zh-Hans", "en-US", "ja-JP", "ko-KR"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
            }
        }
    }
}
