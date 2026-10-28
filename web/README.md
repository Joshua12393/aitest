# Adaptive goal planning and task recommendations

Implements the supplied [project specification](https://docs.google.com/document/d/1D4yVbV8IE8FvtKM-OYQGBU2uJfAmmbWu0v10NXm1Rx0/edit) as a local HTML application with a real SWI-Prolog HTTP backend.

## Run

From PowerShell in this directory:

```powershell
.\run.ps1
```

Open http://localhost:8080. Use `-Port 8081` for another port. Ctrl+C stops the server. The launcher reuses the runtime already present under `../task_planner/.tools/swipl/bin/`, or uses an installed `swipl` on PATH. It works from other working directories too. With SWI-Prolog on PATH, `swipl -q server.pl 8080` also works. No Node, external packages, API keys, internet connection, or build step is required.

## What is implemented

- Task form: title, a dropdown with all 20 task types, optional subject, exact deadline date/time, and required work time in minutes or hours. Selecting a type shows its category, priority, difficulty, energy, and typical duration from the Prolog knowledge base; the suggested duration can be changed. Quiz / exam review is a dropdown option and uses the review-time label. The deadline time remains explicitly editable.
- Class form: weekday checkboxes, subject, start/end time, including minute precision. Select multiple days to save the same class on each day in one action. If any selected entry is invalid or already saved, the whole addition is rejected.
- **Do First:** pending tasks due in 2 days or less, including today and overdue work.
- **Do Next:** pending tasks due in 3–5 days.
- **Do Later:** pending tasks due after 5 days.
- Complete, reopen, and delete tasks; delete saved classes.
- Monthly calendar with a chronological daily timeline: weekly classes, Prolog-suggested task sessions, and remaining vacant periods interleave by start time. Due-task details remain available below the timeline. Calendar dots distinguish class days and planned work.
- Editable planning hours, defaulting to **8 AM–10 PM**, saved locally. Prolog splits long work across vacant periods and days, avoids classes and other allocated tasks, stops at the exact deadline, and reports any minutes it cannot place.
- Type-based default estimates, category, priority, difficulty, energy, and explanations.
- Optional available-time badges. Longer tasks stay visible in their deadline group.
- Blank initial user data. Every displayed task/class comes from user input.
- Automatically saved local JSON, validated on loading and restored at startup.
- Responsive layout, labeled controls, escaped user text, and accessible status messages.

The current version extends the document's first version with automatic time suggestions, as requested. A deadline is required. This is a single local planner shared by tabs on this computer, without accounts or cloud synchronization.

## Scheduling policy

`scheduler.pl` performs the allocation in Prolog. It expands weekly classes into occupied intervals, accounts for overlapping classes when finding gaps, then allocates pending tasks in deadline order (including deadline time); the existing priority/difficulty/duration order breaks equal deadlines. Work may be split between gaps, so a 180-minute review can occupy 10–11 and 12–14 around an 11–12 class. Sessions are chronological in each selected date's returned timeline. Classes outside planning hours still appear.

Suggestions cover today and the next 89 days. Today's allocation starts at or after the current Asia/Manila time, rounded up to five minutes. Sessions never overlap a class or another suggested task; they are not placed after their finish-before time. Impossible or overdue deadlines produce an explicit unscheduled-minute warning instead of silently placing late work. Longer deadlines can also produce a horizon-related shortage. This is an earliest-free-period planner; it does not infer meals, travel, breaks, attendance, or completed work.

The timeline is a recomputed suggestion, not a locked reservation or an actual-work log. A task's input duration remains the outstanding work until the user marks the whole task complete. Merely reaching a suggested session's end does not count as completion; unfinished work may move when time advances or inputs change. Each snapshot builds one shared plan, so viewing tomorrow does not allocate the same task again independently for that date.

## Prolog structure

- `system_facts.pl`: 20 task types with 6 explicit facts each: `system_task/1`, `task_category/2`, `typical_minutes/2`, `task_difficulty/2`, `task_priority/2`, `task_energy/2`. Exactly **120 system facts**, independently counted from loaded clauses.
- `planner.pl`: dynamic `user_task/5` and `user_class/4`; urgency/recommendation rules; validation; JSON persistence. `user_task(Id, Type, DaysLeft, Minutes, Status)` uses unique IDs with a separate title. `user_class(Day, StartMinuteOfDay, EndMinuteOfDay, Subject)` stores times as minutes after midnight: 08:30 = 510. Companion metadata keeps IDs and absolute due dates.
- `scheduler.pl`: pure Prolog free-interval detection, task allocation, shortage reporting, and merging classes/work/free time into one daily sequence.
- `server.pl`: local HTTP server, JSON endpoints, static frontend, error handling, and browser-origin checks for mutations.
- `public/`: HTML, CSS, and JavaScript. Prolog determines each bucket, ordering, and time-fit result; JavaScript renders the returned data.

Within each group, earlier deadlines lead. Equal deadlines use system priority (high first), difficulty (hard first), estimated duration (shorter first), and ID. This makes system knowledge useful while preserving the specified deadline thresholds. The user's estimate may override the task type's typical estimate. Difficulty and energy remain visible context.

Due dates use Asia/Manila calendar days. They are persisted as ISO dates, and Prolog refreshes `DaysLeft` whenever state is requested. The page refreshes every minute and on returning to the tab. Completed tasks keep their original estimate for reference but are excluded from all three recommendation predicates.

The web app loads only its own Prolog modules. Earlier standalone prototypes have been removed; their Markdown guides remain as historical documentation. The local SWI-Prolog runtime remains under `../task_planner/.tools/swipl/`.

## Storage

Every accepted change is saved to `web/data/state.json`. Writes use a temporary file and replacement; HTTP mutations are serialized with a mutex and wrapped in a Prolog transaction, so failed saves roll back memory. Invalid saved data stops startup rather than silently replacing it. Keep a copy of this JSON file to back up your planner. `PLANNER_STATE` can point to a separate state file for isolated tests or another local dataset. Never consult user JSON as Prolog source.

## Verify

Before cleanup, 54 Prolog tests, 66 isolated HTTP checks, and 6 calendar tests passed. The test files and scripts were removed during cleanup because the app does not need them at runtime. Historical verification notes remain under `verification/`.

For the three examples in the document, add an assignment due in 1 day, reading due in 4 days, and cleaning due in 10 days. They appear under Do First, Do Next, and Do Later respectively. Add Monday Computer Networks from 08:00 to 10:00; it appears in the saved class list. Reload or restart to verify persistence.

API: `GET /api/state?minutes=60&date=2026-10-29` returns the shared plan and selected day's timeline. JSON POSTs: `/api/tasks` (`title`, `type`, `days_left`, `minutes`, optional `subject` and `deadline_time` minute-of-day), `/api/planning` (`day_start`, `day_end` minutes), `/api/classes` (`subject`, `days` array, `start`, `end`; legacy single `day` is accepted), `/api/task_status` (`id`, `status`), `/api/delete_task` (`id`), `/api/delete_class` (`id`). New tasks/classes return 201; validation failures return 400. Older schema-1 JSON files without scheduling options still load using defaults.
# Editable schedules and exact deadlines

Task entry uses an exact deadline date and time (Asia/Manila). The **Task type** dropdown is restored and sends the selected type to Prolog, so types such as research, cleaning, exercise, and work use their own knowledge profiles. Choose **Quiz / exam review** for review time; other types use the total-work label. Both accept hours or minutes. Changing the type suggests its typical duration in the currently selected unit. Automatic refresh preserves the selected type and any manually edited duration. Task cards show the selected type and its category. The backend retains compatibility with older checkbox-based requests and saved records.

Use **Edit** in the class list or **Edit class** in the calendar to change a weekly occurrence's subject, weekday, and times. Each weekday is a separate saved occurrence.

Use **Edit time** on any work session to choose its date, start, and end. This saves a fixed session; Prolog reserves it before allocating the task's remaining minutes. You may split work by shortening a chosen session, but chosen sessions cannot exceed the task's total work. Other automatic suggestions may rearrange. Fixed sessions survive refresh/restart; **Return to automatic scheduling** removes the reservation. They remain on their chosen dates as time passes and do not mark the task complete.

New chosen sessions must be in the future within 90 days, within planning hours, before the deadline, and clear of classes and other chosen sessions. Conflicting class/planning-hour edits fail atomically with an explanation. Move or release the chosen work session first. Completed tasks are excluded from scheduling; deleting a task removes its reservations.

Added routes: `POST /api/edit_class`, `/api/session`, `/api/delete_session`. Optional `sessions` in schema-1 storage preserves compatibility with existing files. The pure scheduler supports `build_plan/7` for reservations; `build_plan/6` remains supported.

Verified: 54 Prolog tests, 66 isolated HTTP checks (including editing, rejection rollback and restart persistence), and 6 calendar tests.
