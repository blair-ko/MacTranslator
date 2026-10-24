import Foundation

enum TranslationError: LocalizedError {
    case emptyInput
    case invalidURL
    case networkError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "請輸入要翻譯的文字"
        case .invalidURL:
            return "無法建立翻譯請求網址"
        case .networkError(let msg):
            return "網路連線錯誤：\(msg)"
        case .parseError:
            return "無法解析翻譯結果"
        }
    }
}

final class TranslationService: Sendable {
    static let shared = TranslationService()

    /// 判斷文字是否主要為中文（包含漢字且非日文假名為主）
    func isPredominantlyChinese(_ text: String) -> Bool {
        var hanCount = 0
        var kanaCount = 0
        var hangulCount = 0
        var latinCount = 0

        for scalar in text.unicodeScalars {
            let v = scalar.value
            if (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) {
                hanCount += 1
            } else if (0x3040...0x309F).contains(v) || (0x30A0...0x30FF).contains(v) {
                kanaCount += 1
            } else if (0xAC00...0xD7AF).contains(v) {
                hangulCount += 1
            } else if (0x0041...0x005A).contains(v) || (0x0061...0x007A).contains(v) {
                latinCount += 1
            }
        }

        // 若有日文假名或韓文諺文則不視為純中文
        if kanaCount > 0 || hangulCount > 0 {
            return false
        }
        if hanCount == 0 {
            return false
        }
        // 只要中文字數大於等於 1 且佔比明顯，即視為中文
        return hanCount * 3 >= latinCount
    }

    /// 智慧決定目標語言（支援中 <-> 英雙向自動互翻）
    func resolveTargetLanguage(
        for text: String,
        source: Language,
        selectedTarget: Language,
        smartBidirectional: Bool
    ) -> Language {
        guard smartBidirectional && source == .auto else {
            return selectedTarget == .auto ? .zhTW : selectedTarget
        }
        if isPredominantlyChinese(text) {
            // 如果輸入是中文，且目前目標語言設為中文，自動轉譯為英文
            if selectedTarget == .zhTW || selectedTarget == .zhCN {
                return .en
            }
            return selectedTarget
        } else {
            // 如果輸入不是中文（例如英文、日文等），自動轉譯為繁體中文（除非使用者明確選了其他非英目標語言）
            if selectedTarget == .en {
                return .zhTW
            }
            return selectedTarget
        }
    }

    func translate(
        text: String,
        from source: Language,
        to target: Language,
        smartBidirectional: Bool = true
    ) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranslationError.emptyInput
        }

        let resolvedTarget = resolveTargetLanguage(
            for: trimmed,
            source: source,
            selectedTarget: target,
            smartBidirectional: smartBidirectional
        )

        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")
        components?.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: source.rawValue),
            URLQueryItem(name: "tl", value: resolvedTarget.rawValue),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "dt", value: "bd"),
            URLQueryItem(name: "dt", value: "rm"),
            URLQueryItem(name: "dj", value: "1"),
            URLQueryItem(name: "q", value: trimmed)
        ]

        guard let url = components?.url else {
            throw TranslationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TranslationError.networkError(error.localizedDescription)
        }

        if let httpResp = response as? HTTPURLResponse, !(200...299).contains(httpResp.statusCode) {
            throw TranslationError.networkError("HTTP \(httpResp.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranslationError.parseError
        }

        var translatedFragments: [String] = []
        var phoneticFragments: [String] = []

        if let sentences = json["sentences"] as? [[String: Any]] {
            for sentence in sentences {
                if let trans = sentence["trans"] as? String {
                    translatedFragments.append(trans)
                }
                if let srcTranslit = sentence["src_translit"] as? String, !srcTranslit.isEmpty {
                    phoneticFragments.append(srcTranslit)
                } else if let translit = sentence["translit"] as? String, !translit.isEmpty {
                    phoneticFragments.append(translit)
                }
            }
        }

        let finalTranslation = translatedFragments.joined()
        guard !finalTranslation.isEmpty else {
            throw TranslationError.parseError
        }

        var detectedSrc = (json["src"] as? String) ?? source.rawValue
        if let ldResult = json["ld_result"] as? [String: Any],
           let srclangs = ldResult["srclangs"] as? [String],
           let firstLang = srclangs.first, !firstLang.isEmpty {
            detectedSrc = firstLang
        }
        if isPredominantlyChinese(trimmed) && !detectedSrc.lowercased().hasPrefix("zh") {
            detectedSrc = "zh-TW"
        }

        var dictEntries: [DictionaryEntry] = []
        if let dictArray = json["dict"] as? [[String: Any]] {
            for item in dictArray {
                let pos = (item["pos"] as? String) ?? "詞義"
                if let terms = item["terms"] as? [String], !terms.isEmpty {
                    dictEntries.append(DictionaryEntry(partOfSpeech: pos, terms: Array(terms.prefix(6))))
                }
            }
        }

        let phoneticText = phoneticFragments.isEmpty ? nil : phoneticFragments.joined(separator: " ")

        return TranslationResult(
            sourceText: trimmed,
            translatedText: finalTranslation,
            detectedSourceLanguage: detectedSrc,
            targetLanguage: resolvedTarget,
            phonetic: phoneticText,
            dictionaryEntries: dictEntries
        )
    }
}
