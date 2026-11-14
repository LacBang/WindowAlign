import AppKit
import ApplicationServices

enum WindowError: LocalizedError {
    case accessDenied, noApplication, noWindow, noScreen, unsupported, operationFailed(AXError)

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "请在系统设置 → 隐私与安全性 → 辅助功能中允许 WindowAlign。"
        case .noApplication: return "没有正在使用的应用。"
        case .noWindow: return "当前应用没有可操作的窗口。"
        case .noScreen: return "未找到显示器。"
        case .unsupported: return "这个窗口不支持调整位置或大小。"
        case .operationFailed(let code): return "调整窗口失败（辅助功能错误 \(code.rawValue)）。"
        }
    }
}

final class WindowController {
    private var savedFrames: [String: CGRect] = [:]

    func perform(_ layout: Layout, on window: AXUIElement) throws {
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success else { throw WindowError.noWindow }
        let original = try frame(of: window)
        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
        guard !screens.isEmpty else { throw WindowError.noScreen }
        let screenIndex = screens.firstIndex(where: { $0.frame.contains(CGPoint(x: original.midX, y: original.midY)) })
            ?? screens.indices.max(by: { overlap(original, screens[$0].frame) < overlap(original, screens[$1].frame) })!
        let screen = screens[screenIndex]
        let key = "\(pid):\(CFHash(window))"

        if layout == .restore {
            guard let oldFrame = savedFrames.removeValue(forKey: key) else { return }
            try setFrame(oldFrame, of: window)
            return
        }

        if savedFrames[key] == nil { savedFrames[key] = original }
        let target: CGRect
        switch layout {
        case .nextScreen, .previousScreen:
            let delta = layout == .nextScreen ? 1 : screens.count - 1
            let other = screens[(screenIndex + delta) % screens.count]
            let from = screen.visibleFrame, to = other.visibleFrame
            let width = min(original.width, to.width), height = min(original.height, to.height)
            let relativeX = from.width > original.width ? (original.minX - from.minX) / (from.width - original.width) : 0
            let relativeY = from.height > original.height ? (original.minY - from.minY) / (from.height - original.height) : 0
            target = CGRect(x: to.minX + min(max(relativeX, 0), 1) * (to.width - width),
                            y: to.minY + min(max(relativeY, 0), 1) * (to.height - height),
                            width: width, height: height)
        default:
            target = layout.frame(in: screen.visibleFrame, current: original)
        }
        try setFrame(target.integral, of: window)
    }

    func focusedWindow(targetPID: pid_t?) throws -> AXUIElement {
        guard AXIsProcessTrusted() else { throw WindowError.accessDenied }
        guard let pid = targetPID else { throw WindowError.noApplication }
        let application = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &value)
        if result != .success || value == nil {
            result = AXUIElementCopyAttributeValue(application, kAXMainWindowAttribute as CFString, &value)
        }
        guard result == .success, let window = value,
              CFGetTypeID(window) == AXUIElementGetTypeID() else { throw WindowError.noWindow }
        return window as! AXUIElement
    }

    private func frame(of window: AXUIElement) throws -> CGRect {
        var positionValue: CFTypeRef?, sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let position = positionValue, let size = sizeValue else { throw WindowError.unsupported }
        guard CFGetTypeID(position) == AXValueGetTypeID(),
              CFGetTypeID(size) == AXValueGetTypeID() else { throw WindowError.unsupported }
        var point = CGPoint.zero, dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions),
              let primary = NSScreen.screens.first else { throw WindowError.unsupported }
        return CGRect(x: point.x, y: primary.frame.maxY - point.y - dimensions.height,
                      width: dimensions.width, height: dimensions.height)
    }

    private func setFrame(_ rect: CGRect, of window: AXUIElement) throws {
        guard let primary = NSScreen.screens.first else { throw WindowError.noScreen }
        var point = CGPoint(x: rect.minX, y: primary.frame.maxY - rect.maxY)
        var size = rect.size
        guard let position = AXValueCreate(.cgPoint, &point),
              let dimensions = AXValueCreate(.cgSize, &size) else { throw WindowError.unsupported }
        // Some apps adjust their minimum size when moved; set size twice to settle the frame.
        for (attribute, value) in [(kAXSizeAttribute, dimensions), (kAXPositionAttribute, position),
                                   (kAXSizeAttribute, dimensions)] {
            let result = AXUIElementSetAttributeValue(window, attribute as CFString, value)
            guard result == .success else { throw WindowError.operationFailed(result) }
        }
    }

    private func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}
