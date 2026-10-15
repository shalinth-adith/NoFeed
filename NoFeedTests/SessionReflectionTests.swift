//
//  SessionReflectionTests.swift
//  NoFeedTests
//
//  Two things that must not drift: the mapping from the retired 1–5 dots, and
//  the inbox that parks a Lock Screen answer until its session is recorded.
//

import Testing
import Foundation
@testable import NoFeed

struct SessionReflectionTests {

    @Test func legacyRatingsKeepTheirMeaning() {
        #expect(SessionReflection.fromLegacyRating(0) == .none)
        #expect(SessionReflection.fromLegacyRating(1) == .distracted)
        #expect(SessionReflection.fromLegacyRating(2) == .distracted)
        #expect(SessionReflection.fromLegacyRating(3) == .interrupted)
        #expect(SessionReflection.fromLegacyRating(4) == .focused)
        #expect(SessionReflection.fromLegacyRating(5) == .focused)
        #expect(SessionReflection.fromLegacyRating(9) == .none)
    }

    @Test func rawValuesAreStable() {
        #expect(SessionReflection.focused.rawValue == 1)
        #expect(SessionReflection.distracted.rawValue == 2)
        #expect(SessionReflection.interrupted.rawValue == 3)
    }

    private func freshDefaults() -> UserDefaults {
        let name = "SessionReflectionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func inboxHandsTheAnswerToItsOwnSession() {
        let defaults = freshDefaults()
        let started = Date(timeIntervalSince1970: 1_800_000_000)
        ReflectionInbox.store(.distracted, startedAt: started, defaults: defaults)

        #expect(ReflectionInbox.take(for: started.addingTimeInterval(0.4), defaults: defaults) == .distracted)
        #expect(ReflectionInbox.peek(defaults: defaults) == nil, "taking clears it")
    }

    @Test func inboxRefusesAnotherSession() {
        let defaults = freshDefaults()
        let started = Date(timeIntervalSince1970: 1_800_000_000)
        ReflectionInbox.store(.focused, startedAt: started, defaults: defaults)

        #expect(ReflectionInbox.take(for: started.addingTimeInterval(90), defaults: defaults) == nil)
        #expect(ReflectionInbox.peek(defaults: defaults)?.reflection == .focused, "still waiting for its own session")
    }

    @Test func inboxIgnoresNone() {
        let defaults = freshDefaults()
        ReflectionInbox.store(.none, startedAt: Date(), defaults: defaults)
        #expect(ReflectionInbox.peek(defaults: defaults) == nil)
    }
}
