# NoFeed

An iPhone app that blocks distracting apps and websites while you focus. Built in
SwiftUI on Apple's Screen Time frameworks (FamilyControls, ManagedSettings,
DeviceActivity). No account, no server: everything stays on the device.

**Current version:** 2.3, on the App Store.

## What it does

- **Focus sessions.** Pick a profile, set a length, and NoFeed shields the apps it
  blocks until the timer ends. Sessions can pause, take a break, and end early
  with a three-second hold.
- **Profiles.** Work, Study, Gym and Sleep ship by default. Each blocks everything
  or a chosen set of apps, keeps an allowlist, and sets its own length. **Strict
  mode** removes pause and makes ending early a 60-second hold.
- **Schedules.** Recurring focus windows that block on their own, with clash
  detection.
- **The block screen.** A custom shield ("Instagram is behind this door") with an
  optional timed **unlock window** (15, 30 or 60 minutes, off by default, never
  offered during anything strict).
- **Insights.** The calendar week, sessions, how often a blocked app was reached
  for, daily goals, a weekly recap with a shareable card, and "What works for you"
  rules once ten sessions have a reflection (Focused / Distracted / Interrupted).
- **Outside the app.** A Home Screen and Lock Screen widget with a Start button
  and live countdown, a Live Activity, a Control Center button, Siri and
  Shortcuts intents, and actions on the session-end notification.

## Requirements

- Xcode 26 or later.
- A **paid** Apple Developer account. The Family Controls capability requires one.
- A **physical iPhone** to see anything blocked. Screen Time does nothing in the
  Simulator; the app builds and runs there, but no shield ever appears.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.

## Building

The Xcode project is generated from `project.yml` and is not committed.

```bash
xcodegen generate
open NoFeed.xcodeproj
```

Change targets, capabilities, versions or build settings in `project.yml`, then
regenerate. Never edit the generated project by hand. Raise `MARKETING_VERSION`
after every approved release; App Store Connect refuses builds on a closed train.

## Targets

Five targets share the App Group `group.me.adithyan.shalinth.Zenly`.

| Target | Kind | Role |
|---|---|---|
| `NoFeed` | App | All UI, sessions, profiles, schedules, Insights, settings |
| `NoFeedMonitor` | DeviceActivityMonitor extension | Applies and lifts shields when scheduled windows start and end |
| `NoFeedShield` | ShieldConfiguration extension | Draws the block screen and counts each reach for a blocked app |
| `NoFeedShieldAction` | ShieldAction extension | Handles "Back to focus" and the unlock window |
| `NoFeedWidget` | WidgetKit extension | Widget, Live Activity and Control Center button |

The processes cannot call each other. They coordinate only through App Group
`UserDefaults`, and `ShieldReconciler` rebuilds the shield state from what is
registered there on every wake. Any code path that applies shields must register
itself first, or the next reconcile clears them.

**Identifiers say "Zenly" on purpose.** The app was renamed to NoFeed, but the bundle
id, App Group, Core Data model (`Zenly.xcdatamodeld`) and some notification and
activity ids keep the old name. They are the App Store identity and are already on
users' devices; renaming them would strand existing data.

## Layout

```
NoFeed/
├── App/           NoFeedApp.swift: composition root, scene-phase handling, URL handling
├── DesignSystem/  The "Quiet" theme (ZTheme), form components, orb, buttons, readable colours
├── Intents/       Siri / Shortcuts / Focus filter intents
├── Models/        Core Data model and value types (WeeklyRecap, InsightRules, SessionReflection)
├── Services/      Session controller, stores, analytics, notifications, persistence, store health
├── Support/       Haptics, feedback mail, DEBUG-only seeding and test hooks
└── Views/         SwiftUI screens by area
Shared/            Code compiled into the app and one or more extensions
NoFeedMonitor/     NoFeedShield/     NoFeedShieldAction/     NoFeedWidget/
NoFeedTests/       Unit tests (Swift Testing, in-memory Core Data)
NoFeedUITests/     UI tests, screenshot tours and the accessibility audit
docs/              Review notes, test reports, evidence, the support site
```

## Localization

NoFeed ships in English, Spanish, French, German, Japanese and Brazilian
Portuguese. All copy lives in two String Catalogs:

- `Shared/Localizable.xcstrings` holds every UI, notification, widget and shield
  string. Each target that compiles shared code bundles it.
- `NoFeed/AppShortcuts.xcstrings` holds the Siri phrases.

Rules for new copy:

- Pass literals to `Text`, `Button` and the Quiet components directly; they take
  `LocalizedStringResource`, so the literal is extracted. Wrap computed copy in
  `String(localized:)`. User data such as a profile name goes through
  `.verbatim(_:)` or `Text(verbatim:)`.
- Never build a plural by hand (`"minute\(n == 1 ? "" : "s")"`). Write the plural
  once, `"\(n) minutes"`, and give the key one/other variations in the catalog.
  A label that sits under a separately drawn number needs two keys instead,
  because the catalog rejects a plural form without the number.
- Format dates and times with `formatted(...)` styles, not fixed `dateFormat`
  patterns, so order and the 12/24-hour clock follow the user's region.
- Building in Xcode adds new keys to the catalog. A key without translations
  falls back to English at runtime.

## Testing

```bash
xcodebuild test -project NoFeed.xcodeproj -scheme NoFeed \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:NoFeedTests
```

- **Unit tests** cover the pure logic: streaks, analytics, the weekly recap, insight
  rules, reflections, the unlock window, short-session shields, strict mode
  across processes, widget hand-off, profile renames and storage-failure
  reporting.
- **UI tests** run on the Simulator with DEBUG-only launch arguments that bypass
  Screen Time and reset state (`NoFeedUITestBypassScreenTime`,
  `NoFeedUITestResetSession`, `NoFeedUITestResetProfiles`,
  `NoFeedUITestResetSchedules`, `NoFeedUITestResetHistory`,
  `NoFeedUITestSkipOnboarding`). None of these exist in a Release build.
- **`AccessibilityAudit`** runs Apple's accessibility audit on 24 screens and
  checks every contrast flag against the rendered pixels. Set
  `TEST_RUNNER_QUIET_SHOT_DIR` to keep its screenshots and findings.
- **On a device** is the only way to test blocking itself. See
  `docs/DEVICE_TEST_PLAN.md`.

## Documents

- `docs/APP_REVIEW_NOTES.md`: what to paste into App Store Connect. Update it in
  the same commit as any change to onboarding, tab names or the blocking flow.
- `docs/test-evidence/ux-review-2.3/REPORT.md`: the 2.3 UI/UX and accessibility review.
- `docs/SECURITY_REVIEW_2.3.md`: the 2.3 security review.
- `docs/privacy-policy.html`, `docs/support.html`: served by GitHub Pages.
