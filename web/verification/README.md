# Historical verification record

The test scripts and preview images referenced below were removed during cleanup. This Markdown history is preserved. Immediately before cleanup, 54 Prolog tests, 66 isolated HTTP checks, and 6 calendar tests passed.

## Restored task-type dropdown - 2026-10-28

- Restored all 20 Prolog task types, profile attributes, editable duration defaults, and type/category labels on task cards. Quiz / exam review remains available as a type.
- Recovered test scripts into a temporary directory outside the project for verification: 54 Prolog tests, 66 HTTP checks, and 6 calendar tests passed. All 20 profiles were also submitted to an isolated server and checked for their category, priority, difficulty, energy, duration, and recommendation group.
- Browser verified cleaning and quiz-review submissions, hours conversion, preservation of custom durations on refresh, class editing, chosen work-time editing, and persistence through a page reload. No browser warnings or errors were reported. Tests used separate temporary data; actual saved tasks and classes were preserved.

# Implementation verification — 2026-10-26

- `../run.ps1 -Mode test`: **25 PlUnit tests passed** on the existing local SWI-Prolog runtime.
- `../smoke.ps1`: **23 HTTP integration checks passed**, using isolated temporary data and a separate server port. Includes startup, 120 system facts/20 types, example task groups, exact time fit, completion/reopening, validation failures, foreign-origin rejection, malformed JSON, invalid query handling, deletion, static HTML serving, and persistence across a real process restart.
- In-app browser: added the document's three example tasks through the forms and verified Do First / Do Next / Do Later; added Monday Computer Networks 08:00–10:00; reloaded and verified records remained; completed/reopened reading; changed available time to 15 minutes and verified tasks remained visible with “Needs more time.”
- Browser error/warning log: no entries during the checked workflow.
- Desktop layout inspected. At the 390 × 844 mobile viewport, measured document content width equaled client width (375 CSS pixels after the scrollbar); no horizontal overflow. Temporary viewport override reset afterward.
- `example-desktop.png` and `example-mobile.png` show the temporary records from the supplied specification. These are verification examples, not seeded user data. They were removed after verification.

The original command-line sources were retained. The web app intentionally stores classes without allocating tasks into calendar slots, following the document's first-version scope.

## Weekday checkboxes — 2026-10-28

- Replaced the class weekday dropdown with seven labeled checkboxes. One submission saves the class on every selected day in a single transaction; the single-day API remains supported.
- **31 PlUnit tests and 29 HTTP checks passed**, including multiple-day persistence, empty/repeated/invalid selections, and rollback when a selected occurrence already exists.
- Browser verified Monday/Wednesday/Friday can be checked together and submitting with no checked days displays a validation message. Saved tasks and classes were preserved.

## Clickable task calendar — 2026-10-28

- Added a monthly calendar with deadline counts, selected-date task details, previous/next month, Today, and next-upcoming-deadline controls. The calendar uses saved due dates and displays completed records separately.
- **6 calendar tests passed** with Node's built-in runner: Monday-first grids, adjoining dates, leap years, month/year navigation, exact due-date filtering, and display independent of the computer timezone. The existing **29 HTTP checks also passed** after this UI change.
- Browser verified selecting October 30 shows the saved task due that day; selecting Today shows its empty state; next/previous month and the next-deadline shortcut update the selected date correctly.
- At 390px and 1280px viewports, document content width equaled client width (375px and 1265px with scrollbars). Phone view stacks task details below the month; desktop places them alongside it. Saved records were not changed.

## Prolog time allocation and chronological timeline — 2026-10-28

- Added `scheduler.pl`: finds vacant intervals around recurring classes, allocates outstanding task duration before exact deadlines, splits work across periods/dates, and returns one sorted daily sequence of classes, work suggestions, and remaining free time.
- Added optional subject and exact finish-before time, minutes/hours input, and persistent editable planning hours defaulting to the user's **8 AM–10 PM** choice. Legacy saved records remain supported.
- **51 PlUnit tests, 47 HTTP integration checks, and 6 calendar date tests passed.** The tests reproduce class 08–09, class 09–10, review 10–11, class 11–12, and remaining review 12–14 for a three-hour requirement. They also check overlapping classes, deadline clipping, shortage reporting, and persistence of preferences/options.
- Read-only browser verification on the live data showed classes and work interleaved in start-time order, the Hours option for exam review, and the 8 AM–10 PM preference controls. Mobile (390px) and desktop (1280px) had no horizontal overflow. No JavaScript errors/warnings were observed.
- The live saved counts remained five tasks and four classes through the server update. Existing unsaved class-form entries were restored after reloading the page for verification.
- Plans are recalculated suggestions over a 90-day horizon; viewing a session or reaching its end does not automatically complete a task. Existing PDF explanations are snapshots of the code before this scheduler enhancement.
## Editable schedules — 2026-10-28

- 54 Prolog tests, 66 isolated HTTP integration checks, 6 calendar tests passed.
- Tested exact-date task/review creation, class edits retaining IDs, fixed-session replacement without duplication, deadline/class/session/total-work conflicts, planning-hour conflict rejection, restart persistence, and returning to automatic scheduling.
- Live browser: quiz checkbox updates the duration label, class and work editors open with existing values, and work editor fits a 390px viewport. Existing production records were not modified during browser checks; unfinished form entries were restored after reloading.
- Work editor screenshot: `C:\Users\kyel\.codex\visualizations\2026\10\26\01a17724-0765-7331-9408-73090a7f082c\edit-work-time.png`.
