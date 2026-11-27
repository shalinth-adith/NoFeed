# Test: phase 3 (mindful pause)

Run on a real iPhone with Screen Time access granted. The Simulator never draws
the block screen, so none of this can be seen there.

Setup: Settings › Focus profiles › Work › Edit. Under **Block screen**, turn on
**Pause, don't block** and Save. The Profiles list should now read
"… · pauses" under Work. Leave Settings › Unlock window **off** for steps 1–7.

## The wait

1. **Start a Work session** and open a blocked app.
   **Expect** the usual block screen with a second button: **I still want it**.
2. **Tap I still want it.**
   **Expect** the screen to stay up, now saying "Take a breath. Ten seconds,
   then it's your call." with the button **Wait 10 seconds**.
3. **Tap the button again before ten seconds pass.**
   **Expect** nothing to open and the count to go down ("Wait 6 seconds").
   The count does not tick on its own; each tap redraws it.
4. **Wait out the ten seconds, then tap.**
   **Expect** "Still want it? It opens for 15 minutes, then closes again." and
   the button **Open for 15 minutes**.
5. **Tap Open for 15 minutes.**
   **Expect** the app to open and stay open. Every other blocked app opens too:
   a pass lifts everything, as the plain unlock button does.
6. **After 15 minutes** (give it a minute more), open a blocked app.
   **Expect** the block screen again, starting from **I still want it**.

## Walking away

7. Tap **I still want it**, then **Back to focus**. Open the app again.
   **Expect** the screen to start from **I still want it**, not mid-wait.
8. Tap **I still want it**, wait the ten seconds, then leave it for three
   minutes without tapping. Open the app again.
   **Expect** it to start over from **I still want it**. A finished wait lapses
   after two minutes.

## What must NOT offer a way out

9. **Strict wins.** In the editor, turn on **Hold me to it**.
   **Expect** Pause, don't block to switch itself off. Start a session.
   **Expect** a one-button block screen.
10. **A plain block alongside.** Turn pause back on for Work. Create a schedule
    for **Study** (not paused) covering now, and start a Work session.
    **Expect** a one-button block screen: the pass would lift Study's block,
    and Study did not agree to that. Turn on Settings › Unlock window.
    **Expect** the second button to come back, and the wait still applies.

## Counting

11. Open a blocked app once and go through the whole wait (steps 1–5).
    **Expect** Insights to count **one** reach for it, not one per tap.

## Schedules

12. Make a schedule that runs with Work, covering now, with the app closed.
    Open a blocked app. **Expect** the pause flow from step 1, even though no
    session has started in the app.
