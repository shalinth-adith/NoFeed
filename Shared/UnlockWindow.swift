//
//  UnlockWindow.swift
//  NoFeed (shared: app + NoFeedShield + NoFeedShieldAction + NoFeedMonitor)
//
//  A deliberate, time-boxed pass out of a running block.
//
//  This is the second attempt at the block screen's second button. The first —
//  "I need it for 5 minutes" — was removed because it tried to exempt *one app*,
//  and a pass has to name the app it lets through: the only currency
//  `shield.applicationCategories = .all(except:)` accepts is an
//  `ApplicationToken`, which Screen Time does not hand the extension when the
//  shield came from a category. See `ShieldTheme.configuration` for the
//  measurement. "Block everything" is a category shield and the default on every
//  shipped profile, so that door was dead on nearly every screen anyone saw.
//
//  This one sidesteps the token problem by not needing a token: it lifts
//  **everything** for the window rather than exempting one app. Clearing shields
//  names nothing, so it works identically whether the block came from a category,
//  a hand-picked list, or a schedule.
//
//  ## Why the floor is fifteen minutes
//
//  Opening a window is easy; *closing* it on time is the hard half. Nothing on
//  iOS can reliably run code in five minutes:
//
//    · `DeviceActivitySchedule` has an ~15-minute minimum interval (Apple's, the
//      same floor `ScheduleCenter.startOneOff` documents).
//    · `BGAppRefreshTask` is granted at the system's discretion, not on a deadline.
//    · A foreground timer dies the moment the user leaves for the app they just
//      unlocked — which is the entire point of unlocking.
//
//  So a five-minute pass would in practice be an "until you next open NoFeed"
//  pass, which is a blocker that quietly turns itself off. Fifteen minutes is the
//  shortest window the system can actually close, so it is the shortest window
//  this offers.
//
//  ## Two layers, on purpose
//
//  `isOpen` is a pure function of the clock, and `ShieldReconciler` consults it on
//  *every* reconcile. The DeviceActivity interval registered alongside makes the
//  re-lock prompt; the expiry makes it certain. If `startMonitoring` fails inside
//  the shield-action extension — a process that runs for a fraction of a second
//  and cannot be debugged — the shields still come back on the next reconcile
//  from any source. Promptness degrades; correctness does not.
//

import Foundation

enum UnlockWindow {
    private static let untilKey = "unlockWindowUntil"
    /// User setting, in minutes. 0 = the feature is off and no button is drawn.
    private static let minutesKey = "unlockWindowMinutes"

    /// Apple's `DeviceActivitySchedule` minimum. A window shorter than this
    /// cannot be closed by the system, so it is not offered.
    static let minimumMinutes = 15

    /// Durations the settings picker offers. Off is represented by 0.
    static let choices = [0, 15, 30, 60]

    // MARK: - The setting

    /// How long a pass lasts, or 0 when the feature is off (the default —
    /// a blocker should not ship with a way out already switched on).
    static var configuredMinutes: Int {
        get { AppGroup.defaults.integer(forKey: minutesKey) }
        set {
            let clean = newValue <= 0 ? 0 : max(minimumMinutes, newValue)
            AppGroup.defaults.set(clean, forKey: minutesKey)
        }
    }

    static var isEnabled: Bool { configuredMinutes >= minimumMinutes }

    // MARK: - The window

    /// When the current pass expires, or nil when none is open.
    static var openUntil: Date? {
        let raw = AppGroup.defaults.double(forKey: untilKey)
        guard raw > 0 else { return nil }
        let date = Date(timeIntervalSince1970: raw)
        return date > Date() ? date : nil
    }

    static func isOpen(now: Date = Date()) -> Bool {
        let raw = AppGroup.defaults.double(forKey: untilKey)
        guard raw > 0 else { return false }
        return Date(timeIntervalSince1970: raw) > now
    }

    /// Whole minutes left, rounded up so the last partial minute reads "1".
    static var remainingMinutes: Int? {
        guard let until = openUntil else { return nil }
        let seconds = until.timeIntervalSinceNow
        guard seconds > 0 else { return nil }
        return max(1, Int(ceil(seconds / 60)))
    }

    /// Open a pass for the configured length. Returns the end date, or nil when
    /// the feature is off — callers use nil to mean "no pass was granted", so a
    /// disabled setting can never be talked into one.
    @discardableResult
    static func open(now: Date = Date()) -> Date? {
        let minutes = configuredMinutes
        guard minutes >= minimumMinutes else { return nil }
        let until = now.addingTimeInterval(TimeInterval(minutes * 60))
        AppGroup.defaults.set(until.timeIntervalSince1970, forKey: untilKey)
        return until
    }

    /// Close any open pass.
    ///
    /// Called when a session starts as well as when one ends: beginning a focus
    /// session while a pass is still open would otherwise start a session that
    /// blocks nothing, with a countdown running over an unshielded phone.
    static func clear() {
        AppGroup.defaults.removeObject(forKey: untilKey)
    }
}
