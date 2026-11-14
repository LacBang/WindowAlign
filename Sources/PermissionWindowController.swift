import AppKit
import ApplicationServices

/// First-launch (and any later untrusted) Accessibility explanation.
/// The menu-bar app is an accessory; this window briefly becomes a regular app so it can appear in front.
final class PermissionWindowController: NSWindowController, NSWindowDelegate {
    private let iconView = NSImageView()
    private let heading = NSTextField(labelWithString: "需要辅助功能权限")
    private let explanation = NSTextField(wrappingLabelWithString:
        "WindowAlign 需要辅助功能权限，才能移动和调整其他应用的窗口；这是 macOS 的系统保护；授权后才能使用快捷键和菜单栏布局；应用无网络请求，不会上传窗口内容。")
    private let hint = NSTextField(wrappingLabelWithString:
        "在“隐私与安全性 → 辅助功能”中打开 WindowAlign 的开关。如果列表里已有 WindowAlign 但无法使用，请先移除再重新添加。授权完成后回到本窗口即可。")
    private let openSettingsButton = NSButton(title: "打开系统设置", target: nil, action: nil)
    private let laterButton = NSButton(title: "稍后", target: nil, action: nil)
    private let actions = NSStackView()
    private var pollTimer: Timer?
    private var showingSuccess = false
    private var session = 0

    /// Ventura and later use System Settings; the older Security pane URL is the fallback.
    private let settingsURLs = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    ]

    init() {
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 520, height: 360),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "需要辅助功能权限"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        super.init(window: window)
        window.delegate = self
        window.center()
        buildInterface()
    }

    required init?(coder: NSCoder) { nil }

    func present() {
        session += 1
        stopPolling()
        if AXIsProcessTrusted() {
            showingSuccess = false
            showSuccess()
        } else {
            showPrompt()
            startPolling()
        }
        showWindow(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildInterface() {
        guard let content = window?.contentView else { return }
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.contentTintColor = .controlAccentColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        heading.font = .boldSystemFont(ofSize: 18)
        configureWrapping(explanation, font: .systemFont(ofSize: 13), color: .labelColor)
        configureWrapping(hint, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)

        openSettingsButton.bezelStyle = .rounded
        openSettingsButton.target = self
        openSettingsButton.action = #selector(openSystemSettings)
        openSettingsButton.keyEquivalent = "\r"
        laterButton.bezelStyle = .rounded
        laterButton.target = self
        laterButton.action = #selector(dismissLater)
        laterButton.keyEquivalent = "\u{1b}"

        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 12
        actions.addArrangedSubview(laterButton)
        actions.addArrangedSubview(openSettingsButton)

        let titleRow = NSStackView(views: [iconView, heading])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 10

        let stack = NSStackView(views: [titleRow, explanation, actions, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24)
        ])
        window?.defaultButtonCell = openSettingsButton.cell as? NSButtonCell
        showPrompt()
    }

    private func configureWrapping(_ field: NSTextField, font: NSFont, color: NSColor) {
        field.font = font
        field.textColor = color
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.usesSingleLineMode = false
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        field.preferredMaxLayoutWidth = 460
    }

    private func showPrompt() {
        showingSuccess = false
        window?.title = "需要辅助功能权限"
        heading.stringValue = "需要辅助功能权限"
        iconView.image = symbol("hand.raised.fill", description: "辅助功能")
        explanation.isHidden = false
        hint.isHidden = false
        actions.isHidden = false
    }

    private func showSuccess() {
        guard !showingSuccess else { return }
        showingSuccess = true
        stopPolling()
        let session = self.session
        window?.title = "WindowAlign"
        heading.stringValue = "已授权，可以开始使用"
        iconView.image = symbol("checkmark.circle.fill", description: "已授权")
        explanation.isHidden = true
        hint.isHidden = true
        actions.isHidden = true
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard let self, self.session == session, self.showingSuccess else { return }
            self.window?.close()
        }
    }

    private func symbol(_ name: String, description: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        return NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(configuration)
    }

    private func startPolling() {
        stopPolling()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshTrust()
        }
        pollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refreshTrust() {
        guard !showingSuccess, AXIsProcessTrusted() else { return }
        showSuccess()
    }

    @objc private func openSystemSettings() {
        // Register this app in the Accessibility list, then open the pane itself.
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(prompt)
        for raw in settingsURLs {
            guard let url = URL(string: raw), NSWorkspace.shared.open(url) else { continue }
            NSLog("WindowAlign opened Accessibility settings: %@", raw)
            return
        }
        NSLog("WindowAlign failed to open Accessibility settings")
    }

    @objc private func dismissLater() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        stopPolling()
        NSApp.setActivationPolicy(.accessory)
    }
}
