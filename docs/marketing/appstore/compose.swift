// Composes the six App Store screenshots at 1320×2868, the 6.9" size App
// Store Connect requires (it scales them down for smaller iPhones).
//
// Each shot is a real Simulator capture from raw/ (see README.md for how each
// was made), set inside the same device frame the Reel uses, on the brand
// ground, with the caption above it. The last one is type only.
//
// Run from docs/marketing/appstore:  swift compose.swift
import AppKit

let W: CGFloat = 1320, H: CGFloat = 2868
let ground = NSColor(srgbRed: 0x07/255, green: 0x08/255, blue: 0x0A/255, alpha: 1)
let lift   = NSColor(srgbRed: 0x16/255, green: 0x1A/255, blue: 0x2A/255, alpha: 1)
let ink    = NSColor(srgbRed: 0xE7/255, green: 0xE8/255, blue: 0xEC/255, alpha: 1)
let quiet  = ink.withAlphaComponent(0.55)
let accent = NSColor(srgbRed: 0x7C/255, green: 0x93/255, blue: 0xE8/255, alpha: 1)   // Work periwinkle

enum Kind { case phone(String), doors, type }
struct Shot { let file: String; let kind: Kind; let caption: [String] }

// Slide 1 should show the most in a thumbnail. iOS's own app picker can't be
// captured on Simulator (no Screen Time, none of these apps installed), so by
// default it is the running session beside four real block screens. Capture the
// picker on a device with these apps selected, save it as raw/01-picker.png, and
// slide 1 uses that instead.
let doorApps = ["Instagram", "YouTube", "X", "TikTok"]
let firstKind: Kind = FileManager.default.fileExists(atPath: "raw/01-picker.png") ? .phone("01-picker.png") : .doors

let shots: [Shot] = [
  .init(file: "1-apps",      kind: firstKind,                 caption: ["Block the apps", "that eat your day"]),
  .init(file: "2-door",      kind: .phone("01-block.png"),    caption: ["A pause,", "not a lecture."]),
  .init(file: "3-holds",     kind: .phone("02-lock.png"),     caption: ["It holds.", "Even if you force-quit."]),
  .init(file: "4-profiles",  kind: .phone("03-profiles.png"), caption: ["One tap.", "Work, Study, Gym."]),
  .init(file: "5-schedule",  kind: .phone("04-schedule.png"), caption: ["Your mornings,", "protected automatically"]),
  .init(file: "6-streaks",   kind: .phone("05-history.png"),  caption: ["Streaks you earn.", "Progress you can see."]),
  .init(file: "7-privacy",   kind: .type,                     caption: ["No account.", "No tracking.", "Nothing leaves", "your phone."]),
]

// Device geometry: the screen keeps the capture's exact aspect.
let Sw: CGFloat = 900
let Sh = Sw * 2868 / 1320
let bezel: CGFloat = 22
let Ow = Sw + bezel * 2, Oh = Sh + bezel * 2
let Rs = Sw * 0.125, Ro = Rs + bezel
let phoneTop: CGFloat = 660

func flip(_ topY: CGFloat, _ h: CGFloat) -> CGFloat { H - topY - h }

func canvas(_ draw: () -> Void) -> NSBitmapImageRep {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  NSGraphicsContext.current?.imageInterpolation = .high
  draw()
  NSGraphicsContext.restoreGraphicsState()
  return rep
}

func drawGround(liftCentreY: CGFloat) {
  ground.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
  let g = NSGradient(colors: [lift, ground])!
  g.draw(fromCenter: NSPoint(x: W / 2, y: H - liftCentreY), radius: 0,
         toCenter: NSPoint(x: W / 2, y: H - liftCentreY), radius: 1100, options: [])
}

/// Lines centred from `top`, shrinking the size until the widest fits `maxWidth`.
@discardableResult
func drawLines(_ lines: [String], top: CGFloat, size: CGFloat, weight: NSFont.Weight,
               colors: [NSColor], maxWidth: CGFloat = 1140, leading: CGFloat = 1.12) -> CGFloat {
  var size = size
  func attrs(_ i: Int) -> [NSAttributedString.Key: Any] {
    [.font: NSFont.systemFont(ofSize: size, weight: weight),
     .foregroundColor: colors[min(i, colors.count - 1)], .kern: -size * 0.012]
  }
  while lines.enumerated().map({ NSAttributedString(string: $1, attributes: attrs($0)).size().width }).max()! > maxWidth {
    size -= 2
  }
  var y = top
  for (i, line) in lines.enumerated() {
    let s = NSAttributedString(string: line, attributes: attrs(i))
    let sz = s.size()
    s.draw(at: NSPoint(x: (W - sz.width) / 2, y: flip(y, sz.height)))
    y += size * leading
  }
  return y
}

func drawPhone(_ screenshot: NSImage, scale k: CGFloat = 1, left: CGFloat? = nil) {
  let ow = Ow * k, oh = Oh * k, b = bezel * k, rs = Rs * k, ro = Ro * k
  let outer = NSRect(x: left ?? (W - ow) / 2, y: flip(phoneTop, oh), width: ow, height: oh)
  let screen = outer.insetBy(dx: b, dy: b)
  let (Ro, Rs) = (ro, rs)

  NSGraphicsContext.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.7)
  shadow.shadowBlurRadius = 80; shadow.shadowOffset = NSSize(width: 0, height: -30)
  shadow.set()
  NSColor(srgbRed: 0x1B/255, green: 0x1D/255, blue: 0x22/255, alpha: 1).setFill()
  NSBezierPath(roundedRect: outer, xRadius: Ro, yRadius: Ro).fill()
  NSGraphicsContext.restoreGraphicsState()

  // A hairline on the bezel edge, so the body separates from the ground.
  NSColor.white.withAlphaComponent(0.10).setStroke()
  let edge = NSBezierPath(roundedRect: outer.insetBy(dx: 1, dy: 1), xRadius: Ro - 1, yRadius: Ro - 1)
  edge.lineWidth = 2; edge.stroke()

  NSGraphicsContext.saveGraphicsState()
  NSBezierPath(roundedRect: screen, xRadius: Rs, yRadius: Rs).addClip()
  screenshot.draw(in: screen, from: .zero, operation: .copy, fraction: 1)
  NSGraphicsContext.restoreGraphicsState()
}

let fm = FileManager.default
try? fm.createDirectory(atPath: "final", withIntermediateDirectories: true)

/// The title block of a real block-screen capture: the first run of
/// near-white rows below the status bar, which is "<App> is behind this door."
func doorTitle(_ app: String) -> CGImage {
  guard let image = NSImage(contentsOfFile: "raw/01-door-\(app).png"),
        let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { fatalError("missing raw/01-door-\(app).png") }
  let w = cg.width, h = cg.height
  let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
  let px = ctx.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)
  // CGContext memory is top-down here: row 0 is the top of the image.
  var top = -1, bottom = -1, minX = w, maxX = 0, gap = 0
  for y in 300..<(h - 400) {
    var bright = false
    for x in stride(from: 0, to: w, by: 2) where px[(y * w + x) * 4] > 200 {
      bright = true; minX = min(minX, x); maxX = max(maxX, x)
    }
    if bright { if top < 0 { top = y }; bottom = y; gap = 0 }
    else if top >= 0 { gap += 1; if gap > 150 { break } }   // the subtitle below is grey, so only the title is bright
  }
  let pad = 24
  return cg.cropping(to: CGRect(x: minX - pad, y: top - pad, width: maxX - minX + pad * 2, height: bottom - top + pad * 2))!
}

func drawDoorCard(_ title: CGImage, x: CGFloat, top: CGFloat, width: CGFloat) {
  // One scale for every card, so the four titles read at the same size.
  let s: CGFloat = 0.82
  let tw = CGFloat(title.width) * s, th = CGFloat(title.height) * s
  _ = width
  let card = NSRect(x: x, y: flip(top, th + 76), width: width, height: th + 76)
  NSGraphicsContext.saveGraphicsState()
  let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.8)
  shadow.shadowBlurRadius = 50; shadow.shadowOffset = NSSize(width: 0, height: -18); shadow.set()
  NSColor.black.setFill(); NSBezierPath(roundedRect: card, xRadius: 44, yRadius: 44).fill()
  NSGraphicsContext.restoreGraphicsState()
  NSColor.white.withAlphaComponent(0.12).setStroke()
  let edge = NSBezierPath(roundedRect: card.insetBy(dx: 1, dy: 1), xRadius: 43, yRadius: 43); edge.lineWidth = 2; edge.stroke()
  NSGraphicsContext.current?.cgContext.draw(title, in: CGRect(x: card.midX - tw / 2, y: card.midY - th / 2, width: tw, height: th))
}

for shot in shots {
  let rep = canvas {
    switch shot.kind {
    case .phone(let raw):
      drawGround(liftCentreY: phoneTop + Oh / 2)
      drawLines(shot.caption, top: 200, size: 104, weight: .semibold, colors: [ink, quiet])
      guard let image = NSImage(contentsOfFile: "raw/\(raw)") else { fatalError("missing raw/\(raw)") }
      drawPhone(image)
    case .doors:
      // The running session, with what it is holding back fanned out beside it.
      drawGround(liftCentreY: phoneTop + Oh / 2)
      drawLines(shot.caption, top: 200, size: 104, weight: .semibold, colors: [ink, quiet])
      guard let session = NSImage(contentsOfFile: "raw/01-session.png") else { fatalError("missing raw/01-session.png") }
      drawPhone(session, scale: 0.72, left: 60)
      var top: CGFloat = 820
      for (i, app) in doorApps.enumerated() {
        drawDoorCard(doorTitle(app), x: 560 + CGFloat(i % 2) * 40, top: top, width: 660)
        top += 330
      }
    case .type:
      // Type only. The app icon, then the promise in four short lines.
      drawGround(liftCentreY: H * 0.45)
      if let icon = NSImage(contentsOfFile: "../reel/captions/icon-rounded.png") {
        let s: CGFloat = 240
        icon.draw(in: NSRect(x: (W - s) / 2, y: flip(760, s), width: s, height: s))
      }
      let end = drawLines(shot.caption, top: 1150, size: 124, weight: .semibold,
                          colors: [ink, ink, accent, accent], leading: 1.14)
      drawLines(["Free. No subscription. Ever."], top: end + 90, size: 52, weight: .regular,
                colors: [quiet])
    }
  }
  let path = "final/\(shot.file).png"
  // App Store Connect rejects screenshots with an alpha channel. Flatten
  // through a context that has none, so the PNG is written as plain RGB.
  let cs = CGColorSpace(name: CGColorSpace.sRGB)!
  let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                      space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  ctx.draw(rep.cgImage!, in: CGRect(x: 0, y: 0, width: W, height: H))
  let opaque = NSBitmapImageRep(cgImage: ctx.makeImage()!)
  try! opaque.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
  print("  \(path)  \(opaque.pixelsWide)x\(opaque.pixelsHigh)")
}
