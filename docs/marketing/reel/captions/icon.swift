// The App Store icon asset is square; iOS rounds it at draw time. For the end
// card we need the rounded version as a real alpha PNG, so clip it here with
// the continuous-corner ratio iOS uses (~22.37% of the side).
import AppKit
let src = NSImage(contentsOfFile: "../../../NoFeed/Assets.xcassets/AppIcon.appiconset/AppIcon.png")!
let S: CGFloat = 440, R = S * 0.2237
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.clear.setFill(); NSRect(x: 0, y: 0, width: S, height: S).fill()
NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: S, height: S), xRadius: R, yRadius: R).addClip()
src.draw(in: NSRect(x: 0, y: 0, width: S, height: S), from: .zero, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "captions/icon-rounded.png"))
print("  icon-rounded.png \(Int(S))x\(Int(S)) r=\(Int(R))")
