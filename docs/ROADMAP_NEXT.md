# NoFeed — next feature set

Ten features in three tiers, built one at a time. Each one is its own commit,
with unit tests and a clean build before it lands. The App Store rating prompt
stays exactly as it is.

## Constraints every feature respects

- **No new Screen Time extension.** Every Screen Time extension needs its own
  Family Controls approval from Apple. Everything below runs in the existing app,
  monitor, shield and shield-action targets.
- **One shield state.** Every enforcer (session, schedule, limit, Focus link,
  location) registers in `ActivityShieldStore`, and `ShieldReconciler` derives
  what is shielded from the union. Nothing writes the store directly.
- **A pass lifts everything.** Under "block everything", iOS gives no token for
  the app behind the shield, so no button can unblock one app on its own. Passes
  go through `UnlockWindow`, which lifts every block for at least 15 minutes.
- **Nothing leaves the phone unless the user turns it on.** iCloud sync and
  focusing with a friend are opt-in and off by default. The privacy policy and
  the App Store privacy slide change in the same commit as each of them.

## Build order

One phase at a time: each is built, tested on a device, and signed off before
the next starts. ✅ marks a phase that is built and waiting for, or past, that test.

| # | Feature | Tier | How |
|---|---|---|---|
| 1 ✅ | Show the score | 3 | `FocusScore` on Insights: time, consistency and follow-through, each shown |
| 2 ✅ | Daily app limits | 2 | A daily `DeviceActivitySchedule` with a `DeviceActivityEvent` threshold per limit. The monitor's `eventDidReachThreshold` registers a limit enforcer until midnight. |
| 3 ✅ | Mindful pause | 1 | A per-profile "pause, don't block" mode. The shield's second button asks once, makes you wait ten seconds (`.defer` redraws the shield), then opens the unlock window. Device test: `docs/TEST_PHASE_3.md`. |
| 4 | Focus mode link | 2 | `ApplyFocusProfileIntent` registers an enforcer while the iOS Focus is on, capped at 12 hours so a missed "off" can't strand a shield. |
| 5 | Locked sessions | 2 | A strict option with no early end and `application.denyAppRemoval` for the session. One emergency exit a week, behind a five-minute hold. |
| 6 | Weekly challenges | 1 | Challenges measured from session history, each ending in a share card. |
| 7 | Location triggers | 2 | Arriving at a saved place starts a profile. `CLMonitor`, "Always" location, opt-in. |
| 8 | Focus with a friend | 1 | SharePlay over Messages or FaceTime: both see whether the other held. An invite link works without SharePlay. |
| 9 | iCloud sync | 3 | Opt-in `NSPersistentCloudKitContainer` mirroring. App choices stay per device (Screen Time tokens are device-specific). |
| 10 | Apple Watch | 3 | A watchOS app: start, see the countdown, hold to end, via WatchConnectivity. |

## Needs you (cannot be done from here)

- **iCloud container** (feature 9): Xcode's automatic signing registers it on
  the first device build; confirm it in the developer portal.
- **SharePlay** (feature 8): the Group Activities capability, same as above.
- **Device testing**: limits, the pause, locked sessions, location and SharePlay
  only run on a real iPhone. The Simulator can build and lay them out.
- **App Review notes**: locked sessions and denying app removal need a sentence
  in `docs/APP_REVIEW_NOTES.md` before submission.
