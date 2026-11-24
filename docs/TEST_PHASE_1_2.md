# Test: phases 1 and 2 (focus score, daily limits)

Run on a real iPhone with Screen Time access granted. The Simulator never
counts app usage, so limits cannot fire there.

## Phase 1 — focus score

1. Open Insights and scroll below "Your week in review".
2. **Expect** a "Focus score" section with a number out of 100 and three rows:
   time toward your goal, days you focused, sessions you finished.
3. Finish a session, then reopen Insights. **Expect** "Sessions you finished"
   and "Time toward your goal" to rise.
4. With no sessions in the last 7 days, **expect** the section to be hidden.

## Phase 2 — daily limits

Setup: Schedule tab › Limits › Daily limits › New limit. Choose one app you
can open freely (for example Safari is not allowed, pick Photos or a game),
set **5 min**, Add limit.

1. **Limit fires.** Use the app for 5 minutes in total, in one go or several.
   **Expect** the block screen with "Today's limit is used up. It opens again
   tomorrow." The row in Daily limits turns red: "Used up today · 5 min a day".
2. **Other apps are untouched.** Apps not in the limit still open normally.
3. **Warning.** Edit the limit to 15 min. After 10 minutes of use **expect** a
   notification: "5 minutes left for today."
4. **Editing lifts it.** After a limit is used up, edit and save it. **Expect**
   the app to open again, with the count starting over.
5. **Switch off.** Turn the row's switch off. **Expect** no block, however long
   you use the app.
6. **Delete.** Delete a used-up limit. **Expect** the app to open immediately.
7. **Midnight.** Leave a limit used up overnight. **Expect** the app to open
   after midnight without opening NoFeed.
8. **Survives a kill.** Force-quit NoFeed, then use the limited app past its
   limit. **Expect** the block anyway (the monitor extension enforces it).
9. **With a session.** Start a focus session while a limit is used up, then end
   it. **Expect** the limited app to stay blocked after the session ends.

Report anything that differs, with the step number.
