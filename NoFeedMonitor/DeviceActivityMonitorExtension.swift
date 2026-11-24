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
import UserNotifications

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let store = ManagedSettingsStore(named: .noFeed)

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        // A daily limit's new day: yesterday's used-up allowance is lifted. The
        // enforcer would expire at midnight on its own; clearing it here just
        // makes that exact. Its counting activity is not an enforcer, so there
        // is nothing to apply.
        if let id = AppLimitStore.limitID(fromMonitor: activity.rawValue) {
            AppLimitStore.clearReached(id)
            ShieldReconciler.reconcile(store)
            return
        }

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

    // MARK: - Daily limits

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                         activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard let id = AppLimitStore.limitID(fromMonitor: activity.rawValue) else { return }
        AppLimitStore.markReached(id)
        ShieldReconciler.reconcile(store)
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name,
                                                 activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        guard let id = AppLimitStore.limitID(fromMonitor: activity.rawValue),
              let limit = AppLimitStore.limit(id: id), limit.isEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = limit.displayName
        content.body = String(localized: "\(AppLimitStore.warningMinutes) minutes left for today.")
        content.sound = .default
        let request = UNNotificationRequest(identifier: "nofeed.limit.warning.\(id.uuidString)",
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
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
