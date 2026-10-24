import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: TranslatorViewModel
    @ObservedObject var speechService: SpeechService
    @ObservedObject var historyStore: HistoryStore

    init(viewModel: TranslatorViewModel) {
        self.viewModel = viewModel
        self.speechService = viewModel.speechService
        self.historyStore = viewModel.historyStore
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().opacity(0.5)

            if let banner = viewModel.statusBanner {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                    Text(banner)
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.12))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Group {
                switch viewModel.activeTab {
                case .translate:
                    translateTabView
                case .history:
                    historyTabView
                case .shortcuts:
                    settingsTabView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 480, height: 560)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
        )
    }

    // MARK: - Top Header Bar
    private var headerBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Text("MacTranslator")
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 6)

            // 分頁切換
            HStack(spacing: 2) {
                tabButton(.translate, title: "翻譯", icon: "globe")
                tabButton(.history, title: "歷史", icon: "clock.arrow.circlepath", badge: historyStore.items.count)
                tabButton(.shortcuts, title: "設定", icon: "slider.horizontal.3")
            }
            .padding(3)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 6)

            // 快捷動作按鈕
            HStack(spacing: 6) {
                Button(action: { viewModel.captureScreenOCR() }) {
                    Image(systemName: viewModel.isOCRRunning ? "ellipsis" : "viewfinder.rectangular")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(HeaderIconButtonStyle(isActive: viewModel.isOCRRunning))
                .help("區域截圖 OCR 翻譯 (⌥ + S)")

                Button(action: { viewModel.translateClipboard() }) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(HeaderIconButtonStyle(isActive: false))
                .help("翻譯剪貼簿文字或圖片 (⌥ + C)")

                Button(action: { viewModel.togglePin() }) {
                    Image(systemName: viewModel.isPinned ? "pin.fill" : "pin.slash")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(HeaderIconButtonStyle(isActive: viewModel.isPinned))
                .help(viewModel.isPinned ? "視窗已置頂（點擊取消置頂）" : "點擊將視窗置頂")
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func tabButton(_ tab: TranslatorViewModel.Tab, title: String, icon: String, badge: Int = 0) -> some View {
        let isSelected = viewModel.activeTab == tab
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.activeTab = tab
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                if badge > 0 && tab == .history {
                    Text("\(min(badge, 99))")
                        .font(.system(size: 9, weight: .bold))
                        .lineLimit(1)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color(nsColor: .controlBackgroundColor) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: isSelected ? .black.opacity(0.08) : .clear, radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Translate Tab
    private var translateTabView: some View {
        VStack(spacing: 10) {
            languageSelectorBar
            sourceInputCard
            translationOutputCard
        }
        .padding(12)
    }

    private var languageSelectorBar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $viewModel.sourceLanguage) {
                ForEach(Language.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .onChange(of: viewModel.sourceLanguage) { _ in
                Task { await viewModel.performTranslation() }
            }

            Button(action: { viewModel.swapLanguages() }) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(HeaderIconButtonStyle(isActive: false))
            .help("交換語言與文字")

            Picker("", selection: $viewModel.targetLanguage) {
                ForEach(Language.targetLanguages) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .onChange(of: viewModel.targetLanguage) { _ in
                Task { await viewModel.performTranslation() }
            }

            Toggle(isOn: $viewModel.smartBidirectional) {
                Text("智慧互翻")
                    .font(.system(size: 11, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .help("開啟時：輸入中文自動翻英文，輸入外文自動翻繁體中文")
            .onChange(of: viewModel.smartBidirectional) { _ in
                Task { await viewModel.performTranslation() }
            }
        }
    }

    private var sourceInputCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if viewModel.sourceText.isEmpty {
                    Text("輸入或貼上文字自動翻譯...\n快捷键：⌥+Space 喚出視窗 ｜ ⌥+C 剪貼簿翻譯 ｜ ⌥+S 截圖翻譯")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.65))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $viewModel.sourceText)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 6)
                    .padding(.top, 6)
                    .onChange(of: viewModel.sourceText) { newValue in
                        viewModel.onSourceTextChanged(newValue)
                    }
            }
            .frame(height: 135)

            Divider().opacity(0.4)

            HStack(spacing: 8) {
                // 語音朗讀原文
                Button(action: { viewModel.speakSource() }) {
                    HStack(spacing: 4) {
                        Image(systemName: speechService.speakingTarget == .source ? "stop.circle.fill" : "speaker.wave.2.fill")
                        Text(speechService.speakingTarget == .source ? "停止" : "朗讀")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(SmallActionButtonStyle(isHighlighted: speechService.speakingTarget == .source))
                .disabled(viewModel.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let result = viewModel.currentResult, viewModel.sourceLanguage == .auto {
                    Text("偵測：\(result.detectedLanguageDisplay) → \(result.targetLanguage.displayName)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text("\(viewModel.sourceText.count) 字")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if !viewModel.sourceText.isEmpty {
                    Button(action: { viewModel.clearText() }) {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark.circle.fill")
                            Text("清除")
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(SmallActionButtonStyle())
                }

                Button(action: {
                    Task { await viewModel.performTranslation(saveToHistory: true) }
                }) {
                    HStack(spacing: 4) {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.mini)
                                .scaleEffect(0.75)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("翻譯")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.03))
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private var translationOutputCard: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let error = viewModel.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let result = viewModel.currentResult {
                        // 主翻譯結果（支援滑鼠選取）
                        Text(result.translatedText)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)

                        // 拼音 / 音標
                        if let phonetic = result.phonetic, !phonetic.isEmpty {
                            Text(phonetic)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }

                        // 字典多詞性解釋
                        if !result.dictionaryEntries.isEmpty {
                            Divider().padding(.vertical, 4)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("詞典詳解（點擊詞彙可直接複製）")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)

                                ForEach(result.dictionaryEntries) { entry in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(entry.partOfSpeech)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.accentColor)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                            .frame(minWidth: 44, alignment: .leading)

                                        FlowLayoutView(items: entry.terms) { term in
                                            Button(action: {
                                                NSPasteboard.general.clearContents()
                                                NSPasteboard.general.setString(term, forType: .string)
                                                viewModel.copiedFeedback = true
                                                Task {
                                                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                                                    viewModel.copiedFeedback = false
                                                }
                                            }) {
                                                Text(term)
                                                    .font(.system(size: 12))
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 2)
                                                    .background(Color.primary.opacity(0.06))
                                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    } else if viewModel.isOCRRunning {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("正在進行螢幕截圖與 OCR 文字辨識...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "character.book.closed")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary.opacity(0.35))
                            Text("翻譯結果與字典詞義將顯示於此")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                    }
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.4)

            // 翻譯結果底部工具列
            HStack(spacing: 8) {
                Button(action: { viewModel.speakTranslated() }) {
                    HStack(spacing: 4) {
                        Image(systemName: speechService.speakingTarget == .translated ? "stop.circle.fill" : "speaker.wave.2.fill")
                        Text(speechService.speakingTarget == .translated ? "停止朗讀" : "朗讀譯文")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(SmallActionButtonStyle(isHighlighted: speechService.speakingTarget == .translated))
                .disabled(viewModel.currentResult == nil)

                Spacer()

                Button(action: { viewModel.copyTranslatedText() }) {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.copiedFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                            .foregroundColor(viewModel.copiedFeedback ? .green : .primary)
                        Text(viewModel.copiedFeedback ? "已複製！" : "一鍵複製")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(SmallActionButtonStyle(isHighlighted: viewModel.copiedFeedback))
                .disabled(viewModel.currentResult == nil)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.03))
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - History Tab
    private var historyTabView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    TextField("搜尋歷史翻譯紀錄...", text: $viewModel.historySearchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !viewModel.historySearchQuery.isEmpty {
                        Button(action: { viewModel.historySearchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 7))

                Toggle(isOn: $viewModel.showFavoritesOnly) {
                    HStack(spacing: 3) {
                        Image(systemName: viewModel.showFavoritesOnly ? "star.fill" : "star")
                            .foregroundColor(viewModel.showFavoritesOnly ? .yellow : .secondary)
                        Text("收藏")
                            .font(.system(size: 11))
                    }
                }
                .toggleStyle(.button)
                .controlSize(.small)

                if !historyStore.items.isEmpty {
                    Button(action: { historyStore.clearAll(keepFavorites: true) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(SmallActionButtonStyle())
                    .help("清除未收藏的歷史紀錄")
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if viewModel.filteredHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(viewModel.showFavoritesOnly ? "尚無收藏的翻譯紀錄" : "尚無歷史翻譯紀錄")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredHistory) { item in
                            historyRow(item)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func historyRow(_ item: HistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("\(item.sourceLangCode.uppercased()) → \(item.targetLangCode.uppercased())")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(item.formattedTime)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.translatedText, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("複製譯文")

                Button(action: { historyStore.toggleFavorite(id: item.id) }) {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundColor(item.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(item.isFavorite ? "取消收藏" : "加入收藏")

                Button(action: { historyStore.delete(id: item.id) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("刪除此筆紀錄")
            }

            Button(action: { viewModel.restoreHistoryItem(item) }) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.sourceText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(item.translatedText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Settings & Shortcuts Tab
    private var settingsTabView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox(label: Label("全域快捷鍵 (Global Shortcuts)", systemImage: "command")) {
                    VStack(spacing: 10) {
                        shortcutRow(title: "喚出 / 隱藏翻譯視窗", keys: "⌥ Option + Space")
                        Divider()
                        shortcutRow(title: "翻譯剪貼簿內容（支援文字與圖片）", keys: "⌥ Option + C")
                        Divider()
                        shortcutRow(title: "互動式區域截圖 OCR 翻譯", keys: "⌥ Option + S")
                    }
                    .padding(8)
                }

                GroupBox(label: Label("翻譯偏好設定", systemImage: "gearshape")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("啟用中英雙向智慧自動互翻", isOn: $viewModel.smartBidirectional)
                        Text("當來源語言為「自動偵測」時，輸入中文會自動譯為英文；輸入外文會自動譯為繁體中文。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        Divider()

                        Toggle("翻譯完成後自動複製譯文到剪貼簿", isOn: $viewModel.autoCopyResult)

                        Divider()

                        Toggle("保持翻譯視窗浮動置頂 (Pin on Top)", isOn: Binding(
                            get: { viewModel.isPinned },
                            set: { newVal in
                                viewModel.isPinned = newVal
                                viewModel.onPinStateChanged?(newVal)
                            }
                        ))
                    }
                    .padding(8)
                }

                GroupBox(label: Label("關於 MacTranslator", systemImage: "info.circle")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("原生 Swift / SwiftUI 打造的輕量級 macOS 選單列翻譯工具。")
                            .font(.system(size: 12))
                        Text("• 免 API Key 支援免費即時翻譯、詞典多詞性查詢与拼音標示\n• 內建 Apple Vision 原生高精度中/英/日/韓截圖 OCR 辨識\n• 內建 AVSpeechSynthesizer 多語系自然語音朗讀")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }

                HStack {
                    Spacer()
                    Button(role: .destructive, action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "power")
                            Text("結束 MacTranslator")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                }
                .padding(.top, 4)
            }
            .padding(14)
        }
    }

    private func shortcutRow(title: String, keys: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
            Spacer()
            Text(keys)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
    }
}

// MARK: - Helper Views & Styles

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 16
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct HeaderIconButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isActive ? .accentColor : .primary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive
                          ? Color.accentColor.opacity(0.16)
                          : (configuration.isPressed ? Color.primary.opacity(0.12) : Color.primary.opacity(0.05)))
            )
    }
}

struct SmallActionButtonStyle: ButtonStyle {
    var isHighlighted: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isHighlighted ? .accentColor : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHighlighted
                          ? Color.accentColor.opacity(0.14)
                          : (configuration.isPressed ? Color.primary.opacity(0.1) : Color.primary.opacity(0.05)))
            )
    }
}

struct FlowLayoutView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(items), id: \.self) { item in
                content(item)
            }
        }
    }
}
