//
//  ReviewPromptTests.swift
//  NoFeedTests
//
//  The rating request must fire exactly once, on the third completed session,
//  and never again — not on the fourth, not after a relaunch. Each test gets
//  its own UserDefaults suite so nothing touches the App Group.
//

import Testing
import Foundation
@testable import NoFeed

struct ReviewPromptTests {

    private func freshDefaults() -> UserDefaults {
        let name = "ReviewPromptTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func firesOnlyOnTheThirdCompletedSession() {
        let defaults = freshDefaults()
        #expect(ReviewPrompt.recordCompletedSession(defaults: defaults) == false)
        #expect(ReviewPrompt.recordCompletedSession(defaults: defaults) == false)
        #expect(ReviewPrompt.recordCompletedSession(defaults: defaults) == true)
        #expect(ReviewPrompt.hasRequested(defaults: defaults))
    }

    @Test func neverFiresASecondTime() {
        let defaults = freshDefaults()
        for _ in 0..<3 { _ = ReviewPrompt.recordCompletedSession(defaults: defaults) }
        for _ in 0..<10 {
            #expect(ReviewPrompt.recordCompletedSession(defaults: defaults) == false)
        }
    }

    @Test func resetForgetsBothCountAndRequest() {
        let defaults = freshDefaults()
        for _ in 0..<3 { _ = ReviewPrompt.recordCompletedSession(defaults: defaults) }
        ReviewPrompt.reset(defaults: defaults)
        #expect(ReviewPrompt.hasRequested(defaults: defaults) == false)
        #expect(ReviewPrompt.recordCompletedSession(defaults: defaults) == false)
    }
}
