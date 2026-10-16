//
//  LocalizedScreenshots.swift
//  NoFeedUITests
//
//  Screenshots of the main screens in one language, for checking that
//  translated copy fits. Navigates by tab position and accessibility ids, never
//  by label, so it works in any language. Skipped unless a language is given:
//
//      TEST_RUNNER_LOC_SHOT_LANG=de TEST_RUNNER_QUIET_SHOT_DIR=/tmp/shots \
//        xcodebuild test ... -only-testing:NoFeedUITests/LocalizedScreenshots
//

import XCTest

final class LocalizedScreenshots: XCTestCase {

    private var language: String? { ProcessInfo.processInfo.environment["LOC_SHOT_LANG"] }

    private var outputDirectory: URL {
        let raw = ProcessInfo.processInfo.environment["QUIET_SHOT_DIR"]
            ?? NSTemporaryDirectory().appending("quiet-shots")
        let url = URL(fileURLWithPath: raw).appendingPathComponent("loc-\(language ?? "none")")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let png = app.screenshot().pngRepresentation
        try? png.write(to: outputDirectory.appendingPathComponent("\(name).png"))
        // The element tree too, so untranslated labels can be found by script.
        try? app.debugDescription.write(to: outputDirectory.appendingPathComponent("\(name).txt"),
                                        atomically: true, encoding: .utf8)
    }

    private func launch(_ language: String, _ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", language] + extra
        app.launch()
        return app
    }

    /// The run creates default profiles named in its language, and other suites
    /// read the simulator's profiles without resetting them. Put English back.
    override func tearDownWithError() throws {
        guard language != nil else { return }
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                                "NoFeedUITestBypassScreenTime", "NoFeedUITestResetSession",
                                "NoFeedUITestResetProfiles", "NoFeedUITestSkipOnboarding"]
        app.launch()
        _ = app.tabBars.firstMatch.waitForExistence(timeout: 10)
        app.terminate()
    }

    func testMainScreens() throws {
        guard let language else { throw XCTSkip("Set TEST_RUNNER_LOC_SHOT_LANG to a language code.") }

        let fresh = launch(language, ["NoFeedUITestResetOnboarding"])
        sleep(4)
        shot(fresh, "00-onboarding-1")
        for index in 2...5 {
            fresh.swipeLeft(); sleep(1)
            shot(fresh, "00-onboarding-\(index)")
        }
        fresh.terminate()

        let app = launch(language, ["NoFeedUITestBypassScreenTime", "NoFeedUITestResetSession",
                                    "NoFeedUITestResetProfiles", "NoFeedUITestSkipOnboarding",
                                    "NoFeedSeedDemoHistory"])
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 10))
        sleep(4)
        shot(app, "01-home")

        // Session, held, then the ended-early summary.
        let hold = app.descendants(matching: .any)["session-hold-to-end"].firstMatch
        let begin = app.buttons["home-begin"].exists ? app.buttons["home-begin"]
                  : app.buttons.matching(NSPredicate(format: "identifier == 'home-begin'")).firstMatch
        if begin.exists { begin.tap() } else { tapBeginByPosition(app) }
        if hold.waitForExistence(timeout: 8) {
            shot(app, "02-session")
            let pause = app.buttons["session-pause"]
            if pause.exists { pause.tap(); sleep(1); shot(app, "02b-session-held"); pause.tap() }
            hold.press(forDuration: 3.8); sleep(2)
            shot(app, "04b-ended-early")
            app.terminate()
        }

        let again = launch(language, ["NoFeedUITestBypassScreenTime", "NoFeedUITestResetSession",
                                      "NoFeedUITestSkipOnboarding", "NoFeedSeedDemoHistory"])
        let bar = again.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 10))
        sleep(3)
        let names = ["insights", "schedule", "settings"]
        for (offset, name) in names.enumerated() {
            let button = bar.buttons.element(boundBy: offset + 1)
            guard button.exists else { continue }
            button.tap(); sleep(2)
            shot(again, "1\(offset)-\(name)-top")
            again.swipeUp(); sleep(1)
            shot(again, "1\(offset)-\(name)-bottom")
            again.swipeDown(); again.swipeDown(); sleep(1)
            if name == "insights" {
                let recap = again.descendants(matching: .any)["insights-weekly-recap"].firstMatch
                again.swipeUp()
                if recap.exists && recap.isHittable {
                    recap.tap(); sleep(2); shot(again, "10b-weekly-recap")
                    let done = again.buttons["recap-done"]
                    if done.exists { done.tap() } else { again.swipeDown() }
                    sleep(1)
                }
            }
            if name == "schedule" {
                let add = again.buttons["add-schedule"]
                if add.exists && add.isHittable {
                    add.tap(); sleep(2); shot(again, "11b-schedule-editor")
                    again.swipeDown(); sleep(1)
                }
            }
        }
    }

    /// The Begin button sits below the orb; if it has no id, tap the lowest
    /// large button above the tab bar.
    private func tapBeginByPosition(_ app: XCUIApplication) {
        let candidates = app.buttons.allElementsBoundByIndex.filter { $0.isHittable && $0.frame.width > 200 }
        candidates.max(by: { $0.frame.minY < $1.frame.minY })?.tap()
    }
}
