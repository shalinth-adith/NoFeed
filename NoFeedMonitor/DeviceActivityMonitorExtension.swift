//
//  DeviceActivityMonitorExtension.swift
//  NoFeedMonitor
//
//  Runs in a separate process. When a monitored interval (a Pomodoro focus
//  session or a recurring schedule) starts, it applies that activity's shields;
//  when the interval ends, it clears them. The selection for each activity is
//  read from the shared App-Group map (ActivityShieldStore) — the extension has
//  no access to the app's in-memory state.
//

import Foundation
import DeviceActivity
import ManagedSettings

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore(named: .noFeed)

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        // Weekday filtering: recurring schedules monitor daily but only apply on
        // selected weekdays (mask 0 = every day, used by one-off sessions).
        let mask = ActivityShieldStore.weekdaysMask(for: activity.rawValue)
        if mask != 0 {
            let weekday = Calendar.current.component(.weekday, from: Date())
            guard (mask & (1 << weekday)) != 0 else { return }
        }

        // A pass cannot survive into a strict window.
        //
        // The third way strictness leaked: a pass granted at 08:59 under a
        // non-strict block was still open when a strict schedule began at 09:00,
        // and `ShieldReconciler` lets an open window outrank every enforcer — so
        // the strict window opened already suppressed. `FocusSessionController`
        // clears the window when a *session* starts, but nothing did when a
        // schedule started, because that path never runs in the app.
        if ActivityShieldStore.isStrict(for: activity.rawValue) { UnlockWindow.clear() }

        // Reconcile to the union of every currently-active enforcer rather than
        // overwriting the store, so a newly-started window composes with any that
        // are already open instead of clobbering them.
        ShieldReconciler.reconcile(store)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        // Close the pass explicitly before reconciling, and do not rely on the
        // clock to have overtaken it.
        //
        // This wake-up IS the end of the unlock window, so the two instants are
        // the same by construction. `ShieldReconciler` treats an open window as
        // outranking everything, so arriving even a millisecond early — or
        // exactly on the boundary — made it clear the shields and return, with
        // nothing left scheduled to try again. The shields then stayed off until
        // the app was next opened, which is exactly what happened on device.
        //
        // Relying on expiry here was the mistake: it only helps if something
        // reconciles *after* the window ends, and this was the one thing that
        // would have.
        if activity == .unlockWindow { UnlockWindow.clear() }

        // Re-assert whatever is STILL active instead of clearing the whole store —
        // otherwise ending one window (or the one-off focus session) lifts a
        // schedule that is still in its window. Runs even if the app was killed.
        ShieldReconciler.reconcile(store)
    }
}
