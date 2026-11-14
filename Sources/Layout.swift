import AppKit

enum Layout: String, CaseIterable {
    case left, right, top, bottom, full, center
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, middleThird, rightThird, leftTwoThirds, rightTwoThirds
    case nextScreen, previousScreen, restore

    static let menuLayouts: [Layout] = [
        .left, .right, .top, .bottom,
        .topLeft, .topRight, .bottomLeft, .bottomRight,
        .leftThird, .middleThird, .rightThird, .full
    ]

    var title: String {
        switch self {
        case .left: return "左半屏"
        case .right: return "右半屏"
        case .top: return "上半屏"
        case .bottom: return "下半屏"
        case .full: return "填满可用区域"
        case .center: return "居中"
        case .topLeft: return "左上角"
        case .topRight: return "右上角"
        case .bottomLeft: return "左下角"
        case .bottomRight: return "右下角"
        case .leftThird: return "左三分之一"
        case .middleThird: return "中三分之一"
        case .rightThird: return "右三分之一"
        case .leftTwoThirds: return "左三分之二"
        case .rightTwoThirds: return "右三分之二"
        case .nextScreen: return "移至下一显示器"
        case .previousScreen: return "移至上一显示器"
        case .restore: return "恢复原尺寸"
        }
    }

    func frame(in area: CGRect, current: CGRect) -> CGRect {
        let x = area.minX, y = area.minY, w = area.width, h = area.height
        switch self {
        case .left: return CGRect(x: x, y: y, width: w / 2, height: h)
        case .right: return CGRect(x: x + w / 2, y: y, width: w / 2, height: h)
        case .top: return CGRect(x: x, y: y + h / 2, width: w, height: h / 2)
        case .bottom: return CGRect(x: x, y: y, width: w, height: h / 2)
        case .full: return area
        case .center:
            let width = min(current.width, w), height = min(current.height, h)
            return CGRect(x: x + (w - width) / 2, y: y + (h - height) / 2,
                          width: width, height: height)
        case .topLeft: return CGRect(x: x, y: y + h / 2, width: w / 2, height: h / 2)
        case .topRight: return CGRect(x: x + w / 2, y: y + h / 2, width: w / 2, height: h / 2)
        case .bottomLeft: return CGRect(x: x, y: y, width: w / 2, height: h / 2)
        case .bottomRight: return CGRect(x: x + w / 2, y: y, width: w / 2, height: h / 2)
        case .leftThird: return CGRect(x: x, y: y, width: w / 3, height: h)
        case .middleThird: return CGRect(x: x + w / 3, y: y, width: w / 3, height: h)
        case .rightThird: return CGRect(x: x + 2 * w / 3, y: y, width: w / 3, height: h)
        case .leftTwoThirds: return CGRect(x: x, y: y, width: 2 * w / 3, height: h)
        case .rightTwoThirds: return CGRect(x: x + w / 3, y: y, width: 2 * w / 3, height: h)
        case .nextScreen, .previousScreen, .restore: return current
        }
    }
}
