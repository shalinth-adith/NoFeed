//
//  UnlockWindowTests.swift
//  NoFeedTests
//
//  The block screen's timed pass. This is the one feature in the app whose job
//  is to *stop* blocking, so the tests are written around the ways it could fail
//  open — a pass granted when the setting is off, a window that outlives its
//  duration, a pass surviving into the next session.
//
//  Serialized, and every test restores the two keys it touches: `UnlockWindow` is
//  a single pair of App Group values by design (the shield extensions have no
//  other channel), so parallel tests would overwrite each other's windows, and a
//  leaked window would leave the simulator's app unshielded after the run.
//
//  These are on `UnlockWindow` rather than on `ShieldReconciler` for the same
//  reason `ShortSessionShieldTests` is: `ManagedSettingsStore` does nothing
//  outside a Screen Time-authorized device, so what is checkable is whether the
//  window reports itself correctly — which is exactly what the reconciler reads.
//

import Testing
import Foundation
@testable import NoFeed

@Suite(.serialized)
struct UnlockWindowTests {

    /// Save both keys, run, restore. `UnlockWindow` writes through to the shared
    /// suite, so without this a failed assertion could leave a real pass open.
    private func withCleanState(_ body: () throws -> Void) rethrows {
        let defaults = AppGroup.defaults
        let savedMinutes = defaults.object(forKey: "unlockWindowMinutes")
        let savedUntil = defaults.object(forKey: "unlockWindowUntil")
        defer {
            defaults.set(savedMinutes, forKey: "unlockWindowMinutes")
            defaults.set(savedUntil, forKey: "unlockWindowUntil")
            if savedMinutes == nil { defaults.removeObject(forKey: "unlockWindowMinutes") }
            if savedUntil == nil { defaults.removeObject(forKey: "unlockWindowUntil") }
        }
        UnlockWindow.clear()
        UnlockWindow.configuredMinutes = 0
        try body()
    }

    // MARK: - The setting

    /// Off is the default and the only value below the floor that survives. A
    /// blocker should not ship with its own way out already switched on.
    @Test func offIsRepresentableAndIsNotClampedUp() {
        withCleanState {
            UnlockWindow.configuredMinutes = 0
            #expect(UnlockWindow.configuredMinutes == 0)
            #expect(!UnlockWindow.isEnabled)
        }
    }

    /// Anything positive but under Apple's schedule floor is raised to it rather
    /// than honoured. A ten-minute window cannot be closed by the system, so
    /// offering one would be a promise nothing can keep.
    @Test func aWindowUnderTheFloorIsRaisedToIt() {
        withCleanState {
            UnlockWindow.configuredMinutes = 5
            #expect(UnlockWindow.configuredMinutes == UnlockWindow.minimumMinutes)
            UnlockWindow.configuredMinutes = 14
            #expect(UnlockWindow.configuredMinutes == 15)
        }
    }

    @Test func realDurationsAreKept() {
        withCleanState {
            for minutes in [15, 30, 60] {
                UnlockWindow.configuredMinutes = minutes
                #expect(UnlockWindow.configuredMinutes == minutes)
                #expect(UnlockWindow.isEnabled)
            }
        }
    }

    /// The picker must never offer something the floor would silently rewrite.
    @Test func everyOfferedChoiceIsEitherOffOrLegal() {
        for choice in UnlockWindow.choices {
            #expect(choice == 0 || choice >= UnlockWindow.minimumMinutes)
        }
    }

    // MARK: - Granting a pass
    //
    // The failure that matters is failing *open*.

    /// With the setting off there is no pass, whatever presses the button. The
    /// shield draws no second button in this state, but the two processes are
    /// separate and the setting can change between drawing and pressing.
    @Test func noPassIsGrantedWhileTheFeatureIsOff() {
        withCleanState {
            UnlockWindow.configuredMinutes = 0
            #expect(UnlockWindow.open() == nil)
            #expect(!UnlockWindow.isOpen())
        }
    }

    @Test func aPassRunsForTheConfiguredLength() throws {
        try withCleanState {
            UnlockWindow.configuredMinutes = 30
            let now = Date()
            let until = try #require(UnlockWindow.open(now: now))
            #expect(abs(until.timeIntervalSince(now) - 30 * 60) < 1)
            #expect(UnlockWindow.isOpen(now: now))
        }
    }

    // MARK: - Closing itself
    //
    // The whole design rests on this: the DeviceActivity interval makes the
    // re-lock prompt, but expiry is what makes it certain. If these fail, a
    // failed `startMonitoring` leaves the phone unshielded indefinitely.

    @Test func aWindowIsClosedOnceItsTimeHasPassed() {
        withCleanState {
            UnlockWindow.configuredMinutes = 15
            // Opened twenty minutes ago: a fifteen-minute pass that expired five
            // minutes back.
            UnlockWindow.open(now: Date().addingTimeInterval(-20 * 60))
            #expect(!UnlockWindow.isOpen())
            #expect(UnlockWindow.openUntil == nil)
            #expect(UnlockWindow.remainingMinutes == nil)
        }
    }

    @Test func aWindowIsStillOpenJustBeforeItExpires() {
        withCleanState {
            UnlockWindow.configuredMinutes = 15
            UnlockWindow.open(now: Date().addingTimeInterval(-14 * 60))
            #expect(UnlockWindow.isOpen())
            #expect(UnlockWindow.remainingMinutes == 1)
        }
    }

    /// Rounds up, so the last partial minute reads "1 minute" rather than "0".
    @Test func remainingMinutesRoundUp() {
        withCleanState {
            UnlockWindow.configuredMinutes = 30
            UnlockWindow.open(now: Date().addingTimeInterval(-30 * 60 + 90))
            #expect(UnlockWindow.remainingMinutes == 2)
        }
    }

    /// The regression, stated as the hazard it is.
    ///
    /// A pass is still open a moment before it expires — which is correct, and is
    /// precisely why `DeviceActivityMonitorExtension.intervalDidEnd` must *clear*
    /// the window rather than trust the clock to have overtaken it. That wake-up
    /// is the end of the window by construction, so arriving a hair early found
    /// `isOpen` true, took the reconciler's suppression branch, re-cleared the
    /// shields, and left nothing scheduled to try again. On device the shields
    /// stayed off until the app was next opened.
    ///
    /// The extension is a separate target and cannot be exercised from here, so
    /// this pins the semantics its correctness depends on rather than the call.
    @Test func aWindowIsStillOpenAMomentBeforeItExpires() {
        withCleanState {
            UnlockWindow.configuredMinutes = 15
            // Half a second short of expiry — the size of the race.
            UnlockWindow.open(now: Date().addingTimeInterval(-15 * 60 + 0.5))
            #expect(UnlockWindow.isOpen())
            // ...and an explicit close does not care what the clock says.
            UnlockWindow.clear()
            #expect(!UnlockWindow.isOpen())
        }
    }

    @Test func clearingClosesAnOpenWindow() {
        withCleanState {
            UnlockWindow.configuredMinutes = 60
            UnlockWindow.open()
            #expect(UnlockWindow.isOpen())
            UnlockWindow.clear()
            #expect(!UnlockWindow.isOpen())
            #expect(UnlockWindow.openUntil == nil)
        }
    }

    /// Turning the setting off does not by itself close a running pass — the
    /// settings screen calls `clear()` for that. Pinned so the responsibility
    /// does not quietly move and end up owned by neither.
    @Test func theSettingAndTheWindowAreIndependent() {
        withCleanState {
            UnlockWindow.configuredMinutes = 15
            UnlockWindow.open()
            UnlockWindow.configuredMinutes = 0
            #expect(UnlockWindow.isOpen())
            UnlockWindow.clear()
            #expect(!UnlockWindow.isOpen())
        }
    }
}
