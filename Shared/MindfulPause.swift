//
//  MindfulPause.swift
//  NoFeed (shared: app + NoFeedShield + NoFeedShieldAction + NoFeedMonitor)
//
//  "Pause, don't block": a per-profile mode where the block screen is a speed
//  bump rather than a wall.
//
//  Reaching for a blocked app still lands on the shield. Its second button —
//  "I still want it" — does not open anything. It starts ten seconds of
//  waiting, and only after those ten seconds does the same button offer to
//  open the door for a while. Most reaches are reflexes; ten seconds is long
//  enough for a reflex to notice itself, and short enough that a real need is
//  not punished.
//
//  ## How a wait works with no timer
//
//  The shield cannot run code on a timer: iOS asks for a `ShieldConfiguration`,
//  draws it in its own process, and calls back only when a button is pressed.
//  So the wait is a timestamp in the App Group, and every stage is a pure
//  function of the clock:
//
//      idle ──tap──▶ waiting (10…1 s left) ──tap after 10 s──▶ ready ──tap──▶ pass
//
//  The shield-action extension answers a tap during the wait with `.defer`,
//  which makes iOS ask for a fresh configuration. That redraw reads the
//  timestamp and shows how long is left. Nothing has to wake up on time.
//
//  ## What the pass is
//
//  The same `UnlockWindow` the plain unlock button opens: everything lifts, for
//  the configured length or the 15-minute floor when that setting is off. A
//  profile turning this mode on *is* the opt-in, so it does not also need the
//  global unlock setting. See `UnlockWindow` for why a pass cannot be per app.
//
//  ## Where the setting lives
//
//  Keyed by profile name in the App Group, not on the Core Data entity. The
//  model is unversioned, so a new attribute would break every installed store,
//  and the extensions cannot open Core Data anyway. Each enforcer carries its
//  own `isMindful` flag in `ActivityShieldStore`, written when it registers,
//  so the shield can tell what it is standing in front of.
//

import Foundation

enum MindfulPause {
    /// How long the wait is.
    static let waitSeconds = 10

    /// How long a finished wait stays "ready" before it lapses back to idle.
    ///
    /// Without a limit, waiting once would leave every later reach one tap away
    /// from a pass — which is the plain unlock button with extra steps. Two
    /// minutes covers reading the screen and deciding; it does not cover
    /// putting the phone down and coming back.
    static let readyLifetime = 120

    enum Stage: Equatable {
        case idle
        case waiting(secondsLeft: Int)
        case ready
    }

    private static let requestedKey = "mindfulPauseRequestedAt"
    private static let profilesKey = "mindfulPauseProfiles"

    // MARK: - The wait

    static func stage(now: Date = Date()) -> Stage {
        let raw = AppGroup.defaults.double(forKey: requestedKey)
        guard raw > 0 else { return .idle }
        let elapsed = now.timeIntervalSince(Date(timeIntervalSinceReferenceDate: raw))
        // A clock that moved backwards (or a timestamp from the future) is not
        // a wait anyone sat through.
        guard elapsed >= 0 else { return .idle }
        if elapsed < Double(waitSeconds) {
            return .waiting(secondsLeft: max(1, Int(ceil(Double(waitSeconds) - elapsed))))
        }
        if elapsed < Double(waitSeconds + readyLifetime) { return .ready }
        return .idle
    }

    /// Start the ten seconds. A wait already under way is left alone, so
    /// tapping again does not restart the count.
    static func begin(now: Date = Date()) {
        guard stage(now: now) == .idle else { return }
        // Reference-date, not 1970: `Date` holds `timeIntervalSinceReferenceDate`,
        // so it round-trips exactly. Going via 1970 lands a hair early and the
        // stage boundaries drift (see `ActivityShieldStore.set`).
        AppGroup.defaults.set(now.timeIntervalSinceReferenceDate, forKey: requestedKey)
    }

    /// Back to idle: after a pass is granted, and after "Back to focus".
    static func reset() {
        AppGroup.defaults.removeObject(forKey: requestedKey)
    }

    // MARK: - The setting

    /// Profiles that pause rather than block, by name.
    static var profileNames: Set<String> {
        Set(AppGroup.defaults.stringArray(forKey: profilesKey) ?? [])
    }

    static func isOn(forProfile name: String?) -> Bool {
        guard let name, !name.isEmpty else { return false }
        return profileNames.contains(name)
    }

    static func set(_ on: Bool, forProfile name: String) {
        guard !name.isEmpty else { return }
        var names = profileNames
        if on { names.insert(name) } else { names.remove(name) }
        AppGroup.defaults.set(names.sorted(), forKey: profilesKey)
    }

    static func rename(from oldName: String, to newName: String) {
        guard oldName != newName, isOn(forProfile: oldName) else { return }
        set(false, forProfile: oldName)
        set(true, forProfile: newName)
    }
}

// MARK: - Which door the block screen offers

/// The block screen's second button, decided in one place.
///
/// The shield draws it and the shield-action extension acts on it, in two
/// processes at two different times. Both ask this, so what is pressed can
/// never be more generous than what was drawn — and the action re-asks at
/// press time, because state can change in between (a strict session starting
/// is the case that matters).
enum ShieldDoor: Equatable {
    /// One button. Strict is running, or nothing has opted into a way out.
    case none
    /// The plain timed pass from Settings.
    case unlock(minutes: Int)
    /// "Pause, don't block": a wait before the pass.
    case mindful(MindfulPause.Stage, minutes: Int)

    static func current(now: Date = Date()) -> ShieldDoor {
        guard !ActiveSessionInfo.isStrict,
              !ActivityShieldStore.anyActiveEnforcerIsStrict(now) else { return .none }

        // A pass lifts everything, so the wait can grant one on its own only
        // when every live enforcer agreed to pause. Alongside one that did not,
        // the global unlock setting has to cover it — and then the wait still
        // applies, because the stricter door of the two is the honest one.
        if ActivityShieldStore.anyActiveEnforcerIsMindful(now),
           UnlockWindow.isEnabled || ActivityShieldStore.allActiveEnforcersAreMindful(now) {
            return .mindful(MindfulPause.stage(now: now), minutes: UnlockWindow.mindfulMinutes)
        }
        if UnlockWindow.isEnabled { return .unlock(minutes: UnlockWindow.configuredMinutes) }
        return .none
    }

    /// The second button's words, or nil for a one-button screen.
    var buttonTitle: String? {
        switch self {
        case .none:
            return nil
        case .unlock(let minutes):
            return String(localized: "Unlock for \(String(localized: "\(minutes) minutes"))")
        case .mindful(.idle, _):
            return String(localized: "I still want it")
        case .mindful(.waiting(let seconds), _):
            return String(localized: "Wait \(String(localized: "\(seconds) seconds"))")
        case .mindful(.ready, let minutes):
            return String(localized: "Open for \(String(localized: "\(minutes) minutes"))")
        }
    }

    /// The line the subtitle leads with while a pause is under way.
    var leadLine: String? {
        switch self {
        case .mindful(.waiting, _):
            return String(localized: "Take a breath. Ten seconds, then it\u{2019}s your call.")
        case .mindful(.ready, let minutes):
            return String(localized: "Still want it? It opens for \(String(localized: "\(minutes) minutes")), then closes again.")
        default:
            return nil
        }
    }

    /// True while the shield is being redrawn for a pause rather than shown
    /// for a new reach. The shield extension skips counting the attempt then:
    /// each `.defer` asks for a fresh screen, and counting each one would turn
    /// one reach into three on Insights.
    var isMidPause: Bool {
        if case .mindful(let stage, _) = self { return stage != .idle }
        return false
    }
}
