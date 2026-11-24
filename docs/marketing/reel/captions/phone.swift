// Renders each app screen INSIDE an iPhone, on the brand ground, at the final
// 1080×1920. The phone geometry is identical in every frame, so when build.sh
// dissolves between them the device stays locked and only the screen changes —
// the "real hardware" read that a full-bleed rectangle can't give.
//
// The Simulator screenshots are 1206×2622 and already include the status bar and
// the Dynamic Island pill, so the frame only adds body, bezel, rounded screen,
// a drop shadow, a soft radial lift behind it, and a faint diagonal glass glare.
//
// Run from docs/marketing/reel:  swift captions/phone.swift
import AppKit

let W: CGFloat = 1080, H: CGFloat = 1920
let ground = NSColor(srgbRed: 0x07/255, green: 0x08/255, blue: 0x0A/255, alpha: 1)
let lift   = NSColor(srgbRed: 0x14/255, green: 0x17/255, blue: 0x22/255, alpha: 1)

// Phone geometry. Screen matches the 1206×2622 capture aspect exactly.
// Sized to fill the frame: the whole device visible, top-to-bottom, with only a
// thin margin of ground on every side. The phone IS the shot — no caption band
// below it (there is no room, and the app's own screens carry the words). The
// aspect (2.174) is taller than 9:16, so height is the constraint and the side
// margins fall out of it.
let Sw: CGFloat = 845
let Sh = Sw * 2622 / 1206            // ≈1837
let bezel: CGFloat = 16
let Ow = Sw + bezel*2, Oh = Sh + bezel*2   // ≈877 × 1869
let Rs = Sw * 0.125                   // screen corner
let Ro = Rs + bezel                   // outer corner
let cx = W/2
let phoneTop: CGFloat = (H - Oh) / 2  // centred vertically; ≈25px top/bottom gap
let screenTopY = phoneTop + bezel     // top-down y of the screen's top edge

func flip(_ topY: CGFloat, _ h: CGFloat) -> CGFloat { H - topY - h }
let outer  = NSRect(x: cx - Ow/2, y: flip(phoneTop, Oh), width: Ow, height: Oh)
let screen = NSRect(x: cx - Sw/2, y: flip(screenTopY, Sh), width: Sw, height: Sh)

func bitmap(_ draw: () -> Void) -> NSBitmapImageRep {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  draw()
  NSGraphicsContext.restoreGraphicsState()
  return rep
}

func phoneFrame(_ shotPath: String) -> NSBitmapImageRep {
  let shot = NSImage(contentsOfFile: shotPath)!
  return bitmap {
    // Ground + a radial lift behind the device so it is not floating on flat black.
    ground.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
    let g = NSGradient(colors: [lift, ground])!
    g.draw(fromCenter: NSPoint(x: cx, y: flip(H/2, 0)), radius: 0,
           toCenter: NSPoint(x: cx, y: flip(H/2, 0)), radius: 820, options: [])

    // Drop shadow, then the black body.
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = NSColor.black.withAlphaComponent(0.75)
    sh.shadowBlurRadius = 90; sh.shadowOffset = NSSize(width: 0, height: -30); sh.set()
    NSColor(white: 0.02, alpha: 1).setFill()
    NSBezierPath(roundedRect: outer, xRadius: Ro, yRadius: Ro).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Screen.
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: screen, xRadius: Rs, yRadius: Rs).addClip()
    shot.draw(in: screen, from: NSRect(x: 0, y: 0, width: shot.size.width, height: shot.size.height),
              operation: .sourceOver, fraction: 1)
    // Faint diagonal glass glare, top-left to mid — the sheen a real screen has.
    let glare = NSGradient(colors: [NSColor.white.withAlphaComponent(0.10), NSColor.white.withAlphaComponent(0.0)])!
    glare.draw(from: NSPoint(x: screen.minX, y: screen.maxY), to: NSPoint(x: screen.midX, y: screen.midY),
               options: [])
    NSGraphicsContext.restoreGraphicsState()

    // Bezel inner + outer hairlines: a bright edge where glass meets metal, a
    // darker one at the metal's rim. This is what stops the phone reading flat.
    NSColor.white.withAlphaComponent(0.10).setStroke()
    let inner = NSBezierPath(roundedRect: screen.insetBy(dx: -1, dy: -1), xRadius: Rs+1, yRadius: Rs+1)
    inner.lineWidth = 2; inner.stroke()
    NSColor.white.withAlphaComponent(0.06).setStroke()
    let rim = NSBezierPath(roundedRect: outer.insetBy(dx: 0.5, dy: 0.5), xRadius: Ro, yRadius: Ro)
    rim.lineWidth = 1; rim.stroke()
  }
}

func save(_ rep: NSBitmapImageRep, _ path: String) {
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
  print("  \(path)")
}

try? FileManager.default.createDirectory(atPath: "frames", withIntermediateDirectories: true)
let shots = ["focus":"01-focus", "session":"02b-session", "door":"02-block-screen", "lock":"02d-lock-screen",
             "island":"02c-dynamic-island", "insights":"03-insights", "recap":"03b-recap"]
for (name, file) in shots.sorted(by: { $0.key < $1.key }) {
  save(phoneFrame("shots/\(file).png"), "frames/p-\(name).png")
}

// Report where the screen sits, so build.sh can drop captions into each screen's
// dead space in composition coordinates.
print("SCREEN topY=\(Int(screenTopY)) botY=\(Int(screenTopY+Sh)) x=\(Int(screen.minX))..\(Int(screen.maxX))")
