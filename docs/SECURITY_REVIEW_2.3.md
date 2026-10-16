# Security review: NoFeed `9b1e864..beee24e`

**Date:** 2026-10-16
**Result:** no vulnerabilities meet the reporting bar. No finding reached medium or high severity with at least 80% confidence of real exploitability.

**Scope:** the code added on `main` since `9b1e864`: 15 commits across 46 files, read with the wider repository as context.

## Attack surfaces examined

| # | Surface | Location | Why it is not exploitable |
|---|---|---|---|
| 1 | `nofeed://start?profile=<uuid>` URL handler | `NoFeed/App/NoFeedApp.swift:143-171`, `Shared/FocusLaunchRequest.swift:61-67` | Scheme and host are checked, and the profile is parsed with `UUID(uuidString:)`. It only starts a session when none is running, using one of the user's own profiles with its own settings. No path stops a session, disables strict mode, or opens an unlock window. |
| 2 | App Intents and `FocusProfileEntity` | `Shared/StartFocusIntent.swift:27-30`, `Shared/FocusProfileEntity.swift` | Same capability as the URL. Invoking it requires the user's Shortcuts, Siri or Control Center. The entity query is read-only. |
| 3 | Profile directory and session accent in App Group defaults | `Shared/ProfileDirectory.swift:27-52`, `Shared/ActiveSessionInfo.swift` | Profile id, name, colour and length only. Readable only by the app's own signed extensions. Decoded with `JSONDecoder` into a plain struct. |
| 4 | Notification reflection actions | `NoFeed/Services/NotificationService.swift`, `NoFeed/Services/ReflectionInbox.swift` | Only the app's own local notifications reach the delegate. Action ids are validated against an enum. An action can only attach a mood rating; it cannot affect blocking. |
| 5 | UI-test and debug hooks | `NoFeed/Support/DebugSeed.swift`, `NoFeed/App/NoFeedApp.swift:31-89`, `AuthorizationService.swift:26-45`, `ProfileStore.swift:171-182` | All inside `#if DEBUG`, including the Screen Time bypass and the data resets. None ship in a Release build. |
| 6 | Feedback mail link | `NoFeed/Support/FeedbackMail.swift` | Hard-coded recipient, percent-encoded subject and body containing only app version, iOS version and device model. The user sends the draft themselves. |
| 7 | Privacy and support links, review prompt, widget links | `SettingsView.swift`, `ReviewPrompt.swift`, `NoFeedWidget/NoFeedWidget.swift` | Fixed constants or `URLComponents` from a UUID. The review prompt uses StoreKit's rate-limited system API. |
| 8 | 60-second strict hold-to-end | `QuietForm.swift`, `SessionView.swift:86-105` | Makes strict mode harder to leave: no pause, a 60-second hold, a cancelled gesture resets the timer, and the instant VoiceOver activation is off for strict sessions. |
| 9 | `project.yml` | `project.yml` | Version numbers and three Shared files added to the widget target. No new entitlements or URL schemes. |

## Note outside the reporting bar

**An unprompted session start through the URL scheme** is excluded as a nuisance, not an authorization bypass.

* **Location:** `NoFeed/App/NoFeedApp.swift:143-147`.
* **Behaviour:** another app can open `nofeed://start` and start one of the user's own profiles without asking. A website can too, after Safari's "Open in NoFeed?" prompt. A strict profile can still be ended with the 60-second hold.
* **Optional hardening:** show an in-app confirmation before a URL-triggered start.
