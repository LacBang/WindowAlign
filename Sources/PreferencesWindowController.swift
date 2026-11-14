import AppKit

private enum RecordingResult {
    case set(Shortcut), clear, cancel, invalid
}

private final class ShortcutRecorderButton: NSButton {
    var onResult: ((RecordingResult) -> Void)?
    private(set) var recording = false

    override var acceptsFirstResponder: Bool { true }

    func begin() {
        recording = true
        title = "请按组合键…"
        window?.makeFirstResponder(self)
    }

    func end(with label: String) {
        recording = false
        title = label
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { onResult?(.cancel); return }
        if event.keyCode == 51 || event.keyCode == 117 { onResult?(.clear); return }
        guard let shortcut = Shortcut.from(event) else { onResult?(.invalid); return }
        onResult?(.set(shortcut))
    }
}

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private let hotkeys: Hotkeys
    private let onChange: () -> Void
    private var buttons: [Layout: ShortcutRecorderButton] = [:]
    private var recordingLayout: Layout?
    private let message = NSTextField(labelWithString: "点击快捷键，再按新的组合键。Esc 取消，Delete 清除。")

    init(hotkeys: Hotkeys, onChange: @escaping () -> Void) {
        self.hotkeys = hotkeys
        self.onChange = onChange
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 430, height: 470),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "WindowAlign · 快捷键"
        window.center()
        super.init(window: window)
        window.delegate = self
        buildInterface()
    }

    required init?(coder: NSCoder) { nil }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildInterface() {
        guard let content = window?.contentView else { return }
        let heading = NSTextField(labelWithString: "窗口布局快捷键")
        heading.font = .boldSystemFont(ofSize: 18)
        message.font = .systemFont(ofSize: 12)
        message.textColor = .secondaryLabelColor
        message.lineBreakMode = .byTruncatingTail

        let gridRows: [[NSView]] = Layout.menuLayouts.map { layout in
            let label = NSTextField(labelWithString: layout.title)
            label.alignment = .right
            let button = ShortcutRecorderButton(title: hotkeys.store.shortcut(for: layout)?.label ?? "未设置",
                                                target: self, action: #selector(beginRecording(_:)))
            button.bezelStyle = .rounded
            button.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
            button.identifier = NSUserInterfaceItemIdentifier(layout.rawValue)
            button.onResult = { [weak self] result in self?.complete(result, for: layout) }
            buttons[layout] = button
            return [label, button]
        }
        let grid = NSGridView(views: gridRows)
        grid.columnSpacing = 18
        grid.rowSpacing = 7
        grid.column(at: 0).width = 125
        grid.column(at: 1).width = 175

        let reset = NSButton(title: "恢复默认快捷键", target: self, action: #selector(resetShortcuts))
        reset.bezelStyle = .rounded
        let stack = NSStackView(views: [heading, message, grid, reset])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24)
        ])
    }

    @objc private func beginRecording(_ sender: ShortcutRecorderButton) {
        guard let raw = sender.identifier?.rawValue, let layout = Layout(rawValue: raw) else { return }
        finishRecording()
        recordingLayout = layout
        hotkeys.pause()
        sender.begin()
        message.stringValue = "正在录入“\(layout.title)”：按组合键，Esc 取消，Delete 清除。"
        message.textColor = .secondaryLabelColor
    }

    private func complete(_ result: RecordingResult, for layout: Layout) {
        guard recordingLayout == layout else { return }
        defer { finishRecording() }
        do {
            switch result {
            case .set(let shortcut):
                try hotkeys.update(layout, to: shortcut)
                message.stringValue = "已保存“\(layout.title)”的快捷键。"
            case .clear:
                try hotkeys.update(layout, to: nil)
                message.stringValue = "已清除“\(layout.title)”的快捷键。"
            case .cancel:
                message.stringValue = "已取消录入。"
            case .invalid:
                message.stringValue = "请同时按 ⌘、⌃ 或 ⌥ 中的至少一个修饰键。"
                message.textColor = .systemRed
                return
            }
            message.textColor = .secondaryLabelColor
            onChange()
        } catch {
            message.stringValue = error.localizedDescription
            message.textColor = .systemRed
        }
    }

    private func finishRecording() {
        if let layout = recordingLayout {
            buttons[layout]?.end(with: hotkeys.store.shortcut(for: layout)?.label ?? "未设置")
        }
        recordingLayout = nil
        hotkeys.reload()
    }

    @objc private func resetShortcuts() {
        finishRecording()
        hotkeys.store.reset()
        hotkeys.reload()
        refreshButtons()
        message.stringValue = "已恢复默认快捷键。"
        message.textColor = .secondaryLabelColor
        onChange()
    }

    private func refreshButtons() {
        for layout in Layout.menuLayouts {
            buttons[layout]?.end(with: hotkeys.store.shortcut(for: layout)?.label ?? "未设置")
        }
    }

    func windowWillClose(_ notification: Notification) { finishRecording() }
    func windowDidResignKey(_ notification: Notification) {
        if recordingLayout != nil { finishRecording() }
    }
}
