// Renders each caption to a transparent PNG with the pill baked in, at 1080px
// wide, using SF Pro at a real semibold — ffmpeg here has no drawtext, and
// this gives better type than drawtext could anyway.
import AppKit

struct Caption { let file: String; let text: String; let size: CGFloat; let weight: NSFont.Weight; let alpha: CGFloat; let pill: Bool }
let ink = NSColor(srgbRed: 0xE7/255, green: 0xE8/255, blue: 0xEC/255, alpha: 1)
let items: [Caption] = [
  .init(file: "c-holds",   text: "It holds.",                             size: 60, weight: .semibold, alpha: 1,    pill: true),
  .init(file: "c-lock",    text: "Even on your Lock Screen.",             size: 56, weight: .semibold, alpha: 1,    pill: true),
  .init(file: "c-island",  text: "Counting down where you can see it.",   size: 52, weight: .semibold, alpha: 1,    pill: true),
  .init(file: "c-sticks",  text: "It sticks.",                            size: 60, weight: .semibold, alpha: 1,    pill: true),
  .init(file: "e-name",    text: "NoFeed",                                size: 104, weight: .semibold, alpha: 1,   pill: false),
  .init(file: "e-store",   text: "Free on the App Store.",                size: 46, weight: .regular,  alpha: 0.62, pill: false),
]
let canvasW: CGFloat = 1080
for c in items {
  let font = NSFont.systemFont(ofSize: c.size, weight: c.weight)
  let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink.withAlphaComponent(c.alpha)]
  let str = NSAttributedString(string: c.text, attributes: attrs)
  let textSize = str.size()
  let padX: CGFloat = c.pill ? 34 : 0, padY: CGFloat = c.pill ? 22 : 0
  let h = ceil(textSize.height + padY * 2)
  let img = NSImage(size: NSSize(width: canvasW, height: h))
  img.lockFocus()
  NSColor.clear.setFill(); NSRect(x: 0, y: 0, width: canvasW, height: h).fill()
  let pillW = ceil(textSize.width + padX * 2)
  let pillRect = NSRect(x: (canvasW - pillW) / 2, y: 0, width: pillW, height: h)
  if c.pill {
    NSColor.black.withAlphaComponent(0.55).setFill()
    NSBezierPath(roundedRect: pillRect, xRadius: h / 2, yRadius: h / 2).fill()
  }
  str.draw(at: NSPoint(x: (canvasW - textSize.width) / 2, y: padY))
  img.unlockFocus()
  // Rasterise at 1x (points == pixels here) to PNG.
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvasW), pixelsHigh: Int(h), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  img.draw(in: NSRect(x: 0, y: 0, width: canvasW, height: h))
  NSGraphicsContext.restoreGraphicsState()
  let png = rep.representation(using: .png, properties: [:])!
  try! png.write(to: URL(fileURLWithPath: "captions/\(c.file).png"))
  print("  \(c.file).png  \(Int(canvasW))x\(Int(h))")
}
