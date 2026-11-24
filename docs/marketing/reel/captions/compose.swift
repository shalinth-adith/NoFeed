// Composes the designed frames for the Reel in AppKit, where shadows, rounded
// corners and gradients are first-class — ffmpeg then only adds motion, fades and
// assembly. Everything is drawn at 1080×1920 (the final frame) so nothing is
// resampled twice.
//
//   captions/*.png       captions, no pill, soft shadow (legible on light and dark)
//   frames/lock.png      the Lock Screen Live Activity card, floating
//   frames/island.png    the Dynamic Island strip, floating
//   frames/ground.png    the end-card ground with a radial lift
//
// Run from docs/marketing/reel:  swift captions/compose.swift
import AppKit

let W: CGFloat = 1080, H: CGFloat = 1920
let ground = NSColor(srgbRed: 0x07/255, green: 0x08/255, blue: 0x0A/255, alpha: 1)
let ink = NSColor(srgbRed: 0xE7/255, green: 0xE8/255, blue: 0xEC/255, alpha: 1)

func bitmap(_ w: CGFloat, _ h: CGFloat, _ draw: () -> Void) -> NSBitmapImageRep {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(w), pixelsHigh: Int(h), bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  NSColor.clear.setFill(); NSRect(x: 0, y: 0, width: w, height: h).fill()
  draw()
  NSGraphicsContext.restoreGraphicsState()
  return rep
}
func save(_ rep: NSBitmapImageRep, _ path: String) {
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
  print("  \(path)  \(rep.pixelsWide)x\(rep.pixelsHigh)")
}
/// AppKit's origin is bottom-left; the video's is top-left. Convert a top-down y.
func flip(_ topY: CGFloat, _ height: CGFloat, in canvasH: CGFloat) -> CGFloat { canvasH - topY - height }

// MARK: - Captions (no pill: type with a soft shadow reads as editorial, a pill reads as a meme)

struct Caption { let file: String; let text: String; let size: CGFloat; let weight: NSFont.Weight; let alpha: CGFloat; let tracking: CGFloat; var dark = false }
let captions: [Caption] = [
  .init(file: "c-holds",  text: "It holds.",                  size: 62,  weight: .semibold, alpha: 1,    tracking: -0.5),
  .init(file: "c-lock",   text: "Even on your Lock Screen.",  size: 54,  weight: .medium,   alpha: 1,    tracking: -0.3),
  .init(file: "c-island", text: "Always in sight.",           size: 54,  weight: .medium,   alpha: 1,    tracking: -0.3),
  .init(file: "c-sticks", text: "It sticks.",                 size: 62,  weight: .semibold, alpha: 1,    tracking: -0.5),
  .init(file: "e-name",   text: "NoFeed",                     size: 108, weight: .semibold, alpha: 1,    tracking: -1.5),
  .init(file: "e-store",  text: "Free on the App Store.",     size: 44,  weight: .regular,  alpha: 0.62, tracking: 0.2),
]
for c in captions {
  let font = NSFont.systemFont(ofSize: c.size, weight: c.weight)
  // Type follows the surface it sits on, the way the app's own does: light ink
  // with a dark shadow over dark screens; the app's light-mode ink (#16171B)
  // with a faint light halo over the Insights surface, where white washes out.
  let darkInk = NSColor(srgbRed: 0x16/255, green: 0x17/255, blue: 0x1B/255, alpha: 1)
  let shadow = NSShadow()
  shadow.shadowColor = c.dark ? NSColor.white.withAlphaComponent(0.55) : NSColor.black.withAlphaComponent(0.55)
  shadow.shadowBlurRadius = c.dark ? 14 : 22; shadow.shadowOffset = NSSize(width: 0, height: c.dark ? 0 : -4)
  let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: (c.dark ? darkInk : ink).withAlphaComponent(c.alpha),
                                              .kern: c.tracking, .shadow: shadow]
  let str = NSAttributedString(string: c.text, attributes: attrs)
  let size = str.size(); let pad: CGFloat = 48   // room for the shadow
  let h = ceil(size.height + pad * 2)
  let rep = bitmap(W, h) { str.draw(at: NSPoint(x: (W - size.width) / 2, y: pad)) }
  save(rep, "captions/\(c.file).png")
}

// MARK: - Floating cards cut from captures

/// Draw `src` cropped to `crop` (in source pixels, top-down) as a rounded card of
/// width `cardW` at top-left (x, topY) on a transparent 1080×1920 canvas, with a
/// deep soft shadow underneath so it sits *on* the ground rather than being
/// pasted onto it.
func floatingCard(src: NSImage, crop: NSRect, cardW: CGFloat, topY: CGFloat, radius: CGFloat) -> NSBitmapImageRep {
  let scale = cardW / crop.width
  let cardH = round(crop.height * scale)
  let x = (W - cardW) / 2
  let rect = NSRect(x: x, y: flip(topY, cardH, in: H), width: cardW, height: cardH)
  return bitmap(W, H) {
    // Shadow: drawn as a filled rounded rect with NSShadow, then the card over it.
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = NSColor.black.withAlphaComponent(0.65)
    sh.shadowBlurRadius = 60; sh.shadowOffset = NSSize(width: 0, height: -28); sh.set()
    NSColor.black.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
    // NSImage.draw(in:from:) takes `from` in the image's bottom-left coordinates.
    let srcH = src.size.height
    let from = NSRect(x: crop.minX, y: srcH - crop.maxY, width: crop.width, height: crop.height)
    src.draw(in: rect, from: from, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    // A hairline of light on the top edge, the way glass catches it.
    NSColor.white.withAlphaComponent(0.10).setStroke()
    let p = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
    p.lineWidth = 1; p.stroke()
  }
}

try? FileManager.default.createDirectory(atPath: "frames", withIntermediateDirectories: true)

// Lock Screen: the Live Activity card and a little wallpaper around it (source
// rows 1560–2300 on a 1206×2622 capture), set at y=470 so its centre sits in the
// middle of the safe band with the caption clear beneath.
let lock = NSImage(contentsOfFile: "shots/02d-lock-screen.png")!
save(floatingCard(src: lock, crop: NSRect(x: 0, y: 1560, width: 1206, height: 740), cardW: 1000, topY: 470, radius: 44),
     "frames/lock.png")

// Dynamic Island: the top of the Home Screen above the first icon row.
let island = NSImage(contentsOfFile: "shots/02c-dynamic-island.png")!
save(floatingCard(src: island, crop: NSRect(x: 0, y: 0, width: 1206, height: 230), cardW: 1000, topY: 760, radius: 36),
     "frames/island.png")

// End-card ground: the share card's radial lift behind where the icon will sit.
save(bitmap(W, H) {
  ground.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
  let lift = NSColor(srgbRed: 0x12/255, green: 0x15/255, blue: 0x1F/255, alpha: 1)
  let g = NSGradient(colors: [lift, ground])!
  g.draw(fromCenter: NSPoint(x: W / 2, y: flip(620, 0, in: H)), radius: 0,
         toCenter: NSPoint(x: W / 2, y: flip(620, 0, in: H)), radius: 620, options: [])
}, "frames/ground.png")
