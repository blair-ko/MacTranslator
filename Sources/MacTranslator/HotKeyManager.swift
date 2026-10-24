import Carbon
import Foundation

final class HotKeyManager {
    enum Action: UInt32 {
        case toggleWindow = 1
        case translateClipboard = 2
        case screenshotOCR = 3
    }

    nonisolated(unsafe) static let shared = HotKeyManager()

    var onAction: (@MainActor (Action) -> Void)?

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    func registerDefaultHotKeys() {
        unregisterAll()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard err == noErr, let action = HotKeyManager.Action(rawValue: hotKeyID.id) else {
                    return noErr
                }
                Task { @MainActor in
                    HotKeyManager.shared.onAction?(action)
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        guard status == noErr else { return }

        // ⌥ + Space : 開啟 / 隱藏翻譯視窗
        registerHotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey), action: .toggleWindow)
        // ⌥ + C : 翻譯剪貼簿內容
        registerHotKey(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(optionKey), action: .translateClipboard)
        // ⌥ + S : 截圖 OCR 翻譯
        registerHotKey(keyCode: UInt32(kVK_ANSI_S), modifiers: UInt32(optionKey), action: .screenshotOCR)
    }

    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, action: Action) {
        let signature: OSType = 0x4D54524E // 'MTRN'
        let hotKeyID = EventHotKeyID(signature: signature, id: action.rawValue)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRefs.append(ref)
        }
    }

    func unregisterAll() {
        for ref in hotKeyRefs {
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }
}
