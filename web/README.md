# Adaptive goal planning and task recommendations

Implements the supplied [project specification](https://docs.google.com/document/d/1D4yVbV8IE8FvtKM-OYQGBU2uJfAmmbWu0v10NXm1Rx0/edit) as a local HTML application with a real SWI-Prolog HTTP backend.

## Run

From PowerShell in this directory:

```powershell
.\run.ps1
```

Open http://localhost:8080. Use `-Port 8081` for another port. Ctrl+C stops the server. The launcher reuses the runtime already present under `../task_planner/.tools/swipl/bin/`, or uses an installed `swipl` on PATH. It works from other working directories too. With SWI-Prolog on PATH, `swipl -q server.pl 8080` also works. No Node, external packages, API keys, internet connection, or build step is required.

## What is implemented

- Task form: title, task type, deadline in whole days, estimated minutes.
- Class form: weekday, subject, start/end time, including minute precision.
- **Do First:** pending tasks due in 2 days or less, including today and overdue work.
- **Do Next:** pending tasks due in 3–5 days.
- **Do Later:** pending tasks due after 5 days.
- Complete, reopen, and delete tasks; delete saved classes.
- Type-based default estimates, category, priority, difficulty, energy, and explanations.
- Optional available-time badges. Longer tasks stay visible in their deadline group.
- Blank initial user data. Every displayed task/class comes from user input.
- Automatically saved local JSON, validated on loading and restored at startup.
- Responsive layout, labeled controls, escaped user text, and accessible status messages.

The implementation follows the document's simple first version. Class records are stored for reference; the app does not allocate calendar slots or claim to prevent class/task scheduling conflicts. A deadline is required. This is a single local planner shared by tabs on this computer, without accounts or cloud synchronization.

## Prolog structure

- `system_facts.pl`: 20 task types with 6 explicit facts each: `system_task/1`, `task_category/2`, `typical_minutes/2`, `task_difficulty/2`, `task_priority/2`, `task_energy/2`. Exactly **120 system facts**, independently counted from loaded clauses.
- `planner.pl`: dynamic `user_task/5` and `user_class/4`; urgency/recommendation rules; validation; JSON persistence. `user_task(Id, Type, DaysLeft, Minutes, Status)` uses unique IDs with a separate title. `user_class(Day, StartMinuteOfDay, EndMinuteOfDay, Subject)` stores times as minutes after midnight: 08:30 = 510. Companion metadata keeps IDs and absolute due dates.
- `server.pl`: local HTTP server, JSON endpoints, static frontend, error handling, and browser-origin checks for mutations.
- `public/`: HTML, CSS, and JavaScript. Prolog determines each bucket, ordering, and time-fit result; JavaScript renders the returned data.
- `tests.pl`: PlUnit coverage for the specification, boundaries, knowledge count, calendar handling, persistence, and rollback.

Within each group, earlier deadlines lead. Equal deadlines use system priority (high first), difficulty (hard first), estimated duration (shorter first), and ID. This makes system knowledge useful while preserving the specified deadline thresholds. The user's estimate may override the task type's typical estimate. Difficulty and energy remain visible context.

Due dates use Asia/Manila calendar days. They are persisted as ISO dates, and Prolog refreshes `DaysLeft` whenever state is requested. The page refreshes every minute and on returning to the tab. Completed tasks keep their original estimate for reference but are excluded from all three recommendation predicates.

The separate command-line planner in `../task_planner/` and the original `../proj.pl` and `../proj2.pl` are retained. This web app now loads its own spec-aligned modules rather than the old hardcoded demo records in `proj2.pl`.

## Storage

Every accepted change is saved to `web/data/state.json`. Writes use a temporary file and replacement; HTTP mutations are serialized with a mutex and wrapped in a Prolog transaction, so failed saves roll back memory. Invalid saved data stops startup rather than silently replacing it. Keep a copy of this JSON file to back up your planner. `PLANNER_STATE` can point to a separate state file for isolated tests or another local dataset. Never consult user JSON as Prolog source.

## Verify

```powershell
.\run.ps1 -Mode test
.\smoke.ps1
```

`smoke.ps1` requires PowerShell 7+ and runs HTTP checks against its own temporary state file and port. It verifies all three example groups, mutations, bad inputs, origin checks, and persistence across a real server restart, then removes its test files.

For the three examples in the document, add an assignment due in 1 day, reading due in 4 days, and cleaning due in 10 days. They appear under Do First, Do Next, and Do Later respectively. Add Monday Computer Networks from 08:00 to 10:00; it appears in the saved class list. Reload or restart to verify persistence.

API: `GET /api/state?minutes=60`; JSON POSTs to `/api/tasks` (`title`, `type`, `days_left`, `minutes`), `/api/classes` (`subject`, `day`, `start`, `end`), `/api/task_status` (`id`, `status`), `/api/delete_task` (`id`), `/api/delete_class` (`id`). New tasks/classes return 201; validation failures return 400.
