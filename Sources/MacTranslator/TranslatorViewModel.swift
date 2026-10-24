import AppKit
import Combine
import Foundation

@MainActor
final class TranslatorViewModel: ObservableObject {
    enum Tab: String, CaseIterable {
        case translate = "翻譯"
        case history = "歷史紀錄"
        case shortcuts = "快捷鍵與設定"
    }

    @Published var activeTab: Tab = .translate
    @Published var sourceText: String = ""
    @Published var sourceLanguage: Language = .auto
    @Published var targetLanguage: Language = .zhTW
    @Published var smartBidirectional: Bool = true
    @Published var autoCopyResult: Bool = false
    @Published var isPinned: Bool = false

    @Published var currentResult: TranslationResult?
    @Published var isLoading: Bool = false
    @Published var isOCRRunning: Bool = false
    @Published var errorMessage: String?
    @Published var copiedFeedback: Bool = false
    @Published var statusBanner: String?

    @Published var historySearchQuery: String = ""
    @Published var showFavoritesOnly: Bool = false

    let historyStore = HistoryStore()
    let speechService = SpeechService()

    var onRequestShowWindow: (() -> Void)?
    var onRequestHideWindowForCapture: (() async -> Void)?
    var onPinStateChanged: ((Bool) -> Void)?

    private var debounceTask: Task<Void, Never>?
    private var translateTask: Task<Void, Never>?
    private var activeRequestID: UUID?

    var filteredHistory: [HistoryItem] {
        historyStore.items.filter { item in
            if showFavoritesOnly && !item.isFavorite {
                return false
            }
            let q = historySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if q.isEmpty { return true }
            return item.sourceText.localizedCaseInsensitiveContains(q) ||
                   item.translatedText.localizedCaseInsensitiveContains(q)
        }
    }

    var effectiveTargetLanguagePreview: Language {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return targetLanguage }
        return TranslationService.shared.resolveTargetLanguage(
            for: trimmed,
            source: sourceLanguage,
            selectedTarget: targetLanguage,
            smartBidirectional: smartBidirectional
        )
    }

    func onSourceTextChanged(_ newValue: String) {
        debounceTask?.cancel()
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            translateTask?.cancel()
            activeRequestID = nil
            currentResult = nil
            errorMessage = nil
            isLoading = false
            return
        }

        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000) // 0.45 秒防抖自動翻譯
            guard !Task.isCancelled else { return }
            await executeTranslation(saveToHistory: true)
        }
    }

    func performTranslation(saveToHistory: Bool = true) async {
        debounceTask?.cancel()
        await executeTranslation(saveToHistory: saveToHistory)
    }

    private func executeTranslation(saveToHistory: Bool) async {
        translateTask?.cancel()

        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            activeRequestID = nil
            currentResult = nil
            errorMessage = nil
            isLoading = false
            return
        }

        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        errorMessage = nil

        defer {
            if activeRequestID == requestID {
                isLoading = false
            }
        }

        let src = sourceLanguage
        let tgt = targetLanguage
        let bidirectional = smartBidirectional

        let task = Task { () -> Result<TranslationResult, Error> in
            do {
                let res = try await TranslationService.shared.translate(
                    text: text,
                    from: src,
                    to: tgt,
                    smartBidirectional: bidirectional
                )
                return .success(res)
            } catch {
                return .failure(error)
            }
        }
        translateTask = Task { _ = await task.value }

        let outcome = await task.value
        guard activeRequestID == requestID, !Task.isCancelled else { return }

        isLoading = false
        switch outcome {
        case .success(let result):
            self.currentResult = result
            self.errorMessage = nil
            if saveToHistory {
                historyStore.add(
                    sourceText: result.sourceText,
                    translatedText: result.translatedText,
                    sourceLangCode: result.detectedSourceLanguage,
                    targetLangCode: result.targetLanguage.rawValue
                )
            }
            if autoCopyResult {
                copyTranslatedText(showBanner: true)
            }
        case .failure(let error):
            self.errorMessage = error.localizedDescription
        }
    }

    func swapLanguages() {
        if sourceLanguage == .auto {
            if let detected = currentResult.flatMap({ Language.fromGoogleCode($0.detectedSourceLanguage) }) {
                let oldTarget = effectiveTargetLanguagePreview
                sourceLanguage = oldTarget
                targetLanguage = detected
            } else {
                sourceLanguage = targetLanguage
                targetLanguage = (targetLanguage == .en) ? .zhTW : .en
            }
        } else {
            let temp = sourceLanguage
            sourceLanguage = targetLanguage
            targetLanguage = temp
        }

        if let translated = currentResult?.translatedText, !translated.isEmpty {
            sourceText = translated
        }
        Task {
            await performTranslation(saveToHistory: true)
        }
    }

    func clearText() {
        debounceTask?.cancel()
        translateTask?.cancel()
        speechService.stop()
        sourceText = ""
        currentResult = nil
        errorMessage = nil
        isLoading = false
    }

    func copyTranslatedText(showBanner: Bool = false) {
        guard let text = currentResult?.translatedText, !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedFeedback = true
        if showBanner {
            showTemporaryBanner("已自動複製翻譯結果")
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copiedFeedback = false
        }
    }

    func translateClipboard() {
        activeTab = .translate
        onRequestShowWindow?()

        let pb = NSPasteboard.general
        if let str = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !str.isEmpty {
            sourceText = str
            showTemporaryBanner("已載入剪貼簿文字")
            Task {
                await performTranslation(saveToHistory: true)
            }
        } else if NSImage(pasteboard: pb) != nil {
            // 剪貼簿內是圖片時，自動進行圖片 OCR 翻譯！
            Task {
                isOCRRunning = true
                errorMessage = nil
                showTemporaryBanner("正在辨識剪貼簿圖片文字...")
                do {
                    let recognized = try await OCRService.shared.recognizeFromClipboardImage()
                    isOCRRunning = false
                    sourceText = recognized
                    await performTranslation(saveToHistory: true)
                } catch {
                    isOCRRunning = false
                    errorMessage = error.localizedDescription
                }
            }
        } else {
            errorMessage = "剪貼簿中沒有可翻譯的文字或圖片"
        }
    }

    func captureScreenOCR() {
        guard !isOCRRunning else { return }
        Task {
            isOCRRunning = true
            errorMessage = nil
            await onRequestHideWindowForCapture?()

            do {
                let text = try await OCRService.shared.captureScreenAndRecognize()
                isOCRRunning = false
                activeTab = .translate
                onRequestShowWindow?()
                sourceText = text
                showTemporaryBanner("OCR 截圖辨識完成")
                await performTranslation(saveToHistory: true)
            } catch OCRError.cancelled {
                isOCRRunning = false
                onRequestShowWindow?()
            } catch {
                isOCRRunning = false
                activeTab = .translate
                onRequestShowWindow?()
                errorMessage = error.localizedDescription
            }
        }
    }

    func speakSource() {
        let locale: String
        if sourceLanguage != .auto {
            locale = sourceLanguage.speechLocale
        } else if let detected = currentResult.flatMap({ Language.fromGoogleCode($0.detectedSourceLanguage) }) {
            locale = detected.speechLocale
        } else if TranslationService.shared.isPredominantlyChinese(sourceText) {
            locale = "zh-TW"
        } else {
            locale = "en-US"
        }
        speechService.toggleSpeak(text: sourceText, localeIdentifier: locale, target: .source)
    }

    func speakTranslated() {
        guard let result = currentResult else { return }
        speechService.toggleSpeak(
            text: result.translatedText,
            localeIdentifier: result.targetLanguage.speechLocale,
            target: .translated
        )
    }

    func restoreHistoryItem(_ item: HistoryItem) {
        activeTab = .translate
        if let tgt = Language.fromGoogleCode(item.targetLangCode) {
            targetLanguage = tgt
        }
        sourceText = item.sourceText
        Task {
            await performTranslation(saveToHistory: false)
        }
    }

    func togglePin() {
        isPinned.toggle()
        onPinStateChanged?(isPinned)
    }

    private func showTemporaryBanner(_ text: String) {
        statusBanner = text
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if statusBanner == text {
                statusBanner = nil
            }
        }
    }
}
