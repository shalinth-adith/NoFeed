//
//  ReviewPrompt.swift
//  NoFeed
//
//  Decides when to ask for an App Store rating: once, on the third completed
//  focus session. Three is the smallest number that proves the app did its job
//  more than once, and the completed summary is the one screen where the user
//  has just received something rather than been interrupted.
//
//  The decision is kept apart from the request itself so it can be tested
//  without StoreKit. `SessionSummaryView` calls `recordCompletedSession()` and
//  only then asks the system; the system applies its own rate limit on top.
//

import Foundation

enum ReviewPrompt {
    /// Completed sessions needed before the one and only request.
    static let sessionsBeforeRequest = 3

    private static let countKey = "reviewPromptCompletedSessions"
    private static let requestedKey = "reviewPromptRequested"

    /// Records one more completed session. Returns `true` exactly once in the
    /// life of the install: on the session that reaches the threshold.
    static func recordCompletedSession(defaults: UserDefaults = AppGroup.defaults) -> Bool {
        let count = defaults.integer(forKey: countKey) + 1
        defaults.set(count, forKey: countKey)

        guard count >= sessionsBeforeRequest,
              !defaults.bool(forKey: requestedKey) else { return false }

        defaults.set(true, forKey: requestedKey)
        return true
    }

    /// Whether the request has already been made on this install.
    static func hasRequested(defaults: UserDefaults = AppGroup.defaults) -> Bool {
        defaults.bool(forKey: requestedKey)
    }

    /// Forget both the count and the request. Only used by tests.
    static func reset(defaults: UserDefaults = AppGroup.defaults) {
        defaults.removeObject(forKey: countKey)
        defaults.removeObject(forKey: requestedKey)
    }
}
