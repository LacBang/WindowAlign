import AppKit

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: IconMaker OUTPUT.png")
}

let side = 1024
guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                    isPlanar: false, colorSpaceName: .deviceRGB,
                                    bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Could not create icon canvas")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
defer { NSGraphicsContext.restoreGraphicsState() }

let outer = NSBezierPath(roundedRect: CGRect(x: 40, y: 40, width: 944, height: 944),
                         xRadius: 210, yRadius: 210)
NSGradient(starting: NSColor(calibratedRed: 0.03, green: 0.63, blue: 1.0, alpha: 1),
           ending: NSColor(calibratedRed: 0.01, green: 0.35, blue: 0.88, alpha: 1))!
    .draw(in: outer, angle: 90)

let inset = NSBezierPath(roundedRect: CGRect(x: 94, y: 94, width: 836, height: 836),
                         xRadius: 165, yRadius: 165)
NSColor(calibratedRed: 0.035, green: 0.11, blue: 0.20, alpha: 1).setFill()
inset.fill()

let back = NSBezierPath(roundedRect: CGRect(x: 212, y: 266, width: 392, height: 518),
                        xRadius: 58, yRadius: 58)
NSColor(calibratedRed: 0.70, green: 0.84, blue: 0.94, alpha: 1).setFill()
back.fill()
NSColor(calibratedRed: 0.59, green: 0.76, blue: 0.88, alpha: 1).setStroke()
back.lineWidth = 5
back.stroke()

let front = NSBezierPath(roundedRect: CGRect(x: 380, y: 224, width: 432, height: 574),
                         xRadius: 64, yRadius: 64)
NSColor.white.setFill()
front.fill()
NSColor(calibratedRed: 0.82, green: 0.90, blue: 0.96, alpha: 1).setStroke()
front.lineWidth = 6
front.stroke()

let divider = NSBezierPath()
divider.move(to: CGPoint(x: 382, y: 704))
divider.line(to: CGPoint(x: 810, y: 704))
divider.lineWidth = 5
NSColor(calibratedWhite: 0.87, alpha: 1).setStroke()
divider.stroke()

for (index, color) in [
    NSColor(calibratedRed: 0.99, green: 0.40, blue: 0.39, alpha: 1),
    NSColor(calibratedRed: 0.98, green: 0.74, blue: 0.29, alpha: 1),
    NSColor(calibratedRed: 0.34, green: 0.78, blue: 0.44, alpha: 1)
].enumerated() {
    color.setFill()
    NSBezierPath(ovalIn: CGRect(x: 422 + index * 36, y: 735, width: 20, height: 20)).fill()
}

let arrow = NSBezierPath()
arrow.lineWidth = 32
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: CGPoint(x: 462, y: 360))
arrow.line(to: CGPoint(x: 700, y: 600))
arrow.move(to: CGPoint(x: 566, y: 600))
arrow.line(to: CGPoint(x: 700, y: 600))
arrow.line(to: CGPoint(x: 700, y: 466))
NSColor(calibratedRed: 0.19, green: 0.48, blue: 0.72, alpha: 1).setStroke()
arrow.stroke()

context.flushGraphics()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
