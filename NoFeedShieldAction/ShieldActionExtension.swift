//
//  ShieldActionExtension.swift
//  NoFeedShieldAction
//
//  Handles taps on the block screen's button (Quiet spec, screen 03).
//
//  There is one button — "Back to focus" — and it closes the app you reached
//  for. Every action closes, whichever overload iOS routes it to.
//
//  There used to be a second button offering five minutes with the app, backed
//  by a snooze store with an expiry. It is gone. Granting a pass means naming
//  the app to exempt, and the only currency `shield.applicationCategories =
//  .all(except:)` accepts is an `ApplicationToken` — which Screen Time does not
//  hand out when the shield came from a category. "Block everything" is a
//  category shield and is the default on all four profiles, so the door was a
//  control that closed the app and changed nothing on nearly every block screen
//  anyone would ever see. See `ShieldTheme.configuration` for the measurement.
//
//  What remains is small enough to be obviously correct, which is the right
//  shape for a process iOS spawns for a fraction of a second and cannot be
//  debugged from.
//

import DeviceActivity
import Foundation
import ManagedSettings
import ManagedSettingsUI

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction,
                         for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, completionHandler)
    }

    /// `.primaryButtonPressed` is "Back to focus"; `.secondaryButtonPressed` is
    /// the timed pass. Any other case closes, because an unrecognised action must
    /// never be treated as consent to unblock.
    private func respond(to action: ShieldAction,
                         _ completionHandler: @escaping (ShieldActionResponse) -> Void) {
        DistractionLog.recordAttempt()

        guard action == .secondaryButtonPressed else {
            completionHandler(.close)
            return
        }
        grantPass(completionHandler)
    }

    /// Open a window, drop the shields, and arrange for them to come back.
    ///
    /// Order matters. The window is recorded *first*: `ShieldReconciler` treats an
    /// open window as outranking every enforcer, so any reconcile racing this
    /// process — the app foregrounding, a schedule tick — sees the pass rather
    /// than re-applying the shield we are about to clear.
    ///
    /// `startMonitoring` is best-effort by design. This process gets a fraction of
    /// a second, cannot be debugged, and may not be allowed to register an
    /// activity at all. If it fails the pass still closes itself: `isOpen` is a
    /// pure function of the clock, so the next reconcile from any source restores
    /// the shields. The interval only makes that prompt.
    private func grantPass(_ completionHandler: @escaping (ShieldActionResponse) -> Void) {
        guard let until = UnlockWindow.open() else {
            // The setting was switched off between drawing the button and pressing
            // it. No pass, no pretending there was one.
            completionHandler(.close)
            return
        }

        ShieldApplier.clear(ManagedSettingsStore(named: .noFeed))
        startCloser(at: until)

        // `.defer` leaves the user in the app they reached for, which is the whole
        // point — `.close` would grant the pass and then throw them out of it.
        completionHandler(.defer)
    }

    private func startCloser(at until: Date) {
        let calendar = Calendar.current

        // Wake a minute PAST the window rather than exactly on it.
        //
        // Belt to the braces of `UnlockWindow.clear()` in the monitor's
        // `intervalDidEnd`. The two instants used to coincide by construction, so
        // a wake-up arriving on or a hair before the boundary found the window
        // still open and re-cleared the shields instead of restoring them. Either
        // fix alone closes that; both together mean the restore does not depend on
        // the order two clocks happen to tick in.
        //
        // Costs the user nothing they would notice — the pass they were promised
        // is honoured in full, and a minute later the shields come back.
        let wake = until.addingTimeInterval(60)

        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: Date()),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: wake),
            repeats: false
        )
        do {
            try DeviceActivityCenter().startMonitoring(.unlockWindow, during: schedule)
        } catch {
            // Logged rather than surfaced: the fallback above is silent and
            // correct, and there is no UI in this process to complain to.
            print("[NoFeed] unlock window monitoring failed: \(error)")
        }
    }
}
