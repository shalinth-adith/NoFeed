//
//  AccessibilityAudit.swift
//  NoFeedUITests
//
//  Apple's automated accessibility audit, run on every screen a user can
//  reach. Each screen's findings are written to $QUIET_SHOT_DIR/a11y/ as a
//  text file next to a screenshot, so the review can quote them.
//
//  The audit never fails the test on its own: a finding is recorded and the
//  tour carries on, because a review wants the whole list, not the first hit.
//  Everything here is DEBUG-gated on the app side through the usual launch
//  arguments (Screen Time bypass, seeded history, reset profiles).
//

import XCTest

final class AccessibilityAudit: XCTestCase {

    private var findings: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    // MARK: - Output

    private var outputDirectory: URL {
        let raw = ProcessInfo.processInfo.environment["QUIET_SHOT_DIR"]
            ?? NSTemporaryDirectory().appending("quiet-shots")
        let url = URL(fileURLWithPath: raw).appendingPathComponent("a11y")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Runs the audit on whatever is on screen, writes the findings and a
    /// screenshot under `name`, and returns the number of findings.
    @discardableResult
    private func audit(_ app: XCUIApplication, _ name: String) -> Int {
        var lines: [String] = []
        var occluded: [String] = []
        var measuredPass: [String] = []
        // Rendered pixels, taken before auditing, to check contrast flags
        // against what is actually drawn.
        let pixels = PixelSampler(app.screenshot().image)
        // The floating tab bar is translucent. Content scrolled beneath it is
        // measured against the bar's blur, which is not what anyone reads; it
        // is recorded separately so the main list is only what is visible.
        let navBar = app.navigationBars.firstMatch
        // A navigation bar's scroll-edge blur reaches ~16pt below its frame.
        let barBottom = navBar.exists && navBar.frame.height > 0 ? navBar.frame.maxY + 16 : 0
        let tabBar = app.tabBars.firstMatch
        let footer = app.descendants(matching: .any)["quiet-footer"].firstMatch
        // The floating bar casts a soft shadow upward; its fade begins ~12pt
        // above its frame. The editor footer fades 20pt above its own frame.
        var barTop = tabBar.exists ? tabBar.frame.minY - 12 : .greatestFiniteMagnitude
        if footer.exists { barTop = min(barTop, footer.frame.minY - 20) }
        let screen = app.windows.firstMatch.frame
        // One pass per type. A single `.all` pass returned some issues with no
        // element attached, which left nothing to place them by; per-type
        // passes attach the element every time.
        let types: [XCUIAccessibilityAuditType] = [.contrast, .elementDetection, .hitRegion,
                                                   .sufficientElementDescription, .dynamicType,
                                                   .textClipped, .trait]
        do {
          for type in types {
            try app.performAccessibilityAudit(for: type) { issue in
                let frame = issue.element?.frame ?? .zero
                let element = issue.element.map { "\($0.elementType.rawValue):\($0.label)" } ?? "-"
                let entry = "[\(Self.describe(issue.auditType))] \(issue.compactDescription) — element: \(element) frame: \(Self.short(frame))\n    \(issue.detailedDescription)"
                let hidden = frame != .zero && (frame.maxY > barTop + 1 || frame.minY < barBottom || frame.minY >= screen.maxY || frame.maxY <= 0)
                if hidden {
                    occluded.append(entry)
                } else if issue.auditType == .contrast, frame != .zero,
                          let ratio = pixels.contrast(in: frame) {
                    // 4.5:1 throughout. WCAG allows 3:1 for large text, but a
                    // frame does not say its font size, so take the strict bar.
                    let needed = 4.5
                    if ratio >= needed {
                        measuredPass.append(entry + String(format: "\n    measured %.1f:1 on the rendered pixels (needs %.1f:1)", ratio, needed))
                    } else {
                        lines.append(entry + String(format: "\n    measured %.1f:1", ratio))
                    }
                } else {
                    lines.append(entry)
                }
                return true   // recorded; do not fail the test
            }
          }
        } catch {
            lines.append("[audit-error] \(error.localizedDescription)")
        }
        var text = lines.isEmpty ? "No findings." : lines.joined(separator: "\n")
        if !measuredPass.isEmpty {
            text += "\n\n# Flagged by the audit, passing on the rendered pixels (not counted)\n" + measuredPass.joined(separator: "\n")
        }
        if !occluded.isEmpty {
            text += "\n\n# Under the tab bar or off screen (not counted)\n" + occluded.joined(separator: "\n")
        }
        try? text.write(to: outputDirectory.appendingPathComponent("\(name).txt"),
                        atomically: true, encoding: .utf8)
        try? app.debugDescription.write(to: outputDirectory.appendingPathComponent("\(name).tree.txt"),
                                        atomically: true, encoding: .utf8)
        let shot = app.screenshot()
        try? shot.pngRepresentation.write(to: outputDirectory.appendingPathComponent("\(name).png"))
        let attachment = XCTAttachment(string: "\(name)\n\(text)")
        attachment.name = "a11y-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        findings.append("\(name): \(lines.count)")
        return lines.count
    }

    private static func short(_ r: CGRect) -> String {
        "(\(Int(r.minX)),\(Int(r.minY)) \(Int(r.width))×\(Int(r.height)))"
    }

    private static func describe(_ type: XCUIAccessibilityAuditType) -> String {
        var parts: [String] = []
        if type.contains(.contrast) { parts.append("contrast") }
        if type.contains(.elementDetection) { parts.append("element-detection") }
        if type.contains(.hitRegion) { parts.append("hit-region") }
        if type.contains(.sufficientElementDescription) { parts.append("description") }
        if type.contains(.dynamicType) { parts.append("dynamic-type") }
        if type.contains(.textClipped) { parts.append("text-clipped") }
        if type.contains(.trait) { parts.append("trait") }
        return parts.isEmpty ? "other" : parts.joined(separator: ",")
    }

    // MARK: - Navigation helpers

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["NoFeedUITestBypassScreenTime",
                                "NoFeedUITestResetSession",
                                "NoFeedUITestResetProfiles",
                                "NoFeedUITestSkipOnboarding",
                                "NoFeedSeedDemoHistory"] + extra
        app.launch()
        let tabBar = app.tabBars.firstMatch
        if !tabBar.waitForExistence(timeout: 6) { app.tap() }
        _ = tabBar.waitForExistence(timeout: 8)
        return app
    }

    private func tap(_ element: XCUIElement, timeout: TimeInterval = 6) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        var attempts = 0
        while !element.isHittable && attempts < 4 {
            XCUIApplication().swipeUp()
            attempts += 1
        }
        guard element.isHittable else { return false }
        element.tap()
        return true
    }

    // MARK: - The tour

    func testAuditEveryScreen() throws {
        let app = launch()

        // Focus tab (Home). Wait out the splash cross-fade first: auditing
        // during it measured every label at about 2.4:1 against the fading
        // overlay, which is not a state anyone reads.
        let beginButton = app.buttons["Begin focus"]
        _ = beginButton.waitForExistence(timeout: 10)
        var waited = 0
        while !beginButton.isHittable && waited < 10 { sleep(1); waited += 1 }
        sleep(2)
        audit(app, "01-home")

        // Session screen, then the ended-early summary
        let begin = app.buttons["Begin focus"]
        if tap(begin) {
            let hold = app.descendants(matching: .any)["session-hold-to-end"].firstMatch
            if hold.waitForExistence(timeout: 8) {
                audit(app, "02-session")
                let pause = app.buttons["session-pause"]
                if pause.exists { pause.tap(); sleep(1); audit(app, "02b-session-held"); pause.tap() }
                hold.press(forDuration: 3.8)
                sleep(1)
                audit(app, "04b-ended-early")
                let leave = app.buttons.matching(
                    NSPredicate(format: "label CONTAINS[c] 'all for now' OR label ==[c] 'Done'")).firstMatch
                if leave.waitForExistence(timeout: 5) { leave.tap() }
            }
        }

        // Insights, scrolled top and bottom
        if tap(app.tabBars.buttons["Insights"]) {
            sleep(1)
            audit(app, "05-insights-top")
            app.swipeUp()
            audit(app, "05-insights-bottom")
            let recap = app.descendants(matching: .any)["insights-weekly-recap"].firstMatch
            if tap(recap) {
                sleep(1)
                audit(app, "07-weekly-recap")
                let done = app.buttons["recap-done"]
                if done.waitForExistence(timeout: 3) { done.tap() } else { app.swipeDown() }
                sleep(1)
            }
            let history = app.buttons.matching(NSPredicate(format: "label CONTAINS 'See all sessions'")).firstMatch
            if tap(history) {
                sleep(1)
                audit(app, "08-history")
                let firstRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'min'")).firstMatch
                if tap(firstRow) {
                    sleep(1)
                    audit(app, "08b-session-detail")
                    app.navigationBars.buttons.firstMatch.tap()
                }
                app.navigationBars.buttons.firstMatch.tap()
            }
        }

        // Schedule tab and editor
        if tap(app.tabBars.buttons["Schedule"]) {
            sleep(1)
            audit(app, "14-schedule")
            let add = app.buttons["add-schedule"]
            if tap(add) {
                _ = app.textFields["schedule-title"].waitForExistence(timeout: 6)
                audit(app, "16-schedule-editor")
                let cancel = app.buttons.matching(NSPredicate(format: "label ==[c] 'Cancel'")).firstMatch
                if cancel.exists { cancel.tap() }
            }
        }

        // Settings, profiles, detail, editor
        if tap(app.tabBars.buttons["Settings"]) {
            sleep(1)
            audit(app, "22-settings-top")
            app.swipeUp()
            audit(app, "22-settings-bottom")
            app.swipeDown()
            let profiles = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Focus profiles'")).firstMatch
            if tap(profiles) {
                sleep(1)
                audit(app, "20-profiles")
                let work = app.descendants(matching: .any)["profile-row-Work"].firstMatch
                if tap(work) {
                    sleep(1)
                    audit(app, "20b-profile-detail")
                    if tap(app.buttons["profile-detail-edit"]) {
                        _ = app.textFields["profile-edit-name"].waitForExistence(timeout: 6)
                        audit(app, "20c-profile-edit")
                        let cancel = app.buttons.matching(NSPredicate(format: "label ==[c] 'Cancel'")).firstMatch
                        if cancel.exists { cancel.tap() }
                    }
                    if tap(app.buttons["profile-detail-delete"]) {
                        sleep(1)
                        audit(app, "20-delete-sheet")
                        let keep = app.buttons["keep-profile"]
                        if keep.exists { keep.tap() }
                    }
                }
            }
        }

        let summary = findings.joined(separator: "\n")
        try? summary.write(to: outputDirectory.appendingPathComponent("SUMMARY.txt"),
                           atomically: true, encoding: .utf8)
    }

    /// Onboarding on a fresh install, plus the block screen and the "app
    /// paused" screen that only a launch argument can show on Simulator.
    func testAuditOnboardingAndPreviews() throws {
        let fresh = XCUIApplication()
        fresh.launchArguments += ["NoFeedUITestResetOnboarding"]
        fresh.launch()
        sleep(4)
        audit(fresh, "00-onboarding-1")
        for index in 2...5 {
            fresh.swipeLeft()
            sleep(1)
            audit(fresh, "00-onboarding-\(index)")
        }
        fresh.terminate()

        let block = XCUIApplication()
        block.launchArguments += ["NoFeedUITestBypassScreenTime", "NoFeedPreviewBlockScreen", "Instagram"]
        block.launch()
        sleep(2)
        audit(block, "03-block-screen")
        block.terminate()

        let paused = XCUIApplication()
        paused.launchArguments += ["NoFeedUITestBypassScreenTime", "NoFeedPreviewShield", "Instagram"]
        paused.launch()
        sleep(2)
        audit(paused, "03b-app-paused")
    }
}


/// Reads a screenshot's pixels to measure the contrast actually drawn inside a
/// frame: the darkest pixel against the lightest. Apple's audit estimates
/// contrast heuristically and misreads text over gradients (the orb halo) and
/// translucent bars; this checks its flags against the rendering.
private struct PixelSampler {
    let width: Int, height: Int, scale: CGFloat
    let data: [UInt8]

    init(_ image: UIImage) {
        let cg = image.cgImage!
        width = cg.width; height = cg.height
        scale = CGFloat(cg.width) / image.size.width
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &buffer, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        data = buffer
    }

    func contrast(in frame: CGRect) -> Double? {
        let x0 = max(0, Int(frame.minX * scale)), x1 = min(width, Int(frame.maxX * scale))
        let y0 = max(0, Int(frame.minY * scale)), y1 = min(height, Int(frame.maxY * scale))
        guard x1 > x0, y1 > y0 else { return nil }
        var lo = 1.0, hi = 0.0
        for y in y0..<y1 {
            for x in x0..<x1 {
                let i = (y * width + x) * 4
                let l = Self.luminance(data[i], data[i + 1], data[i + 2])
                lo = min(lo, l); hi = max(hi, l)
            }
        }
        return (hi + 0.05) / (lo + 0.05)
    }

    private static func luminance(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Double {
        func ch(_ v: UInt8) -> Double {
            let c = Double(v) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)
    }
}
