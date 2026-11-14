import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let windowController = WindowController()
    private let hotkeys = Hotkeys()
    private var statusItem: NSStatusItem!
    private var targetPID: pid_t?
    private var menuWindow: Result<AXUIElement, Error>?
    private var preferences: PreferencesWindowController?
    private var permissionWindow: PermissionWindowController?
    private var permissionItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        targetPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        NSLog("WindowAlign launch: AX trusted=%d, initial target=%d",
              AXIsProcessTrusted() ? 1 : 0, targetPID ?? -1)
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handleURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(applicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = WindowAlignIcon.menuBarImage()
        statusItem.button?.toolTip = "WindowAlign · 窗口布局"
        configureMenu()
        hotkeys.onAction = { [weak self] layout in self?.apply(layout) }
        hotkeys.start()
        // Wait until the run loop is up so an accessory app can come forward.
        if !AXIsProcessTrusted() {
            DispatchQueue.main.async { [weak self] in
                self?.presentPermissionOnboarding()
            }
        }
    }

    @objc private func applicationActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              isTargetApplication(app) else { return }
        targetPID = app.processIdentifier
        NSLog("WindowAlign target: %@ pid=%d", app.localizedName ?? "?", app.processIdentifier)
    }

    private func isTargetApplication(_ app: NSRunningApplication) -> Bool {
        app.processIdentifier != ProcessInfo.processInfo.processIdentifier
            && app.bundleIdentifier != "com.apple.shortcuts"
            && app.bundleIdentifier != "com.apple.WorkflowKit.BackgroundShortcutRunner"
    }

    @objc private func handleURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        NSLog("WindowAlign URL event: %@", event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue ?? "?")
        guard let raw = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: raw), url.scheme == "windowalign",
              let name = url.host, let layout = Layout(rawValue: name) else { return }
        apply(layout)
    }

    private func configureMenu() {
        let menu = NSMenu(title: "WindowAlign")
        menu.delegate = self
        // The custom rows handle clicks through their buttons instead of a menu item action.
        menu.autoenablesItems = false
        menu.minimumWidth = 310
        menu.addItem(makeModeRow("半屏", symbol: "rectangle.split.2x1",
                                 rows: [[("左", .left), ("右", .right)],
                                        [("上", .top), ("下", .bottom)]]))
        menu.addItem(makeModeRow("四分屏", symbol: "rectangle.split.2x2",
                                 rows: [[("左上", .topLeft), ("右上", .topRight)],
                                        [("左下", .bottomLeft), ("右下", .bottomRight)]]))
        menu.addItem(makeModeRow("三分屏", symbol: "rectangle.split.3x1",
                                 rows: [[("左", .leftThird), ("中", .middleThird), ("右", .rightThird)]],
                                 spacing: "   "))
        menu.addItem(makeModeRow("全屏", symbol: "arrow.up.left.and.arrow.down.right",
                                 rows: [[("填满可用区域", .full)]]))
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "修改快捷键…", action: #selector(openPreferences), keyEquivalent: "")
        settings.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        settings.target = self
        menu.addItem(settings)
        let permission = NSMenuItem(title: "检查辅助功能权限…", action: #selector(requestAccessibility), keyEquivalent: "")
        permission.image = NSImage(systemSymbolName: "hand.raised", accessibilityDescription: nil)
        permission.target = self
        permissionItem = permission
        menu.addItem(permission)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 WindowAlign", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        let frontmostPID = NSWorkspace.shared.frontmostApplication.flatMap { app in
            isTargetApplication(app) ? app.processIdentifier : nil
        }
        let menuTargetPID = frontmostPID ?? targetPID
        menuWindow = Result { try windowController.focusedWindow(targetPID: menuTargetPID) }
        permissionItem?.title = AXIsProcessTrusted()
            ? "辅助功能：已授权"
            : "检查辅助功能权限…"
    }

    func menuDidClose(_ menu: NSMenu) {
        menuWindow = nil
    }

    private func shortcut(_ layout: Layout) -> String {
        hotkeys.store.shortcut(for: layout)?.label ?? "—"
    }

    private func makeModeRow(_ title: String, symbol: String,
                             rows: [[(label: String, layout: Layout)]],
                             spacing: String = "     ") -> NSMenuItem {
        let height: CGFloat = rows.count == 1 ? 43 : 57
        let view = NSView(frame: CGRect(x: 0, y: 0, width: 310, height: height))
        let image = NSImageView(frame: CGRect(x: 16, y: height - 26, width: 17, height: 17))
        image.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        image.contentTintColor = .controlAccentColor
        view.addSubview(image)
        let name = NSTextField(labelWithString: title)
        name.font = .systemFont(ofSize: 13, weight: .semibold)
        name.frame = CGRect(x: 42, y: height - 25, width: 250, height: 18)
        view.addSubview(name)
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        for (index, row) in rows.enumerated() {
            let labels = row.map { "\($0.label) \(shortcut($0.layout))" }
            let detail = NSTextField(labelWithString: labels.joined(separator: spacing))
            detail.font = font
            detail.textColor = .secondaryLabelColor
            detail.frame = CGRect(x: 42, y: height - 41 - CGFloat(index * 14), width: 260, height: 15)
            detail.setAccessibilityElement(false)
            view.addSubview(detail)

            // Keep the original line of text and overlay a separate hit area for each action.
            var prefix = ""
            for (choice, label) in zip(row, labels) {
                let offset = (prefix as NSString).size(withAttributes: [.font: font]).width
                let width = (label as NSString).size(withAttributes: [.font: font]).width
                let button = NSButton(title: choice.layout.title, target: self, action: #selector(selectLayout(_:)))
                button.identifier = NSUserInterfaceItemIdentifier(choice.layout.rawValue)
                button.isTransparent = true
                button.frame = CGRect(x: detail.frame.minX + offset, y: detail.frame.minY,
                                      width: ceil(width) + 4, height: 14)
                view.addSubview(button)
                prefix += label + spacing
            }
        }
        let item = NSMenuItem()
        item.view = view
        return item
    }

    @objc private func selectLayout(_ button: NSButton) {
        guard let identifier = button.identifier, let layout = Layout(rawValue: identifier.rawValue),
              let menuWindow else { return }
        statusItem.menu?.cancelTracking()
        DispatchQueue.main.async { [weak self] in self?.apply(layout, to: menuWindow) }
    }

    @objc private func openPreferences() {
        if preferences == nil {
            preferences = PreferencesWindowController(hotkeys: hotkeys) { [weak self] in
                self?.configureMenu()
            }
        }
        preferences?.present()
    }

    private func apply(_ layout: Layout, to window: Result<AXUIElement, Error>? = nil) {
        NSLog("WindowAlign action: %@ target=%d trusted=%d", layout.rawValue,
              targetPID ?? -1, AXIsProcessTrusted() ? 1 : 0)
        do {
            let target = try window?.get() ?? windowController.focusedWindow(targetPID: targetPID)
            try windowController.perform(layout, on: target)
            NSLog("WindowAlign action succeeded: %@", layout.rawValue)
        } catch {
            NSLog("WindowAlign action failed: %@", error.localizedDescription)
            if let windowError = error as? WindowError, case .accessDenied = windowError {
                presentPermissionOnboarding()
                return
            }
            let alert = NSAlert()
            alert.messageText = "WindowAlign"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private func presentPermissionOnboarding() {
        if permissionWindow == nil {
            permissionWindow = PermissionWindowController()
        }
        permissionWindow?.present()
    }

    @objc private func requestAccessibility() {
        presentPermissionOnboarding()
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}
