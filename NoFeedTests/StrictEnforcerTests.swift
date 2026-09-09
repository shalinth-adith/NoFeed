//
//  StrictEnforcerTests.swift
//  NoFeedTests
//
//  Strictness has to survive a process boundary.
//
//  The block screen and the shield-action extension decide whether to offer a
//  timed pass, and both run outside the app with no access to its memory. Before
//  `ActivityShieldStore.isStrict`, the only thing they could ask was
//  `ActiveSessionInfo`, which describes an *in-app session* — so a strict
//  SCHEDULE that fired while the app was closed read as non-strict and was
//  offered a way out of a block that had promised there was none. A schedule only
//  becomes a session when `ScheduleAutoStart.run` converts it, and that runs in
//  the foreground.
//
//  These are on the store rather than on the extensions for the same reason
//  `ShortSessionShieldTests` is: the extensions are separate targets, and
//  `ManagedSettingsStore` does nothing outside a Screen Time-authorized device.
//  What is checkable — and what actually broke — is whether a live strict
//  enforcer reports itself as strict.
//

import Testing
import FamilyControls
import Foundation
@testable import NoFeed

@MainActor
struct StrictEnforcerTests {

    /// Swift Testing builds a fresh suite value per test and runs them in
    /// parallel over one shared App Group suite, so each test gets its own keys.
    private let activity = "test.strict.\(UUID().uuidString)"
    private let other = "test.other.\(UUID().uuidString)"

    private func clear() {
        ActivityShieldStore.remove(for: activity)
        ActivityShieldStore.remove(for: other)
    }

    /// Register a one-off the way `ScheduleCenter.startOneOff` does.
    private func register(_ name: String,
                          start: Date,
                          minutes: Int,
                          isStrict: Bool) {
        let calendar = Calendar.current
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))
        ActivityShieldStore.set(
            block: FamilyActivitySelection(),
            allow: FamilyActivitySelection(),
            blockAll: true,
            startMinutes: calendar.component(.hour, from: start) * 60
                + calendar.component(.minute, from: start),
            endMinutes: calendar.component(.hour, from: end) * 60
                + calendar.component(.minute, from: end),
            absoluteWindow: (start, end),
            isStrict: isStrict,
            for: name)
    }

    // MARK: - The flag survives the App Group

    @Test func aStrictEnforcerReportsItself() {
        clear(); defer { clear() }
        register(activity, start: Date(), minutes: 30, isStrict: true)
        #expect(ActivityShieldStore.isStrict(for: activity))
    }

    @Test func aNonStrictEnforcerDoesNot() {
        clear(); defer { clear() }
        register(activity, start: Date(), minutes: 30, isStrict: false)
        #expect(!ActivityShieldStore.isStrict(for: activity))
    }

    /// An entry written by a build predating the flag reads as non-strict. That
    /// is the honest answer rather than a guess: those builds never honoured
    /// strictness on the shield either.
    @Test func anUnknownActivityIsNotStrict() {
        #expect(!ActivityShieldStore.isStrict(for: "test.never.registered.\(UUID().uuidString)"))
    }

    // MARK: - What the block screen actually asks
    //
    // The regression: this is the question `ShieldTheme` and `grantPass` ask, and
    // the one that used to have no way of being answered for a schedule.

    @Test func aLiveStrictEnforcerIsSeen() {
        clear(); defer { clear() }
        register(activity, start: Date().addingTimeInterval(-60), minutes: 30, isStrict: true)
        #expect(ActivityShieldStore.anyActiveEnforcerIsStrict())
    }

    /// Strictness composes as a union, exactly like the blocks themselves: if any
    /// live enforcer promised no way out, offering one breaks that promise no
    /// matter what else is open beside it.
    @Test func oneStrictEnforcerAmongstSeveralIsEnough() {
        clear(); defer { clear() }
        register(other, start: Date().addingTimeInterval(-60), minutes: 30, isStrict: false)
        register(activity, start: Date().addingTimeInterval(-60), minutes: 30, isStrict: true)
        #expect(ActivityShieldStore.anyActiveEnforcerIsStrict())
    }

    @Test func onlyNonStrictEnforcersMeanTheDoorStaysOpen() {
        clear(); defer { clear() }
        register(activity, start: Date().addingTimeInterval(-60), minutes: 30, isStrict: false)
        register(other, start: Date().addingTimeInterval(-60), minutes: 30, isStrict: false)
        #expect(!ActivityShieldStore.anyActiveEnforcerIsStrict())
    }

    /// A strict enforcer whose window has closed must not keep suppressing the
    /// pass — otherwise one strict schedule would disable the feature for good.
    @Test func aFinishedStrictEnforcerStopsCounting() {
        clear(); defer { clear() }
        register(activity, start: Date().addingTimeInterval(-90 * 60), minutes: 30, isStrict: true)
        #expect(ActivityShieldStore.isStrict(for: activity))
        #expect(!ActivityShieldStore.anyActiveEnforcerIsStrict())
    }

    /// ...and one that has not begun yet does not either.
    @Test func aStrictEnforcerStillToComeDoesNotCount() {
        clear(); defer { clear() }
        register(activity, start: Date().addingTimeInterval(60 * 60), minutes: 30, isStrict: true)
        #expect(!ActivityShieldStore.anyActiveEnforcerIsStrict())
    }

    // MARK: - Cleanup

    @Test func removingAnActivityForgetsItsStrictness() {
        clear()
        register(activity, start: Date(), minutes: 30, isStrict: true)
        ActivityShieldStore.remove(for: activity)
        #expect(!ActivityShieldStore.isStrict(for: activity))
        #expect(!ActivityShieldStore.anyActiveEnforcerIsStrict())
    }
}
