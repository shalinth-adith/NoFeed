# NoFeed — TestFlight Manual Test Plan

**How each test is written:** every case has a **Goal** (what you're proving), **Setup** (what to
have ready first), **Steps** (exactly what to tap, in order), **Expected** (what a pass looks
like), and a **Result** line to fill in.

> **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

- **Pass** — matched "Expected" exactly.
- **Fail** — write *what actually happened* + how to reproduce.
- **Blocked** — couldn't run (missing setup, e.g. no Spotify Premium).

Cases marked **⚠️** are high-risk regressions — always run these.

---

## Build & tester info

| Field | Value |
|---|---|
| Build / version (TestFlight) | _____________ |
| Device model | _____________ |
| iOS version | _____________ |
| Tester | _____________ |
| Date | _____________ |

---

## 0. One-time setup before you start

**Goal:** Get the phone into a known state so results are trustworthy.

**Steps:**
1. If a previous NoFeed build is installed and you want to test first-run (§1), **delete it**
   first: long-press the icon → Remove App → Delete App. *(Skip deletion if you only want to test
   the update path.)*
2. Install the build from **TestFlight**.
3. Open **Settings ▸ Notifications ▸ NoFeed** and make sure notifications are **Allowed** (needed
   for §4, §9).
4. Have at least one **social/entertainment app** installed (e.g. Instagram, YouTube) to use as a
   "blocked app" target.
5. Optional, only for those cases: a **Focus mode** you can toggle (§6.4), a **Spotify Premium**
   account (§11.4), a free gap on your **Calendar** today (§11.1).

**Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

---

## 1. Entry, Splash & Onboarding

### TC-1.1 Animated splash ⚠️
- **Goal:** First screen animates correctly and brands as "NoFeed".
- **Setup:** App freshly launched (from a cold start — swipe it out of the app switcher first).
- **Steps:**
  1. Tap the NoFeed icon to launch.
  2. Watch the opening screen without touching it.
- **Expected:** Deep-indigo background. Small distracting-app **chips scatter away**, a focus
  **ring draws in**, and a glowing **Focus Orb springs** from tiny to settled. The wordmark
  **"NoFeed"** and **"Find your focus."** appear, with a "Begin your focus session" line. It then
  crossfades smoothly into the app. **No white flash** at any point.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-1.2 Splash with Reduce Motion
- **Goal:** Animation respects the accessibility setting.
- **Setup:** iOS **Settings ▸ Accessibility ▸ Motion ▸ Reduce Motion = ON**.
- **Steps:**
  1. Force-quit NoFeed (swipe up in the app switcher).
  2. Relaunch it and watch the splash.
- **Expected:** You see the settled orb + "NoFeed / Find your focus." **without** the scatter /
  ring-draw / spring motion — a calm static screen, no looping animation.
- **After:** Turn Reduce Motion **OFF** again.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-1.3 First-run onboarding
- **Goal:** New users get the intro flow.
- **Setup:** App was deleted and freshly installed (see §0 step 1).
- **Steps:**
  1. Launch; let the splash finish.
  2. Read page 1, then **swipe left** to advance.
  3. On the next page, use the on-screen **button** (e.g. "Continue"/"Next") instead of swiping.
  4. Continue to the last page and tap the final button ("Get started"/"Done").
- **Expected:** A short multi-page intro (Welcome → Focus → Habit → Screen Time → Done). **Both**
  swiping and the buttons advance pages. The final page drops you into the app (Focus tab).
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-1.4 Screen Time permission prompt
- **Goal:** Granting Screen Time access works (this powers all blocking).
- **Setup:** During onboarding, on the "Screen Time Access" page.
- **Steps:**
  1. Tap **Grant** (or "Allow Access").
  2. In the system sheet that appears, approve with Face ID / passcode.
- **Expected:** The iOS Screen Time prompt appears; after approving, the page shows an
  **"Access Granted"** state. (Tapping "Maybe later" instead should skip without granting.)
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-1.5 Onboarding shows only once
- **Goal:** Returning users skip onboarding.
- **Setup:** You've completed onboarding at least once.
- **Steps:**
  1. Force-quit the app.
  2. Relaunch.
- **Expected:** After the splash it goes **straight to the Focus tab** — no onboarding again.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-1.6 No repeated Screen-Time prompt ⚠️
- **Goal:** The app doesn't nag for Screen Time on every launch (a known past bug).
- **Setup:** Screen Time already granted once.
- **Steps:**
  1. Open and close the app 3–4 times (force-quit between each).
- **Expected:** The system Screen Time prompt does **not** reappear on any later launch.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

---

## 2. Navigation & Tab Bar

### TC-2.1 Five tabs, single Liquid Glass bar
- **Goal:** Bottom navigation is correct and renders once.
- **Setup:** On the main app (past onboarding).
- **Steps:**
  1. Look at the bottom bar.
  2. Tap each tab: **Focus → Insights → Profiles → Schedules → Settings**.
- **Expected:** Exactly **one** translucent (Liquid Glass) bar with those 5 tabs. The selected tab
  is brand-tinted. **No second/duplicate bar**, and content isn't hidden behind the bar.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-2.2 Tab state is preserved
- **Goal:** Switching tabs doesn't reset your place.
- **Steps:**
  1. Go to **Insights**, scroll halfway down.
  2. Tap **Profiles**, then tap **Insights** again.
- **Expected:** Insights returns roughly where you left it (not jumped back to the top).
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

---

## 3. Core Blocking

> These are the heart of the app. Use a real distracting app (e.g. Instagram) as your target.

### TC-3.1 Block specific apps
- **Goal:** A chosen app gets shielded during focus.
- **Setup:**
  1. **Profiles** → open (or create) a profile → **Blocking**.
  2. Turn **"Block all apps" OFF**.
  3. Under the blocklist, pick one app (e.g. Instagram). Save. Make this profile **active**.
- **Steps:**
  1. Go to **Focus** → **Start Focus**.
  2. Leave NoFeed and open the blocked app (Instagram).
- **Expected:** Instead of the app, **NoFeed's custom shield** appears over it.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-3.2 Block all apps
- **Goal:** "Block everything" mode shields all non-essential apps.
- **Setup:** Active profile with **"Block all apps" ON** (the default).
- **Steps:**
  1. **Start Focus**.
  2. Try opening several apps and **Safari**.
  3. Also try **Phone, Messages, Settings, and NoFeed**.
- **Expected:** All the normal apps are shielded; **Phone, Messages, Settings, and NoFeed stay
  usable**.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-3.3 Allowed apps stay open
- **Goal:** An allow-listed app is reachable even in block-all mode.
- **Setup:** Profile with **Block-all ON**, and one app added under **Allowed apps**
  (Profiles → profile → Blocking → Allowed).
- **Steps:**
  1. Start Focus.
  2. Open the allowed app; then try a different, non-allowed app.
- **Expected:** The allowed app **opens normally**; the other one is blocked.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-3.4 Research mode — website allowlist
- **Goal:** Only whitelisted sites load in Safari during focus.
- **Setup:** Profile → **Research mode — allowed websites** = `claude.ai, docs.google.com`. Save,
  make active.
- **Steps:**
  1. Start Focus.
  2. Open **Safari**, visit `claude.ai` (allowed).
  3. Then visit an entertainment site, e.g. `youtube.com`.
- **Expected:** `claude.ai` loads; `youtube.com` is **blocked**; **Safari itself stays open** (only
  the pages are gated).
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-3.5 Custom shield message
- **Goal:** Your personal shield text shows on blocked apps.
- **Setup:** **Settings → Shield message** = e.g. "Future you will thank you". Save.
- **Steps:**
  1. Start Focus.
  2. Open a blocked app.
- **Expected:** The calm indigo shield shows **your message** (a sensible default appears if you
  left it empty).
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-3.6 Strict mode — end-early guard
- **Goal:** Strict mode makes quitting early deliberately hard.
- **Setup:** Profile with **Strict mode ON**, active. Start a session.
- **Steps:**
  1. In the running session, tap **End early**.
  2. Observe the confirmation sheet; try to confirm immediately.
- **Expected:** A confirmation sheet with a **5-second countdown** and a streak-loss warning; the
  **confirm button is disabled until the countdown finishes**, then it works.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-3.7 Stop blocking releases everything
- **Goal:** Ending a session fully unblocks apps and sites.
- **Steps:**
  1. During a session, end it (naturally or via End early).
  2. Open the apps and websites that were blocked.
- **Expected:** Everything opens **normally** again — apps and Safari sites.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

---

## 4. Focus Sessions & Timer

### TC-4.1 Start a session
- **Goal:** A session starts with the timer + blocking + haptic.
- **Steps:**
  1. **Focus** tab → set a duration with **− / +**.
  2. Tap **Start Focus**.
- **Expected:** A full-screen session with a **countdown ring**; you feel a **start haptic**;
  blocking is now active (verify with §3 if unsure).
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-4.2 Adjust duration
- **Goal:** Duration control is bounded and profile-aware.
- **Steps:**
  1. On Focus, tap **−** and **+** repeatedly.
  2. Switch the active profile (top picker) and look at the duration.
- **Expected:** Minutes change in steps of **5**, clamped between **5 and 120**. Switching profiles
  resets the duration to that profile's default.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-4.3 Minimize & resume ⚠️
- **Goal:** A running session survives being minimized.
- **Steps:**
  1. Start a session.
  2. Tap the **▾ (minimize)** control.
  3. Browse other tabs (Insights, Profiles).
  4. Tap the **resume banner** (or the Dynamic Island) to reopen the timer.
- **Expected:** The timer keeps **running** while minimized; you can navigate the app; the banner /
  Island reopens the full session; **Start Focus is disabled** while a session is active.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-4.4 Session completes naturally
- **Goal:** Finishing a session celebrates and cleans up.
- **Setup:** Set duration to the **minimum (5 min)** to keep it short.
- **Steps:**
  1. Start Focus and let the timer run all the way to 0 (stay in-app).
- **Expected:** A celebration summary with **confetti + haptic**; a **"Focus complete"
  notification**; the shields **lift** (blocked apps open again).
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-4.5 Session records even if the app is killed ⚠️ CRITICAL
- **Goal:** A session isn't lost if iOS terminates the app mid-focus.
- **Setup:** Start a short session (5 min).
- **Steps:**
  1. Start Focus.
  2. Leave NoFeed and use other apps for the **full duration** (don't reopen NoFeed) so iOS
     background-terminates it.
  3. After the duration has passed, reopen NoFeed.
- **Expected:** The finished session is **still recorded** — today's focus minutes / streak went
  up, or a summary is shown. **It is not silently lost.**
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-4.6 End-early does NOT count toward streak
- **Goal:** Bailing out isn't rewarded.
- **Steps:**
  1. Note today's streak / minutes (Insights).
  2. Start a session, then **End early** (confirm through strict guard if on).
  3. Check Insights + History.
- **Expected:** The session is logged as **"ended early"** and does **not** add to your streak or
  today's minutes.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-4.7 Pomodoro break
- **Goal:** The break timer runs without blocking.
- **Setup:** Profile with a **non-zero break** length; active.
- **Steps:**
  1. Complete a focus session (§4.4).
  2. On the summary, tap **Take a break**.
  3. Try opening a normally-blocked app during the break.
- **Expected:** A break timer counts down with **no blocking** (apps open freely); a **"Break
  over" notification** fires when it ends.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-4.8 Rate & note a session
- **Goal:** Post-session review saves.
- **Steps:**
  1. On a completed session's summary, tap a **star rating**.
  2. Type a short **note**.
  3. Tap **Done**.
  4. Go to **Insights → History** and open that session.
- **Expected:** The rating + note are **saved** and shown in the session's History detail.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

---

## 5. Profiles

### TC-5.1 Default profiles exist
- **Goal:** New installs are seeded with starter profiles.
- **Setup:** Fresh install.
- **Steps:** Open the **Profiles** tab.
- **Expected:** **Work, Study, and Gym** profiles are present.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-5.2 Create / edit a profile
- **Goal:** A custom profile saves all its settings.
- **Steps:**
  1. **Profiles → +**.
  2. Set a **name**, pick an **icon** and **accent color**.
  3. Set a **blocklist**, **allowed apps**, **research sites**, **session length**, **break**, and
     **Strict mode**.
  4. Tap **Save**.
- **Expected:** The profile persists, appears in the Profiles list and the active-profile picker,
  with the chosen icon/accent.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-5.3 Delete needs confirmation
- **Goal:** You can't delete a profile by accident.
- **Steps:**
  1. **Swipe left** on a profile row.
  2. Tap **Delete**; read the confirmation; tap **Cancel** once, then repeat and **confirm**.
- **Expected:** A "Delete …?" confirmation shows each time. **Cancel keeps** it; confirming
  **removes** it.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-5.4 Empty-profiles guard
- **Goal:** No dead Start button when there are zero profiles.
- **Steps:**
  1. Delete **all** profiles.
  2. Go to the **Focus** tab.
- **Expected:** A **"No focus profiles — create one"** card (not a broken Start button).
- **After:** Recreate a profile so later tests work.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-5.5 Active profile drives the session
- **Goal:** Sessions honor the selected profile's rules.
- **Steps:**
  1. Make a specific profile **active**.
  2. Start Focus and check blocking behaviour.
- **Expected:** The session uses **that profile's** app selection, strict mode, block-all setting,
  and research sites.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

---

## 6. Schedules (automatic blocking windows)

### TC-6.1 Create a recurring schedule
- **Goal:** A schedule can be defined and listed.
- **Steps:**
  1. **Schedules → +**.
  2. Set a **title**, a **start/end time**, choose **weekdays**, and a blocking selection.
  3. Tap **Save**.
- **Expected:** It appears in the list with its **time range + weekday summary**, and has a toggle
  to enable/disable it.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-6.2 Blocks at the scheduled time (long-running)
- **Goal:** Blocking turns on automatically inside the window — no manual start.
- **Setup:** Create a schedule whose window **includes right now** on **today's weekday**, at least
  ~15 minutes long. Enable it. Do **not** start a session manually.
- **Steps:**
  1. Wait until you're inside the window (a minute or two).
  2. Try opening a blocked app.
- **Expected:** Apps are **shielded automatically** during the window, without you starting a
  session.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-6.3 Weekday filtering
- **Goal:** Schedules only fire on their chosen days.
- **Setup:** A schedule set to weekdays that **exclude today**.
- **Steps:** During what would be its time window today, try a blocked app.
- **Expected:** **No blocking today** (wrong weekday).
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-6.4 Time-sensitive start reminder breaks through Focus ⚠️
- **Goal:** The ~1-minute-before reminder isn't silenced by an active Focus mode.
- **Setup:** Create a schedule that **starts a few minutes from now**. Turn ON a **Focus mode**
  (e.g. Do Not Disturb) on the phone.
- **Steps:**
  1. Lock the phone and wait until ~1 minute before the schedule's start.
- **Expected:** A reminder notification arrives **even though a Focus is on** (it's Time-Sensitive,
  so it punches through).
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-6.5 Dynamic Island start countdown ⚠️  (iPhone 14 Pro or newer)
- **Goal:** A live countdown appears before a schedule begins.
- **Setup:** NoFeed running (foreground or just backgrounded). A schedule starting within ~60s.
- **Steps:**
  1. As the start time nears (~1 min out), watch the **Dynamic Island**.
  2. **Swipe to the Home Screen** (background the app) and keep watching.
  3. Watch what happens exactly at the schedule's start time.
- **Expected:** An **"upcoming" pill** in the Dynamic Island counts down **0:59 → 0:00**, and
  **keeps ticking after you background the app**. At the start time it's **replaced by the running
  session's** Live Activity (you never see two stacked).
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-6.6 Smart schedule suggestions
- **Goal:** Suggested templates prefill the editor.
- **Steps:**
  1. **Schedules → Suggested**.
  2. Tap a card (e.g. **Deep Work**, **Evening Study**, **Digital Sunset**, or "Your focus hour").
- **Expected:** The schedule editor opens **pre-filled** with that suggestion's title, time, and
  weekdays.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-6.7 Delete a schedule (confirmation)
- **Goal:** Deleting a schedule is confirmed.
- **Steps:** Swipe left on a schedule → **Delete** → observe confirmation.
- **Expected:** A confirmation appears before it's removed.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

---

## 7. Insights & Analytics

### TC-7.1 Weekly focus chart
- **Goal:** The 7-day chart reflects real sessions.
- **Setup:** You've completed at least one session this week.
- **Steps:** Open **Insights**; look at the weekly focus chart.
- **Expected:** A **7-day bar chart**; the displayed weekly total matches the sum of the bars.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-7.2 Productivity score
- **Goal:** The score behaves sensibly.
- **Steps:** On Insights, find the productivity score.
- **Expected:** A number **0–100**; higher with more focus + consistency, lower with distractions.
  With no data it reads **0** (no blank/NaN/crash).
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-7.3 Distraction attempts
- **Goal:** Attempts to open blocked apps are counted.
- **Setup:** A session is running with real apps blocked.
- **Steps:**
  1. During the session, try opening a blocked app **3 times** (hit the shield each time).
  2. End the session, open **Insights**.
- **Expected:** The distraction count/chart **increased** (roughly 1 per open, de-duped). If it
  stays 0, note whether the shield actually appeared.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-7.4 App usage — per-app detail
- **Goal:** Screen-time breakdown shows real apps.
- **Steps:** **Insights → App usage** card.
- **Expected:** A total plus **top apps with icons and durations** (not just one grand total).
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-7.5 History list & detail
- **Goal:** Past sessions are browsable.
- **Steps:**
  1. **Insights → History**.
  2. Tap a session row.
- **Expected:** A list of past sessions (date, profile, duration, **completed vs ended-early**,
  rating, note); tapping opens a detail view with those fields.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-7.6 Daily Goals (orbs + adjustable targets)
- **Goal:** Goal progress and target editing work.
- **Steps:**
  1. **Insights → Daily Goals** card.
  2. In the detail, look at the three orbs, then use the **Adjust targets** steppers.
- **Expected:** Three progress **orbs** — **Focus minutes / Sessions / Streak** — each vs its
  target. Changing a target with the stepper updates the orb and **persists** (defaults: 120 min /
  3 sessions / 7-day streak).
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-7.7 Badges & Leaderboard
- **Goal:** Gamification screens render.
- **Steps:** **Insights → Badges**, then **Insights → Accountability** (leaderboard).
- **Expected:** A **badge grid** with earned badges highlighted; a leaderboard ranked by **this
  week's focus minutes** with **"You"** in it and an **"iCloud — coming soon"** note.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

---

## 8. Motivation & Gamification

### TC-8.1 First badge
- **Goal:** Completing your first session awards a badge.
- **Setup:** An account/install with **no** completed sessions yet.
- **Steps:** Complete one full session (§4.4).
- **Expected:** A **"First Focus"** badge is awarded — shown on the summary and in the Badges grid.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-8.2 Daily challenge — card & progress
- **Goal:** There's one challenge per day that tracks progress.
- **Steps:**
  1. On **Insights**, note today's challenge card and its progress.
  2. Complete a session, return to Insights.
- **Expected:** **One** challenge for the day (a minutes / sessions / or single-long-session
  goal); progress **advances** after a qualifying session; a **completion notification** fires when
  you meet it.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-8.3 Daily challenge — detail sheet
- **Goal:** The challenge card opens a full detail sheet.
- **Steps:** On Insights, **tap the challenge card**.
- **Expected:** A sheet titled **"Daily Challenge"** with a **Today** card: a progress bar, a **%**,
  an **"X of Y"** line, and a plain-language **explainer** of the challenge type. **Done** closes
  it.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-8.4 Daily challenge — completed history
- **Goal:** Finished challenges are remembered.
- **Steps:**
  1. Open the challenge detail sheet.
  2. Scroll to the **Completed** section.
- **Expected:** If you've completed challenges before, they list with **title + date + a teal
  check**. If none yet, a friendly **"No completed challenges yet"** empty state shows — **not a
  blank gap**.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-8.5 Ambient focus sounds
- **Goal:** Background sounds play/stop cleanly.
- **Steps:**
  1. **Focus → Focus sound**.
  2. Tap **White**, listen, tap it again to stop.
  3. Try **Pink**, **Brown**, **Rain** (and **Lo-fi** if present), switching between them.
- **Expected:** The chosen sound **plays and loops**; tapping the same one **stops** it; switching
  swaps cleanly with **no overlapping** audio.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-8.6 Daily goal card on Focus
- **Goal:** Today's goal progress is visible on the main screen.
- **Steps:**
  1. **Settings** → set a **Daily focus goal**.
  2. Go to **Focus** and check the goal card after some focus time.
- **Expected:** Progress = today's minutes vs the goal; a **"goal reached"** state at/over target.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

---

## 9. Notifications & Smart Nudges

> Tip: for time-based nudges, you can set the reminder time to a minute or two ahead to trigger
> them quickly, or verify wording when they arrive naturally.

### TC-9.1 Daily reminder — "start a session" flavour
- **Goal:** When you haven't focused today, the nudge encourages starting.
- **Setup:** No completed session **today**; daily reminder time reached.
- **Expected:** A daily reminder arrives worded to **start a session**.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-9.2 Daily reminder re-arms after you focus ⚠️
- **Goal:** The nudge adapts and doesn't go stale.
- **Steps:**
  1. Complete a session today.
  2. Bring NoFeed to the **foreground** (this re-arms the reminder).
  3. When the daily reminder later fires, read its wording.
- **Expected:** The reminder is **re-armed** and its message flips to a **"keep it up / break"**
  flavour (because you focused today) — not the "start a session" one. It should fire **once**, not
  as a stale duplicate.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-9.3 Break-over smart message
- **Goal:** The break-end nudge matches your day.
- **Steps:**
  1. After a focus session, start a **break** (§4.7).
  2. Let the break end.
- **Expected:** The **"Break over"** notification uses a **back-to-focus** message (since you've
  focused today).
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-9.4 Daily challenge morning reminder
- **Goal:** A morning nudge points to the new challenge.
- **Expected:** In the morning, a notification tells you a **fresh daily challenge** is waiting.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-9.5 Notifications denied — no crash
- **Goal:** Denying notifications degrades gracefully.
- **Setup:** iOS **Settings ▸ Notifications ▸ NoFeed ▸ Allow Notifications = OFF**.
- **Steps:** Complete a session.
- **Expected:** No crash; the in-app completion summary still shows (the app doesn't depend on the
  notification to function).
- **After:** Re-enable notifications.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

---

## 10. Widget & Live Activity

### TC-10.1 Home-screen widget
- **Goal:** The widget shows a live stat.
- **Steps:**
  1. Long-press the Home Screen → **+** → search **NoFeed** → add a widget.
  2. Long-press the widget → **Edit Widget** → pick a metric (streak / minutes / attempts).
  3. Complete a session and check the widget later.
- **Expected:** The widget shows the chosen stat and **updates** after sessions.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-10.2 Live Activity — Lock Screen
- **Goal:** A running session shows on the Lock Screen.
- **Steps:**
  1. Start a session.
  2. Lock the phone and look at the Lock Screen.
- **Expected:** A Lock-Screen banner with the **profile name + a live countdown**, tinted with the
  profile accent.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-10.3 Dynamic Island — running session  (iPhone 14 Pro+)
- **Goal:** The session lives in the Dynamic Island.
- **Steps:**
  1. Start a session, return to the Home Screen.
  2. Look at the compact pill; then **long-press** it.
  3. Let the session end.
- **Expected:** The compact pill **counts down**; long-press **expands** to profile + progress; the
  activity **disappears when the session ends** (no leftover pill).
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

---

## 11. Integrations

### TC-11.1 Calendar free-time
- **Goal:** A free calendar gap can launch a right-sized session.
- **Setup:** Grant Calendar access; have a **free gap** on today's calendar.
- **Steps:**
  1. On **Focus**, find the calendar/free-time card.
  2. Tap it.
- **Expected:** A **"Free until X — start focus now"** card; tapping starts a session **sized to
  the gap**.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-11.2 Tasks + Reminders
- **Goal:** The task list works and syncs with Reminders.
- **Steps:**
  1. **Focus** toolbar → **Tasks**.
  2. **Add** a task, **complete** one, **delete** one.
  3. Tap **Import from Reminders**; then export a task back to Reminders.
- **Expected:** Tasks **persist**; import pulls in your **incomplete** reminders; export creates a
  reminder in the Reminders app.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-11.3 Apple Music
- **Goal:** In-app transport controls the system player.
- **Steps:**
  1. **Settings → Music → Apple Music**.
  2. On **Focus**, use the music row: **play / pause / next**.
- **Expected:** Controls drive the system Music player; the **now-playing title** shows.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-11.4 Spotify  (requires Premium)
- **Goal:** Spotify connect + control works.
- **Setup:** Spotify app installed, **Premium**, redirect URI `zenly://spotify-callback`
  registered.
- **Steps:**
  1. **Settings → Music → Spotify → Connect**.
  2. Authorize in Spotify, then return to NoFeed.
  3. Use the Focus music row: play / pause / next.
- **Expected:** You return to NoFeed; **play/pause/next control Spotify**. *(Free account: it may
  connect but controls do nothing — that's expected; mark Blocked.)*
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-11.5 Focus filter
- **Goal:** An iOS Focus can switch NoFeed's profile.
- **Steps:**
  1. iOS **Settings → Focus →** choose a Focus **→ Focus Filters → add NoFeed**, pick a profile.
  2. Turn that Focus **on**, then open NoFeed.
- **Expected:** NoFeed switches to the chosen profile on next open.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-11.6 Permission-denied states
- **Goal:** Denied Calendar/Reminders shows a helpful message, not a dead button.
- **Setup:** In iOS Settings, **deny** Calendar or Reminders for NoFeed.
- **Steps:** Open the related area in NoFeed (Settings/Tasks/Calendar card).
- **Expected:** A message like **"access denied — enable in Settings app"** — no dead Connect
  button, no crash.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

---

## 12. Start Focus from Elsewhere

### TC-12.1 Siri / Shortcuts
- **Goal:** Voice / Shortcuts can start a session.
- **Steps:** Say **"Hey Siri, start a focus session in NoFeed"** (or run it from the Shortcuts app).
- **Expected:** NoFeed opens and a session starts using the **active profile**.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-12.2 Control Center  (iOS 18+)
- **Goal:** A Control Center tile starts focus.
- **Steps:**
  1. Edit Control Center → add the **"Start Focus"** control.
  2. Open Control Center and tap it.
- **Expected:** NoFeed opens and starts a session.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

---

## 13. Settings & Persistence

### TC-13.1 Settings persist across relaunch
- **Goal:** Nothing you set is lost on restart.
- **Steps:**
  1. Change: **shield message**, **daily goal**, **reminder time**, **music source**.
  2. Force-quit and reopen the app.
- **Expected:** Every value is **exactly as you left it**.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-13.2 Settings screen sanity
- **Goal:** No broken rows.
- **Steps:** Scroll the whole **Settings** screen; toggle a few switches/steppers.
- **Expected:** No clipped text, no dead links; every control responds.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

---

## 14. Accessibility & Visual Polish

### TC-14.1 VoiceOver
- **Goal:** The app is usable with VoiceOver.
- **Setup:** iOS **Settings ▸ Accessibility ▸ VoiceOver = ON** (triple-click side button to toggle).
- **Steps:** Swipe through the **splash**, **Focus**, a **session**, and a **summary**.
- **Expected:** Splash announces **"NoFeed. Find your focus."**; the music buttons announce
  Previous / Play-Pause / Next; **− / +** announce the duration; Tasks, minimize, resume, the star
  rating, and the profile icon/accent pickers are **labeled buttons that announce their selected
  state**.
- **After:** Turn VoiceOver off.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-14.2 Largest text size
- **Goal:** Big text doesn't break layouts.
- **Setup:** **Settings ▸ Accessibility ▸ Display & Text Size ▸ Larger Text** → drag to max.
- **Steps:** Visit Focus, Insights, Profiles, a session.
- **Expected:** Text **scales** without clipping or overlapping.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-14.3 Readability on the dark theme
- **Goal:** Nothing is invisible on the indigo background.
- **Steps:** Scan every main screen.
- **Expected:** All text readable (no white-on-white or invisible glass text); progress bars/orbs
  are clearly visible.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

### TC-14.4 Safe areas (notch / Island / home indicator)
- **Goal:** No content hidden by hardware cutouts.
- **Steps:** Check the top and bottom of each main screen and the full-screen session.
- **Expected:** Nothing is clipped under the notch, Dynamic Island, or home indicator.
- **Result:** ⬜ Pass  ⬜ Fail  ⬜ Blocked — **Notes:** ____________________

---

## 15. Known limitations — do NOT report these as bugs

- Streak counts **completed** focus sessions only, **by day** (not per session).
- Spotify playback control requires **Premium**.
- Friend leaderboards are **local** until iCloud/CloudKit + GameKit are enabled.
- Rain sound is synthesized (always available); **Lo-fi** needs a bundled audio file.
- Per-app usage names/icons render via Apple privacy tokens — raw app names aren't shown as text.

---

## Reviewer sign-off summary

Fill in after the pass so the review is scannable.

| Section | Cases | Pass | Fail | Blocked |
|---|---|---|---|---|
| 1. Entry / Splash / Onboarding | 6 | | | |
| 2. Navigation & Tab Bar | 2 | | | |
| 3. Core Blocking | 7 | | | |
| 4. Sessions & Timer | 8 | | | |
| 5. Profiles | 5 | | | |
| 6. Schedules | 7 | | | |
| 7. Insights & Analytics | 7 | | | |
| 8. Motivation & Gamification | 6 | | | |
| 9. Notifications & Smart Nudges | 5 | | | |
| 10. Widget & Live Activity | 3 | | | |
| 11. Integrations | 6 | | | |
| 12. Start Focus from Elsewhere | 2 | | | |
| 13. Settings & Persistence | 2 | | | |
| 14. Accessibility & Visual Polish | 4 | | | |
| **Total** | **70** | | | |

**Blocker / critical bugs (must fix before release):**
1. ____________________
2. ____________________

**Minor issues / polish:**
1. ____________________
2. ____________________

**Overall verdict:** ⬜ Ship  ⬜ Ship after minor fixes  ⬜ Do not ship (blockers)

**Tester:** _____________   **Date:** _____________
