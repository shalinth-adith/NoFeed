//
//  MindfulPauseTests.swift
//  NoFeedTests
//
//  "Pause, don't block" lives across three processes: the app records which
//  enforcers pause, the shield draws the wait, and the shield-action extension
//  grants the pass. The extensions only run on a device, so these check the
//  parts every one of them asks: the clock-driven stages, the per-profile
//  setting, and how enforcers compose into the door the block screen offers.
//
//  Enforcers are registered in 2100 and asked about at that instant, so the
//  live entries other suites write in parallel are never "active" here.
//

import Testing
import FamilyControls
import Foundation
@testable import NoFeed

@MainActor
@Suite(.serialized)
struct MindfulPauseTests {

    private let a = "test.mindful.a.\(UUID().uuidString)"
    private let b = "test.mindful.b.\(UUID().uuidString)"
    private let future = Date(timeIntervalSince1970: 4_102_444_800 + 3_600) // 2100-01-01 01:00 UTC

    private func clear() {
        ActivityShieldStore.remove(for: a)
        ActivityShieldStore.remove(for: b)
        MindfulPause.reset()
    }

    private func register(_ name: String, strict: Bool = false, mindful: Bool) {
        ActivityShieldStore.set(block: FamilyActivitySelection(),
                                allow: FamilyActivitySelection(),
                                blockAll: true,
                                absoluteWindow: (future.addingTimeInterval(-600), future.addingTimeInterval(600)),
                                isStrict: strict,
                                isMindful: mindful,
                                for: name)
    }

    // MARK: - The wait is a function of the clock

    @Test func theWaitRunsTenSecondsThenOffersThePass() {
        clear(); defer { clear() }
        let start = Date()
        #expect(MindfulPause.stage(now: start) == .idle)

        MindfulPause.begin(now: start)
        #expect(MindfulPause.stage(now: start) == .waiting(secondsLeft: 10))
        #expect(MindfulPause.stage(now: start.addingTimeInterval(3.2)) == .waiting(secondsLeft: 7))
        // The last partial second still reads as one, never zero.
        #expect(MindfulPause.stage(now: start.addingTimeInterval(9.9)) == .waiting(secondsLeft: 1))
        #expect(MindfulPause.stage(now: start.addingTimeInterval(10)) == .ready)
    }

    @Test func tappingAgainDoesNotRestartTheCount() {
        clear(); defer { clear() }
        let start = Date()
        MindfulPause.begin(now: start)
        MindfulPause.begin(now: start.addingTimeInterval(6))
        #expect(MindfulPause.stage(now: start.addingTimeInterval(6)) == .waiting(secondsLeft: 4))
    }

    /// A wait sat through once must not leave every later reach one tap from a
    /// pass — that would be the plain unlock button with extra steps.
    @Test func aFinishedWaitLapsesBackToIdle() {
        clear(); defer { clear() }
        let start = Date()
        MindfulPause.begin(now: start)
        let lapse = TimeInterval(MindfulPause.waitSeconds + MindfulPause.readyLifetime)
        #expect(MindfulPause.stage(now: start.addingTimeInterval(lapse - 1)) == .ready)
        #expect(MindfulPause.stage(now: start.addingTimeInterval(lapse)) == .idle)
    }

    @Test func aClockThatWentBackwardsIsNotAWait() {
        clear(); defer { clear() }
        let start = Date()
        MindfulPause.begin(now: start)
        #expect(MindfulPause.stage(now: start.addingTimeInterval(-30)) == .idle)
    }

    @Test func backToFocusResetsTheWait() {
        clear(); defer { clear() }
        MindfulPause.begin()
        MindfulPause.reset()
        #expect(MindfulPause.stage() == .idle)
    }

    // MARK: - The per-profile setting

    @Test func theSettingFollowsTheProfileName() {
        let name = "Test profile \(UUID().uuidString)"
        let renamed = name + " renamed"
        defer { MindfulPause.set(false, forProfile: name); MindfulPause.set(false, forProfile: renamed) }

        #expect(!MindfulPause.isOn(forProfile: name))
        MindfulPause.set(true, forProfile: name)
        #expect(MindfulPause.isOn(forProfile: name))

        MindfulPause.rename(from: name, to: renamed)
        #expect(!MindfulPause.isOn(forProfile: name))
        #expect(MindfulPause.isOn(forProfile: renamed))

        #expect(!MindfulPause.isOn(forProfile: nil))
        #expect(!MindfulPause.isOn(forProfile: ""))
    }

    // MARK: - Enforcers compose into one door

    /// Strict promises no way out and a pause is one, so strict wins even if a
    /// caller passes both.
    @Test func aStrictEnforcerIsNeverRecordedAsMindful() {
        clear(); defer { clear() }
        register(a, strict: true, mindful: true)
        #expect(!ActivityShieldStore.isMindful(for: a))
    }

    @Test func everyLiveEnforcerMindfulOffersTheWait() {
        clear(); defer { clear() }
        register(a, mindful: true)
        register(b, mindful: true)
        #expect(ActivityShieldStore.allActiveEnforcersAreMindful(future))
        #expect(ShieldDoor.current(now: future) == .mindful(.idle, minutes: UnlockWindow.mindfulMinutes))
    }

    /// A pass lifts everything. A plain enforcer alongside did not agree to be
    /// lifted, so the mindful one cannot grant a pass on its own authority.
    @Test func aPlainEnforcerAlongsideIsNotLiftedByAPause() {
        clear(); defer { clear() }
        register(a, mindful: true)
        register(b, mindful: false)
        #expect(ActivityShieldStore.anyActiveEnforcerIsMindful(future))
        #expect(!ActivityShieldStore.allActiveEnforcersAreMindful(future))
    }

    @Test func aStrictEnforcerAlongsideMeansNoDoorAtAll() {
        clear(); defer { clear() }
        register(a, mindful: true)
        register(b, strict: true, mindful: false)
        #expect(ShieldDoor.current(now: future) == .none)
    }

    @Test func nothingLiveIsNotAllMindful() {
        #expect(!ActivityShieldStore.allActiveEnforcersAreMindful(Date(timeIntervalSince1970: 4_200_000_000)))
    }

    // MARK: - The pass

    @Test func aPassIsNeverShorterThanTheFloor() {
        defer { UnlockWindow.clear() }
        let now = Date()
        let until = UnlockWindow.open(minutes: 5, now: now)
        #expect(until == now.addingTimeInterval(TimeInterval(UnlockWindow.minimumMinutes * 60)))
    }

    @Test func midPauseRedrawsAreNotCountedAsReaches() {
        #expect(ShieldDoor.mindful(.waiting(secondsLeft: 4), minutes: 15).isMidPause)
        #expect(ShieldDoor.mindful(.ready, minutes: 15).isMidPause)
        #expect(!ShieldDoor.mindful(.idle, minutes: 15).isMidPause)
        #expect(!ShieldDoor.unlock(minutes: 15).isMidPause)
    }
}
