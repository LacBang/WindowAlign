import AppKit
import Carbon

struct Shortcut {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    var label: String {
        var symbols = ""
        if modifiers & UInt32(controlKey) != 0 { symbols += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { symbols += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘" }
        return symbols + keyLabel
    }

    func matches(_ other: Shortcut) -> Bool {
        keyCode == other.keyCode && modifiers == other.modifiers
    }

    static func from(_ event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        guard modifiers & UInt32(cmdKey | controlKey | optionKey) != 0 else { return nil }
        let special: [UInt16: String] = [
            123: "←", 124: "→", 125: "↓", 126: "↑",
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫"
        ]
        let key = special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? ""
        guard !key.isEmpty else { return nil }
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: key)
    }
}

enum ShortcutError: LocalizedError {
    case duplicate, unavailable
    var errorDescription: String? {
        switch self {
        case .duplicate: return "这个组合键已经分配给其他布局。"
        case .unavailable: return "这个组合键被系统或其他应用占用。"
        }
    }
}

final class ShortcutStore {
    private let key = "WindowAlign.Shortcuts.v1"
    private let defaultModifiers = UInt32(cmdKey | controlKey)
    private let defaults: [(Layout, UInt32, String)] = [
        (.left, 123, "←"), (.right, 124, "→"),
        (.top, 126, "↑"), (.bottom, 125, "↓"),
        (.topLeft, 34, "I"), (.topRight, 31, "O"),
        (.bottomLeft, 40, "K"), (.bottomRight, 37, "L"),
        (.leftThird, 7, "X"), (.middleThird, 11, "B"),
        (.rightThird, 9, "Z"), (.full, 3, "F")
    ]

    func shortcut(for layout: Layout) -> Shortcut? {
        let saved = UserDefaults.standard.dictionary(forKey: key)?[layout.rawValue] as? [String: Any]
        if let saved = saved {
            guard saved["enabled"] as? Bool == true,
                  let keyCode = saved["keyCode"] as? UInt32,
                  let modifiers = saved["modifiers"] as? UInt32,
                  let label = saved["keyLabel"] as? String else { return nil }
            return Shortcut(keyCode: keyCode, modifiers: modifiers, keyLabel: label)
        }
        guard let item = defaults.first(where: { $0.0 == layout }) else { return nil }
        return Shortcut(keyCode: item.1, modifiers: defaultModifiers, keyLabel: item.2)
    }

    func save(_ shortcut: Shortcut?, for layout: Layout) {
        var all = UserDefaults.standard.dictionary(forKey: key) ?? [:]
        if let shortcut = shortcut {
            all[layout.rawValue] = ["enabled": true, "keyCode": shortcut.keyCode,
                                    "modifiers": shortcut.modifiers,
                                    "keyLabel": shortcut.keyLabel] as [String: Any]
        } else {
            all[layout.rawValue] = ["enabled": false]
        }
        UserDefaults.standard.set(all, forKey: key)
    }

    func reset() { UserDefaults.standard.removeObject(forKey: key) }
}

final class Hotkeys {
    let store = ShortcutStore()
    private var references: [EventHotKeyRef?] = []
    private var handler: EventHandlerRef?
    var onAction: ((Layout) -> Void)?

    func start() {
        if handler == nil {
            var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
            let callback: EventHandlerUPP = { _, event, userData in
                guard let userData = userData, let event = event else { return noErr }
                let owner = Unmanaged<Hotkeys>.fromOpaque(userData).takeUnretainedValue()
                var id = EventHotKeyID()
                let result = GetEventParameter(event, UInt32(kEventParamDirectObject),
                                               UInt32(typeEventHotKeyID), nil,
                                               MemoryLayout<EventHotKeyID>.size, nil, &id)
                if result == noErr { owner.dispatch(id.id) }
                return noErr
            }
            let pointer = Unmanaged.passUnretained(self).toOpaque()
            InstallEventHandler(GetApplicationEventTarget(), callback, 1, &event, pointer, &handler)
        }
        reload()
    }

    func pause() {
        references.forEach { if let reference = $0 { UnregisterEventHotKey(reference) } }
        references.removeAll()
    }

    func reload() {
        pause()
        for (index, layout) in Layout.menuLayouts.enumerated() {
            guard let shortcut = store.shortcut(for: layout) else { continue }
            var reference: EventHotKeyRef?
            let id = EventHotKeyID(signature: 0x57414C4E, id: UInt32(index + 1))
            let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id,
                                             GetApplicationEventTarget(), 0, &reference)
            if status == noErr {
                references.append(reference)
            } else {
                NSLog("WindowAlign hotkey failed: %@ status=%d", layout.rawValue, status)
            }
        }
    }

    func update(_ layout: Layout, to shortcut: Shortcut?) throws {
        if let shortcut = shortcut {
            if Layout.menuLayouts.contains(where: { $0 != layout && store.shortcut(for: $0)?.matches(shortcut) == true }) {
                throw ShortcutError.duplicate
            }
            var testReference: EventHotKeyRef?
            let testID = EventHotKeyID(signature: 0x57414C4E, id: 999)
            guard RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, testID,
                                      GetApplicationEventTarget(), 0, &testReference) == noErr else {
                throw ShortcutError.unavailable
            }
            if let testReference = testReference { UnregisterEventHotKey(testReference) }
        }
        store.save(shortcut, for: layout)
        reload()
    }

    private func dispatch(_ id: UInt32) {
        let index = Int(id) - 1
        guard Layout.menuLayouts.indices.contains(index) else { return }
        NSLog("WindowAlign hotkey dispatched: %@", Layout.menuLayouts[index].rawValue)
        onAction?(Layout.menuLayouts[index])
    }

    deinit {
        pause()
        if let handler = handler { RemoveEventHandler(handler) }
    }
}
