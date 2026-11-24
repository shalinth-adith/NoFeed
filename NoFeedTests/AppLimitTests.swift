//
//  AppLimitTests.swift
//  NoFeedTests
//
//  A used-up limit becomes an ordinary enforcer that lasts until midnight. The
//  monitor extension and the Screen Time threshold itself only run on a device,
//  so these check the part that decides what gets shielded and for how long.
//

import Testing
import FamilyControls
import Foundation
@testable import NoFeed

@MainActor
@Suite(.serialized)
struct AppLimitTests {

    /// The limits list is one App Group key, so the suite keeps what was there.
    private func withLimits(_ limits: [AppLimit], _ body: () throws -> Void) rethrows {
        let saved = AppLimitStore.load()
        AppLimitStore.save(limits)
        defer {
            for limit in limits { AppLimitStore.clearReached(limit.id) }
            AppLimitStore.save(saved)
        }
        try body()
    }

    @Test func namesRoundTripAndNeverCollide() {
        let id = UUID()
        #expect(AppLimitStore.limitID(fromMonitor: AppLimitStore.monitorName(id)) == id)
        // The enforcer is not mistaken for the counting activity…
        #expect(AppLimitStore.limitID(fromMonitor: AppLimitStore.reachedName(id)) == nil)
        #expect(AppLimitStore.isReachedEnforcer(AppLimitStore.reachedName(id)))
        // …and nothing else is mistaken for either.
        #expect(AppLimitStore.limitID(fromMonitor: "zenly.focus.session") == nil)
        #expect(!AppLimitStore.isReachedEnforcer(AppLimitStore.monitorName(id)))
    }

    @Test func reachingALimitShieldsUntilMidnight() throws {
        let limit = AppLimit(name: "Social", minutes: 30)
        try withLimits([limit]) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            let now = try #require(calendar.date(bySettingHour: 15, minute: 10, second: 0, of: Date()))
            AppLimitStore.markReached(limit.id, now: now, calendar: calendar)

            let window = try #require(ActivityShieldStore.absoluteWindow(for: AppLimitStore.reachedName(limit.id)))
            #expect(window.start == now)
            #expect(window.end == calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)))

            // An enforcer like any other: active now, gone after midnight.
            #expect(ActivityShieldStore.activeActivitiesNow(now).contains(AppLimitStore.reachedName(limit.id)))
            #expect(AppLimitStore.anyReachedNow(now))
            #expect(!AppLimitStore.anyReachedNow(window.end.addingTimeInterval(1)))
            // A limit is never strict: the unlock window may still lift it.
            #expect(!ActivityShieldStore.isStrict(for: AppLimitStore.reachedName(limit.id)))
        }
    }

    @Test func aDisabledLimitIsNeverMarkedReached() {
        let limit = AppLimit(name: "Off", minutes: 30, isEnabled: false)
        withLimits([limit]) {
            AppLimitStore.markReached(limit.id)
            #expect(!AppLimitStore.isReached(limit.id))
        }
    }

    @Test func clearingLiftsTheBlock() {
        let limit = AppLimit(name: "Video", minutes: 15)
        withLimits([limit]) {
            AppLimitStore.markReached(limit.id)
            #expect(AppLimitStore.isReached(limit.id))
            AppLimitStore.clearReached(limit.id)
            #expect(!AppLimitStore.isReached(limit.id))
        }
    }

    @Test func limitsSurviveAStoreRoundTrip() {
        let limits = [AppLimit(name: "A", minutes: 20), AppLimit(name: "", minutes: 45, isEnabled: false)]
        withLimits(limits) {
            #expect(AppLimitStore.load() == limits)
            #expect(AppLimitStore.load()[1].displayName == "Daily limit")
        }
    }
}
