# 2.3 verification — 2026-10-16

Build: commit `b4aabe6` and later, iPhone 17 Pro Simulator (iOS 26), app launched with
`NoFeedSeedDemoHistory NoFeedUITestBypassScreenTime NoFeedUITestResetSession`.

## Automated

| Run | Result |
|---|---|
| `NoFeedTests` (unit) | 170 tests in 22 suites, 0 failures |
| `QuietSessionScreens/testCompleteScreen` | PASS — completed summary shows the three chips; tapping Focused selects it |
| `QuietSessionScreens/testInsightsPopulatedScreen` | PASS |
| `NoFeedQuietSuite` | 14 pass, 2 skipped |
| `QuietSessionScreens` | 8 pass |
| `ProfileDetailScreens` | 5 pass |
| `QuietEditorScreens` | 2 pass |
| `NoFeedUITests` (legacy) | 2 pass; three tests that drove the retired "Profiles"/"Schedules" tabs were deleted, their flows being covered by `NoFeedQuietSuite` |
| `NoFeedUITestsLaunchTests` | 2 pass |

The full UI suite was run across three simulators (it exceeds a single ten-minute slot). Eight
tests that failed on the first pass were all fixture leaks between runs — a leftover profile
tripping the duplicate-name rule, a renamed Study, a session left running, a prior schedule
colliding one step early — plus one keyboard covering the schedule editor's rows on its second
open. Fixed by three DEBUG-only launch arguments (`NoFeedUITestResetProfiles`,
`NoFeedUITestResetSchedules`, `NoFeedUITestResetHistory`) that the suites pass, and a cleanup
helper rewritten for the 20b/20c screens.

## Screenshots

| File | Shows |
|---|---|
| `01-home-seeded.png` | Focus tab with seeded history |
| `02-insights-reflect-card.png` | Insights: "How did Today · Study, 33 min feel?" with Focused / Distracted / Interrupted |
| `03-insights-reflect-advanced.png` | After tapping Focused the card asks about the next unanswered session |
| `04-settings-feedback-row.png` | Settings › About: Version 2.3 (1) and Send feedback |
| `05-settings-feedback-fallback.png` | No mail client on Simulator → alert with the address and a Copy button |
| `06-url-start-study-session.png` | `xcrun simctl openurl … "nofeed://start?profile=<Study id>"` started a 50-minute Study session (the widget's Start pill path) |
| `07-hold-ended-early.png` | A 4-second hold on "Hold to end early" ended the session through the rewritten GestureState hold |

"What works for you" is correctly absent: fewer than ten sessions carry an answer.

## Not verifiable on the Simulator (needs a device)

- Notification actions on the focus-end notification arriving while the app is suspended, then
  the summary pre-selecting the answer on reopen.
- The Home Screen / Lock Screen widget families, the in-widget countdown and the Start pill
  tap itself (the URL it sends was exercised above).
- Shields staying up during the 60-second strict hold, and a strict session's hold label.
