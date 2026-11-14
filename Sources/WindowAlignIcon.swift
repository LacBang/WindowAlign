import AppKit

enum WindowAlignIcon {
    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            NSColor.black.setStroke()
            let back = NSBezierPath(roundedRect: CGRect(x: 2, y: 3, width: 11, height: 12),
                                    xRadius: 2, yRadius: 2)
            back.lineWidth = 1.5
            back.stroke()
            let front = NSBezierPath(roundedRect: CGRect(x: 7, y: 5, width: 11, height: 12),
                                     xRadius: 2, yRadius: 2)
            front.lineWidth = 1.5
            front.stroke()
            let arrow = NSBezierPath()
            arrow.lineWidth = 1.7
            arrow.lineCapStyle = .round
            arrow.lineJoinStyle = .round
            arrow.move(to: CGPoint(x: 9.5, y: 8))
            arrow.line(to: CGPoint(x: 15.5, y: 14))
            arrow.move(to: CGPoint(x: 11.7, y: 14))
            arrow.line(to: CGPoint(x: 15.5, y: 14))
            arrow.line(to: CGPoint(x: 15.5, y: 10.2))
            arrow.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
