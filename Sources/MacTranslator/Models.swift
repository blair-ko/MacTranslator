import Foundation

enum Language: String, CaseIterable, Identifiable, Codable {
    case auto = "auto"
    case zhTW = "zh-TW"
    case zhCN = "zh-CN"
    case en = "en"
    case ja = "ja"
    case ko = "ko"
    case fr = "fr"
    case de = "de"
    case es = "es"
    case th = "th"
    case vi = "vi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "自動偵測"
        case .zhTW: return "繁體中文"
        case .zhCN: return "簡體中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .th: return "ไทย"
        case .vi: return "Tiếng Việt"
        }
    }

    var shortBadge: String {
        switch self {
        case .auto: return "AUTO"
        case .zhTW: return "中(繁)"
        case .zhCN: return "中(簡)"
        case .en: return "EN"
        case .ja: return "JA"
        case .ko: return "KO"
        case .fr: return "FR"
        case .de: return "DE"
        case .es: return "ES"
        case .th: return "TH"
        case .vi: return "VI"
        }
    }

    var speechLocale: String {
        switch self {
        case .auto, .en: return "en-US"
        case .zhTW: return "zh-TW"
        case .zhCN: return "zh-CN"
        case .ja: return "ja-JP"
        case .ko: return "ko-KR"
        case .fr: return "fr-FR"
        case .de: return "de-DE"
        case .es: return "es-ES"
        case .th: return "th-TH"
        case .vi: return "vi-VN"
        }
    }

    static var targetLanguages: [Language] {
        allCases.filter { $0 != .auto }
    }

    static func fromGoogleCode(_ code: String) -> Language? {
        let normalized = code.lowercased()
        if normalized.hasPrefix("zh-tw") || normalized.hasPrefix("zh-hant") {
            return .zhTW
        } else if normalized.hasPrefix("zh") {
            return .zhCN
        }
        return allCases.first { $0.rawValue.lowercased() == normalized }
    }
}

struct DictionaryEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    let partOfSpeech: String
    let terms: [String]
}

struct TranslationResult: Codable, Equatable {
    let sourceText: String
    let translatedText: String
    let detectedSourceLanguage: String
    let targetLanguage: Language
    let phonetic: String?
    let dictionaryEntries: [DictionaryEntry]

    var detectedLanguageDisplay: String {
        if let lang = Language.fromGoogleCode(detectedSourceLanguage) {
            return lang.displayName
        }
        return detectedSourceLanguage.uppercased()
    }
}

struct HistoryItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let timestamp: Date
    let sourceText: String
    let translatedText: String
    let sourceLangCode: String
    let targetLangCode: String
    var isFavorite: Bool = false

    var formattedTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh-Hant-TW")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
