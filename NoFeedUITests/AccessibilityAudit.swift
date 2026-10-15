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
        do {
            try app.performAccessibilityAudit(for: .all) { issue in
                let element = issue.element.map { "\($0.elementType.rawValue):\($0.label)" } ?? "-"
                lines.append("[\(Self.describe(issue.auditType))] \(issue.compactDescription) — element: \(element)\n    \(issue.detailedDescription)")
                return true   // recorded; do not fail the test
            }
        } catch {
            lines.append("[audit-error] \(error.localizedDescription)")
        }
        let text = lines.isEmpty ? "No findings." : lines.joined(separator: "\n")
        try? text.write(to: outputDirectory.appendingPathComponent("\(name).txt"),
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
                                "NoFeedSeedDemoHistory"] + extra
        app.launch()
        let tabBar = app.tabBars.firstMatch
        if !tabBar.waitForExistence(timeout: 6) {
            app.tap()
            if !tabBar.waitForExistence(timeout: 4) {
                for label in ["Get Started", "Next", "Continue", "Maybe later", "Start Focusing"] {
                    let button = app.buttons[label]
                    if button.waitForExistence(timeout: 2) { button.tap() }
                }
            }
        }
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

        // Focus tab (Home)
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
                app.textFields["schedule-title"].typeText("\n")
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
                let work = app.staticTexts["Work"].firstMatch
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
