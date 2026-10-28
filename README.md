# AI-Based Adaptive Goal Planning and Task Recommendation System

A local task planner with an HTML interface and a SWI-Prolog backend. Users enter their tasks and weekly classes; Prolog applies deadline rules and task-type knowledge to recommend what to prioritize.

## Start the web app

Install [SWI-Prolog](https://www.swi-prolog.org/download/stable) and make `swipl` available on PATH. In PowerShell, run:

```powershell
.\web\run.ps1
```

Open [localhost:8080](http://localhost:8080). Use `-Port 8081` for another port. The launcher also recognizes an existing local runtime under `task_planner/.tools/swipl/`; runtime binaries are excluded from this repository.

On other platforms, with SWI-Prolog installed:

```sh
swipl -q -s web/server.pl -- 8080
```

## Features

- User-entered tasks, estimates, deadlines, and weekly classes. A task-type dropdown exposes all 20 knowledge profiles, displays their category and attributes, and suggests an editable duration.
- **Do First:** pending tasks due in 2 days or less, including overdue tasks.
- **Do Next:** pending tasks due in 3–5 days.
- **Do Later:** pending tasks due after 5 days.
- 120 meaningful system facts across 20 task types, separate from dynamic user facts.
- Type-based estimates and explanations, available-time badges, task completion and reopening.
- Clickable monthly calendar with a daily sequence of classes, suggested work, and free periods. Prolog splits allotted work time across vacant periods before deadlines; planning hours are editable (default 8 AM–10 PM).
- Local JSON persistence, input validation, and responsive desktop/mobile layouts.

The timetable uses recurring classes and user-entered task durations/deadlines. Suggestions cover the next 90 days, avoid class/task collisions, and report work that cannot fit. They are recalculated suggestions rather than confirmed reservations or automatic completion records. It is a single local planner, without accounts or cloud synchronization. Saved user data is excluded from Git.

## Project contents

- [`web/`](web/README.md): web app, Prolog rules, frontend, and launcher.
- `web/data/state.json`: saved user tasks, classes, settings, and chosen work sessions (local only).
- `task_planner/.tools/swipl/`: local SWI-Prolog runtime used by the launcher.
- Markdown guides and historical verification notes are preserved. The earlier prototypes, write-ups, generated previews, and test files were removed during cleanup.

## Verification

Before cleanup, 54 Prolog tests, 66 isolated HTTP integration checks, and 6 calendar tests passed. Test scripts and preview images were then removed because they are not required to run the app. Historical checks remain in [`web/verification/README.md`](web/verification/README.md).
