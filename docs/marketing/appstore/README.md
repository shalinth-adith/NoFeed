# App Store screenshots

Seven screenshots at 1320 × 2868, the 6.9" iPhone size App Store Connect requires.
Upload `final/1-…` to `final/7-…` in order. They are opaque RGB PNGs, as App
Store Connect requires.

| # | Caption | Screen |
|---|---|---|
| 1 | Block the apps that eat your day | A running session beside real block screens for Instagram, YouTube, X and TikTok |
| 2 | A pause, not a lecture. | The block screen for Instagram |
| 3 | It holds. Even if you force-quit. | Lock Screen with the session's Live Activity |
| 4 | One tap. Work, Study, Gym. | Focus tab with the four built-in profiles |
| 5 | Your mornings, protected automatically | Schedule tab, weekdays 9:00–11:00 |
| 6 | Streaks you earn. Progress you can see. | History: sessions, hours, day streak, reflections |
| 7 | No account. No tracking. Nothing leaves your phone. / Free. No subscription. Ever. | Type only |

Slide 1 is the one most people see, so it carries the most information. iOS's
own app picker would be better still, but it cannot run on Simulator (no Screen
Time, and none of these apps are installed). Capture it on an iPhone with those
apps selected, save it as `raw/01-picker.png`, and `compose.swift` uses it for
slide 1 automatically. A recreated picker with those companies' icons would be a
screen the app never shows, carrying third-party trademarks, so it is not made here.

Caption 6 was "Streaks and a score you earn". The app computes a productivity
score internally but never shows it, so the caption would promise something
users cannot find.

## Recapturing

Every frame in `raw/` is a real Simulator capture from a DEBUG build on an
iPhone 17 Pro Max, with a clean status bar:

```bash
xcrun simctl status_bar booted override --operatorName " " --time 9:41 \
  --wifiBars 3 --cellularBars 4 --batteryState charged --batteryLevel 100
```

Launch arguments, all DEBUG-only:

- **1 and 2 (block screens):** `NoFeedUITestBypassScreenTime NoFeedPreviewBlockScreen <App>`,
  saved as `raw/01-door-<App>.png` (and `raw/01-block.png` for Instagram). Add
  `NoFeedPreviewClock 9:24` and set the status bar to `--time 9:24`, so the screen
  says "Opens at 9:40 AM" whenever it is captured; the countdown stays real.
  Slide 1's phone is `raw/01-session.png`, a session started from the Focus tab
  with the same status-bar time.
  iOS draws the real shield and the Simulator cannot raise one, so this shows the
  extension's own text. Set the status-bar time to now: the screen quotes the real
  clock ("Opens at …").
- **3 (Lock Screen):** start a session, press Lock twice, then capture. Leave
  `--time` out of the override, or the Lock Screen shows the wrong date. The big
  clock and the "until" time are the Mac's real clock, so capture during the day.
- **4, 5, 6:** `NoFeedUITestBypassScreenTime NoFeedUITestResetSession
  NoFeedUITestResetProfiles NoFeedUITestSkipOnboarding NoFeedUITestResetHistory
  NoFeedSeedDemoHistory NoFeedSeedPlainNotes NoFeedUITestResetSchedules
  NoFeedSeedDemoSchedule`, then open Focus, Schedule, and Insights › See all sessions.

Add `-AppleLanguages "(de)" -AppleLocale de_DE` for another language, then edit the
captions in `compose.swift` and run it:

```bash
cd docs/marketing/appstore && swift compose.swift
```
