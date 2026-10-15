# NoFeed 2.3 — UI/UX, accessibility and acceptance review

**Date:** 2026-10-16 · **Build:** 2.3 (1) at commit `a1b33b4` + review tooling · **Reviewer:** Claude (automated walkthrough + heuristic review)

## Scope and method

No real users took part. This is an expert walkthrough standing in for user testing, with three lenses:

1. **Acceptance walkthrough as three personas** — a first-launch user who declines Screen Time, a returning user with a week of history, and an assistive-technology user (largest text size, VoiceOver semantics).
2. **Apple's automated accessibility audit** (`XCUIApplication.performAccessibilityAudit`) run on **24 screens** via a new UI test, `NoFeedUITests/AccessibilityAudit.swift`. Raw findings per screen are in `light/a11y/*.txt`.
3. **Heuristic UI review** of every screen in light, dark, and at the largest accessibility text size.

Screen Time itself cannot run on the Simulator, so the block screen and "app paused" screen were rendered through the app's own preview arguments. Devices: iPhone 17 Pro (light), iPhone 17 Pro Max (dark, session screens), iPhone Air (dark, onboarding; largest text size).

Screenshot folders: `light/` (automated tours; files from the Pro Max are dark), `light/a11y/` (one per audited screen), `manual/` (first-run walkthrough, dark), `xxxl/` (largest accessibility text size).

---

## Scorecard

| Area | Verdict |
|---|---|
| Visual design and tone | Strong. Calm, consistent "Quiet" language on every custom screen. Copy is unusually good. |
| Core loop (pick → focus → hold to end → summary) | Works end to end, clear, no dead ends. |
| First-run honesty | **Weak.** Onboarding says "You're all set" after the user skips the one permission the app needs; promises badges that do not exist. |
| Dynamic Type | **Fails.** Every custom screen ignores the user's text size; only Settings scales. 250 audit findings. |
| Colour contrast | **Fails on secondary text.** 100 hard failures, 82 borderline, all on the 30–55% ink used for captions, eyebrows and axis labels. |
| Touch targets | 29 undersized targets, mostly text buttons in navigation bars and the Schedule week strip. |
| Information architecture | One notable duplication: profiles are managed from two tabs. |

---

## Findings

Severity: **Critical** blocks a class of users · **High** confuses or misleads most users · **Medium** friction or inconsistency · **Low** polish.

### Critical

**C1 · Custom screens ignore Dynamic Type entirely.**
At the largest accessibility size, Home, Session, Insights, Schedule, the editors, the block screen and onboarding render pixel-identical to the default size, while Settings grows as expected. Compare `xxxl/01-home-xxxl.png` (unchanged) with `xxxl/22-settings-xxxl.png` (scaled). The audit flags 250 "Dynamic Type font sizes are unsupported" elements across 24 screens.
*Cause:* `ZTheme.Font` builds every font with `.system(size:)` and no `relativeTo:` text style.
*Fix:* give each `ZTheme.Font` helper a text style to scale relative to (`Font.system(size:weight:design:).relativeTo` via `@ScaledMetric` or `Font.custom(_:size:relativeTo:)`), then cap the hero numerals with `.dynamicTypeSize(...DynamicTypeSize.accessibility2)` where layout cannot flex. Retest with `xcrun simctl ui <sim> content_size accessibility-extra-extra-extra-large`.

### High

**H1 · "You're all set" after skipping Screen Time.**
`manual/00-onboarding-4-permission-dark.png` → tap *Maybe later* → `manual/00-onboarding-5-all-set-dark.png`. The final page celebrates completion, but the app cannot block anything; Home then shows a disabled *Begin focus* under a permission card (`manual/01-home-no-permission-dark.png`).
*Fix:* branch the last page on `authorization.isAuthorized`: "Almost there — grant Screen Time to start blocking" with the grant button, and only say "all set" when it is true.

**H2 · Secondary text fails contrast across the app.**
The audit records 100 hard contrast failures and 82 "nearly passed". They are all the same token: `ZTheme.Palette.text(0.30)` / `text(0.55)` used for eyebrows (`HISTORY`, `FOCUSING · WORK`, `MINUTES`), captions (`Demo · Notes`, `Ended early`), chart day letters, and helper text in editors. Examples: `light/a11y/05-insights-top.txt`, `16-schedule-editor.txt`, `20c-profile-edit.txt`.
*Fix:* raise the floor. 0.30 → 0.55 for anything that carries information (eyebrows, captions, axis labels), keep 0.30 only for purely decorative hairlines. A 4.5:1 ratio on the cream background needs roughly 0.62 opacity of the ink colour; on the dark canvas roughly 0.58.

**H3 · Schedule editor opens with the keyboard over the two required fields.**
`light/16-new-schedule-live.png`: a new schedule focuses the optional Title field; the keyboard then hides Days and Profile, the only things the form actually needs. The helper even says "a title was never needed". The same thing broke the UI test until it learned to dismiss the keyboard.
*Fix:* do not auto-focus the title on a new schedule. Let the user tap into it.

**H4 · Two permission prompts back to back on first landing.**
After onboarding, Home immediately raises the system notifications prompt (`manual/01-home-first-landing-notification-prompt-dark.png`), seconds after the Screen Time prompt, with no explanation of what notifications are for.
*Fix:* defer the request until the first session is started (its end-of-session alert is the first real reason), and precede it with one line of in-app rationale.

### Medium

**M1 · Promises that point at nothing.**
Onboarding page 3 says "unlock badges" (`manual/00-onboarding-3-habit-dark.png`); there is no badges screen. Settings › Daily Goals footer says "shown as progress orbs on Insights" (`manual/22-settings-top-dark.png`); Insights draws bars, not orbs. The *Streak goal* stepper changes nothing anywhere. The daily 9 am "New daily challenge — open NoFeed to see today's focus challenge" notification opens an app with no challenge screen.
*Fix:* rewrite the onboarding line to what exists (streaks, recap), delete the footer sentence, remove the streak-goal stepper or make Insights use it, and remove the challenge notification until a challenge screen ships.

**M2 · Dark-mode bar chart is nearly invisible.**
`manual/05-insights-xxxl.png` (dark): six of seven bars sit at ~3.5% white on near-black and read as empty; only today's bar is visible. The recap chart has the same fill. In light mode the bars are fine.
*Fix:* raise the dark "raise" fill for chart bars to ~12% white, or give non-today bars a 1pt stroke.

**M3 · Profiles are managed from two places.**
The Schedule tab carries a "Profiles" section with *New profile* (`manual/14-schedule-empty-dark.png`), and Settings › Focus profiles is the full list. A profile created from the Schedule tab lands in a list the user reaches from Settings. The App Review notes say the picker lives in the profile editor and schedule editor, which is a third framing.
*Fix:* keep one home. Either the Schedule tab's section links to the same Profiles list, or it goes and the schedule editor's profile picker gets an inline "New profile".

**M4 · Strict-mode copy is now untrue.**
Profile editor: "Hold me to it — No early exit once a session starts" (`light/20c-profile-edit.png`). Since 2.3 a strict session *can* be ended by a 60-second hold.
*Fix:* "Ending early takes a full minute's hold."

**M5 · Undersized tap targets.**
Audit: 29 elements under 44 pt, including *Maybe later* (onboarding), *That's all for now* (ended-early), *Edit*, *Save*, *Cancel*, *Reorder*, *Delete profile*, and the seven dates in the Schedule week strip (`light/a11y/14-schedule.txt`, `20b-profile-detail.txt`).
*Fix:* `.frame(minHeight: 44)` plus `.contentShape(Rectangle())` on text buttons; if the week-strip dates are not tappable, mark them `.accessibilityHidden(true)` so they are not offered as targets at all.

**M6 · Delete-profile sheet clips its own text.**
Audit flags "Text clipped" on `Delete "Work"?`, *Delete profile* and *Keep it*, plus four "potentially inaccessible text" nodes on the same sheet (`light/a11y/20-delete-sheet.txt`). Also "7 seconds focused" on the ended-early screen and *Streak goal* in Settings.
*Fix:* allow these labels to wrap (`.fixedSize(horizontal: false, vertical: true)`, no `lineLimit(1)`) and let the sheet grow with its content.

**M7 · Two visual languages.**
Settings is a stock grouped `Form` (`manual/22-settings-top-dark.png`); every other screen is the flat "Quiet" row system. The switch is jarring and is also why Settings is the only screen that scales text.
*Fix:* either port Settings to `QuietForm` rows or accept it as the system-styled screen and say so in the design notes. Fixing C1 removes the strongest reason to notice.

**M8 · Session-detail icon has no readable label.**
Audit: `hand.tap.fill` is exposed to VoiceOver by its symbol name (`light/a11y/08b-session-detail.txt`).
*Fix:* `.accessibilityLabel("Reached for a blocked app")` or `.accessibilityHidden(true)`.

### Low

- **L1 · Abandoned permission flow restarts onboarding from page 1.** Backing out of the system passcode sheet and relaunching lands on "Welcome" again rather than the permission page. Remember the page index.
- **L2 · "0 min · Ended early" rows.** A session abandoned after 14 seconds shows as "0 min" on Insights (`manual/05-insights-xxxl.png`). Show seconds under a minute, or omit minutes for ended-early rows.
- **L3 · "+6.9 h vs last week" on a first week.** Insights compares against a week that never happened; the recap already handles this with "Your first week". Reuse that rule.
- **L4 · Destructive action in amber.** *Delete profile* is drawn in the warning tone (`light/20b-profile-detail.png`). iOS users read red as destructive; amber reads as caution.
- **L5 · A profile saved "without blocking" is indistinguishable afterwards.** `light/12-couldnt-save.png` offers it; the list row then shows nothing about it blocking nothing. Add a "Blocks nothing yet" subtitle.
- **L6 · Dead space on tall phones.** Home leaves ~40% of the screen empty between the profile row and the orb on the iPhone Air (`manual/01-home-dark.png`). Consider letting the orb sit higher and the streak footer carry more.
- **L7 · About has no privacy policy or support link.** Both exist on the website; the app only has *Send feedback*.
- **L8 · Disabled primary button with no inline reason.** Home's *Begin focus* is dimmed without permission; the reason sits in a card at the top, not next to the button. A one-line caption under the button ("Grant Screen Time to begin") would close the loop.

---

## Accessibility audit totals (24 screens)

| Finding | Count | Where |
|---|---|---|
| Dynamic Type unsupported | 250 | every custom screen |
| Contrast failed | 100 | secondary text, chart labels, eyebrows |
| Contrast nearly passed | 82 | same tokens, larger sizes |
| Hit area too small | 29 | nav-bar text buttons, week strip, *Maybe later*, *That's all for now* |
| Potentially inaccessible text | 6 | delete sheet, Settings |
| Text clipped | 5 | delete sheet, ended-early, Settings |
| Dynamic Type partially unsupported | 5 | Settings footers |
| Label not human-readable | 1 | session detail icon |

Per-screen counts are in `light/a11y/SUMMARY.txt`. The audit is now a test (`AccessibilityAudit`); re-run it after fixes with:

```bash
TEST_RUNNER_QUIET_SHOT_DIR=/tmp/a11y xcodebuild test -project NoFeed.xcodeproj -scheme NoFeed \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:NoFeedUITests/AccessibilityAudit
```

---

## Persona walkthroughs

**First launch, declines Screen Time.** Reads five pages (good pacing, strong copy), skips the permission, is told "You're all set", lands on a Home with a disabled button and a notifications prompt on top. Insights and Schedule each repeat the permission ask in their own words. Verdict: the app is honest everywhere except the one place that matters, the last onboarding page.

**Returning user, a week of history.** Home shows streak and today's minutes; Begin focus → session → pause/resume → hold to end all behave. The completed summary asks "How did it feel?" with three chips and offers a break; the ended-early screen refuses to scold and offers a shorter try. Insights carries the week, the reflect card, the recap link and goals. Verdict: the loop is complete and pleasant. The only trip-ups are the schedule editor's keyboard and the near-invisible dark chart.

**Assistive-technology user.** Sets the largest text and finds only Settings responds. VoiceOver labels are good on Home, Insights and the editors (the earlier inventory counted ~100 explicit labels), but text buttons are small, the delete sheet clips, and one icon reads as "hand tap fill". Verdict: blocked by C1; the rest is a day's work.

---

## What is working well

- Copy throughout is specific and humane ("Held for you. Nothing is blocked while you're away", "Some days that's what there is").
- The hold-to-end control is the right gate: impossible by accident, no dialog.
- The "Couldn't save" sheet (`light/12-couldnt-save.png`) is a model error state: says why, keeps the input, offers both exits.
- The running-profile delete refusal (`light/21-profiles-cant-delete.png`) explains itself in place with a way out.
- The schedule clash panel names the conflict and offers two one-tap repairs.
- Dark mode is first-class on every custom screen; the "Quiet" tone system holds together.

---

## Suggested order of work

1. C1 Dynamic Type (one file, `NoFeedTheme.swift`, then layout checks).
2. H2 contrast floor (same file, two numbers).
3. H1 and M1 honesty fixes (onboarding last page, Settings footer, badges line, challenge notification).
4. H3 schedule editor focus, H4 notification timing.
5. M5 tap targets, M6 clipping, M8 icon label.
6. M2 dark chart, M3 profile entry points, M4 strict copy.
7. Lows as time allows.

Re-run `AccessibilityAudit` and the screenshot tours after 1–2; the counts in the table above are the baseline.


---

## After the fixes (2026-10-16, same day)

Every finding above was acted on in the commits that follow this report. Status per item:

| ID | Status | What changed |
|---|---|---|
| C1 | Fixed | `ZTheme.Font` now builds every font with `Font.custom(_:size:relativeTo:)` on the system face, so SwiftUI tracks the text size; growth is capped at the first accessibility step on the app root so the fixed compositions still fit. Home, Session and the ended-early screen verified at the largest size (`after/*-xxxl-after.png`). |
| H1 | Fixed | The last onboarding page branches: "Almost there" with a grant button and "Continue without blocking" when Screen Time was skipped. |
| H2 | Fixed | `ZTheme.Palette.text` applies a floor: 30% → 66%, 55% → 72%. Hard contrast failures 100 → 36 (the rest are tone-coloured accents and the app-paused screen's preview copy). |
| H3 | Fixed | The schedule editor no longer focuses the title on open. |
| H4 | Fixed | Notifications are requested at the first session start, after a one-line alert explaining what they are for. |
| M1 | Fixed | Onboarding promises streaks and the recap; the Settings footer says "weekly progress bars"; the streak-goal stepper is gone; the daily challenge notification is cancelled on every launch. |
| M2 | Fixed | New `chartBar` token at 14% white in dark (9% black in light) for the Insights and recap charts. |
| M3 | Fixed | The Schedule tab's Profiles section gains an "All profiles" row that opens the same list Settings does. |
| M4 | Fixed | All three strict-mode subtitles read "Ending early takes a full minute's hold". |
| M5 | Mostly fixed | 44pt targets on Maybe later, That's all for now, Profiles/Settings back, Edit, Reorder, Cancel, Save, Delete profile; the week strip is one element. 29 → 12 remaining, all unlabeled system elements inside the Profiles list. |
| M6 | Fixed | The delete sheet sizes itself to its content; the ended-early clock scales down before clipping. |
| M7 | Documented | Settings stays on the system grouped Form on purpose; the reasoning is in the file header. |
| M8 | Fixed | The session-detail icon is hidden from VoiceOver. |
| L1 | Fixed | Onboarding remembers its page across a relaunch. |
| L2 | Fixed | Sessions under a minute read "under a minute". |
| L3 | Fixed | A first week reads "Your first week" instead of a delta. |
| L4 | Fixed | Delete profile uses the alert tone, not the warning one. |
| L5 | Fixed | A profile that blocks nothing says "blocks nothing yet" in the list. |
| L6 | Fixed | The spacer above the orb is capped so it sits nearer the profile row. |
| L7 | Fixed | About has Privacy policy and Support links. |
| L8 | Fixed | A caption under the dimmed Begin focus says why. |

### Audit, before and after

| Finding | Before | After |
|---|---|---|
| Dynamic Type unsupported | 250 | 1 |
| Dynamic Type partially unsupported | 5 | 181 (the deliberate cap; text grows to accessibility 1 and stops) |
| Contrast failed | 100 | 36 |
| Contrast nearly passed | 82 | 11 |
| Hit area too small | 29 | 12 |
| Text clipped | 5 | 11 (buttons at the capped size; see below) |
| Potentially inaccessible text | 6 | 5 |
| Label not human-readable | 1 | 0 |
| **Total** | **478** | **257** |

What remains, and why: the "partially unsupported" entries are every text that stops growing at the cap, which is a trade the fixed layouts need. The 36 contrast failures are tone-coloured accents (periwinkle on cream) and the app-paused preview copy. The 12 small targets are unlabeled elements the List exposes inside the Profiles screen. The clipped-text entries are CTA labels measured at the capped size ("Try a shorter one — 5 min", the delete sheet's buttons) and would need the buttons to wrap to two lines.

Every UI suite was re-run after the changes. Three tests were updated because they depended on behaviour the fixes removed: two typed into the schedule title without tapping it (the auto-focus is gone), and one asserted a "vs last week" delta on a first week.
