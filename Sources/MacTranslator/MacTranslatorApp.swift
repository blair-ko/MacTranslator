import AppKit
import SwiftUI

@main
struct MacTranslatorApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private let viewModel = TranslatorViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 設定為常駐 Menu Bar 工具（不佔用 Dock 圖示）
        NSApp.setActivationPolicy(.accessory)

        setupMainMenuForEditShortcuts()
        setupStatusItem()
        setupFloatingPanel()
        setupBindingsAndHotKeys()
    }

    private func setupMainMenuForEditShortcuts() {
        let mainMenu = NSMenu()

        // App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "結束 MacTranslator", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // Edit Menu（確保 TextEditor 支援 ⌘V 貼上、⌘C 複製、⌘A 全選、⌘X 剪下、⌘Z 復原）
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            if let image = NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: "MacTranslator")?.withSymbolConfiguration(config) {
                image.isTemplate = true
                button.image = image
                button.imagePosition = .imageLeading
            } else {
                button.title = "譯"
            }
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupFloatingPanel() {
        let rect = NSRect(x: 0, y: 0, width: 480, height: 560)
        panel = FloatingPanel(contentRect: rect)
        panel.delegate = self

        let hostingView = NSHostingView(rootView: ContentView(viewModel: viewModel))
        hostingView.frame = rect
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 16
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        panel.contentView = hostingView
        panel.onEscapePressed = { [weak self] in
            self?.hidePanel()
        }
    }

    private func setupBindingsAndHotKeys() {
        viewModel.onRequestShowWindow = { [weak self] in
            self?.showPanel(nearStatusItem: false)
        }

        viewModel.onRequestHideWindowForCapture = { [weak self] in
            guard let self = self else { return }
            if self.panel.isVisible {
                self.panel.orderOut(nil)
                try? await Task.sleep(nanoseconds: 180_000_000)
            }
        }

        viewModel.onPinStateChanged = { [weak self] pinned in
            guard let self = self else { return }
            self.panel.level = pinned ? .floating : .normal
        }

        HotKeyManager.shared.onAction = { [weak self] action in
            guard let self = self else { return }
            switch action {
            case .toggleWindow:
                self.togglePanel(nearStatusItem: false)
            case .translateClipboard:
                self.viewModel.translateClipboard()
            case .screenshotOCR:
                self.viewModel.captureScreenOCR()
            }
        }
        HotKeyManager.shared.registerDefaultHotKeys()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePanel(nearStatusItem: true)
            return
        }

        if event.type == .rightMouseUp {
            showStatusContextMenu()
        } else {
            togglePanel(nearStatusItem: true)
        }
    }

    private func showStatusContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "開啟 / 隱藏翻譯視窗 (⌥+Space)", action: #selector(menuToggleWindow), keyEquivalent: "")
        menu.addItem(withTitle: "翻譯剪貼簿內容 (⌥+C)", action: #selector(menuTranslateClipboard), keyEquivalent: "")
        menu.addItem(withTitle: "區域截圖 OCR 翻譯 (⌥+S)", action: #selector(menuScreenshotOCR), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "結束 MacTranslator", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func menuToggleWindow() {
        togglePanel(nearStatusItem: true)
    }

    @objc private func menuTranslateClipboard() {
        viewModel.translateClipboard()
    }

    @objc private func menuScreenshotOCR() {
        viewModel.captureScreenOCR()
    }

    func togglePanel(nearStatusItem: Bool) {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel(nearStatusItem: nearStatusItem)
        }
    }

    func showPanel(nearStatusItem: Bool) {
        if !panel.isVisible {
            positionPanel(nearStatusItem: nearStatusItem)
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hidePanel() {
        panel.orderOut(nil)
    }

    private func positionPanel(nearStatusItem: Bool) {
        let panelSize = panel.frame.size
        if nearStatusItem,
           let button = statusItem.button,
           let buttonWindow = button.window {
            let buttonFrame = buttonWindow.frame
            let screen = buttonWindow.screen ?? NSScreen.main
            let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

            var x = buttonFrame.midX - panelSize.width / 2
            x = max(visibleFrame.minX + 12, min(x, visibleFrame.maxX - panelSize.width - 12))
            let y = buttonFrame.minY - panelSize.height - 8
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            let mouseLoc = NSEvent.mouseLocation
            let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main
            let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

            let x = visibleFrame.midX - panelSize.width / 2
            let y = visibleFrame.midY - panelSize.height / 2 + 60
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        // 若使用者點擊的是右上角工作列圖示本身，交由 statusItemClicked 切換隱藏，避免重複觸發
        if let buttonWindow = statusItem.button?.window,
           buttonWindow.frame.insetBy(dx: -4, dy: -4).contains(NSEvent.mouseLocation) {
            return
        }
        // 當未釘選置頂時，點擊視窗外部自動收合
        if !viewModel.isPinned && !viewModel.isOCRRunning {
            hidePanel()
        }
    }
}
