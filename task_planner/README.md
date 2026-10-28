# Historical guide

The standalone command-line source, launcher, tests, and generated evidence were removed during the runtime-only cleanup. This Markdown guide is preserved for reference. Run the current web app with `..\web\run.ps1`; only the local SWI-Prolog runtime remains here under `.tools/swipl/`.

# Task Planner: an explainable Prolog recommendation system

Task Planner helps a user choose what to do next from their goals and tasks.
It considers available time, remaining duration, deadline urgency, user priority,
energy, task difficulty, progress, and prerequisites. Every recommendation has
an explanation. A recursive planner can also suggest an ordered work session.

This is a rule-based academic prototype. The sample records are fictional.
Its decisions follow a stated policy rather than a learned prediction model.

## Files and modules

There are exactly four Prolog source files:

- `facts.pl` declares module `task_facts`: domains, policy values, and sample records.
- `rules.pl` declares module `task_rules`: reasoning, validation, and safe updates.
- `proj.pl` declares module `task_planner`: entry point, text menu, and JSON storage.
  It reexports the facts and rules so loading it exposes the public queries.
- `tests.pl` contains the independent PlUnit tests and temporary fixtures.

`proj.pl` imports the other modules using `reexport/1`; `rules.pl` uses
`use_module/1`. These directives are Prolog's file/module loading mechanism.
The original `../proj.pl` is separate and was not edited.

Other files are `run.ps1`, this README, `RULE_GUIDE.md`, `TEST_QUERIES.md`,
and verification evidence under `verification/`. Runtime-only `state.json`
appears when you choose Save. The optional `.tools/` directory contains a
locally extracted runtime and is excluded from version control.

## Run on this computer

Open PowerShell in this folder:

```powershell
.\run.ps1
.\run.ps1 -Mode demo
.\run.ps1 -Mode test
.\run.ps1 -Mode check
```

The launcher uses `.tools\swipl\bin\swipl.exe` when present, otherwise `swipl`
on PATH. It also works when called by an absolute path from another directory.
The extracted runtime requires no system-wide installation or PATH changes.

On another computer, install [SWI-Prolog](https://www.swi-prolog.org/download/stable).
The application uses SWI-Prolog modules, dictionaries, transactions, JSON,
and PlUnit. It was verified with SWI-Prolog 10.0.2 on Windows x64.
The source and standard SWI libraries are sufficient; no Python, Node,
third-party Prolog packages, network connection, or API key is needed to run it.

Direct commands, with SWI-Prolog on PATH:

```powershell
swipl -q -s proj.pl -g main -t halt
swipl -q -s proj.pl -g demo -t halt
swipl -q -s tests.pl -g run_tests -t halt
swipl -q -s proj.pl
```

With the local runtime, replace `swipl` with `& '.\.tools\swipl\bin\swipl.exe'`.
The last command opens the query prompt. Queries end with a period:

```prolog
?- recommend(60, medium, date(2026,10,26), Task, Explanation).
?- session_plan(60, medium, date(2026,10,26), Tasks, Used, Unused).
?- validate_kb(Errors).
?- halt.
```

## Data model and invariants

The baseline contains **314 fact clauses, 11 goals, 33 tasks, and 5 dependency
edges**. Count these with `knowledge_stats(Stats).`; the count comes from the
loaded fact clauses rather than comments, rules, or generated records.
Of those clauses, 247 describe goals, task attributes, and dependency edges;
67 define domains, ranking values, or the demonstration date.

A goal is `goal(Id, Title, Category, Status)`. Each task has seven required
facts: `task(Id, GoalId, Title, Type)`, `remaining_minutes/2`, `difficulty/2`,
`priority/2`, `deadline/2`, `task_status/2`, and `progress/2`. Optional
`depends_on(Task, Prerequisite)` facts link tasks, including across goals.
Task types must belong to their goal's category. Categories themselves do not
receive hidden ranking preferences.

IDs begin with a lowercase ASCII letter and contain lowercase letters, digits,
or underscores. Titles are nonblank atoms up to 200 characters. The menu
converts plain text into atoms, so titles do not need quotes there. At the
Prolog query prompt, quote titles containing spaces.

- **Duration:** nonnegative integer remaining minutes, supplied by the user.
  A pending or in-progress task needs at least one minute. A completed task
  has zero remaining minutes. Progress does not multiply the estimate again.
- **Progress:** any integer from 0 through 100, not just multiples of ten.
  0 means pending, 1–99 means in progress, and 100 means completed.
- **Archive:** a separate exclusion state preserving progress and remaining
  duration. Restore it before updating progress. Restoring derives its status
  from its saved percentage.
- **Deadline:** `date(Year,Month,Day)` or `none`. Valid years are 1900–9999.
  Dates are validated by a calendar round trip; February 30 is rejected.
- **Goal status:** active, paused, completed, or abandoned. Only active goals
  contribute eligible work. Changing a goal's status does not rewrite its tasks.
- **Prerequisites:** must reference real tasks and form an acyclic graph.
  All direct and transitive prerequisites must be completed. Completion of a
  blocked task is rejected; reopening or archiving a prerequisite of an already
  completed dependant is also rejected until the dependant is reopened.

`validate_kb(Errors)` detects invalid records, duplicate IDs/attributes,
missing fields, broken references, cycles, orphan attributes, and inconsistent
completion. `Errors = []` means the current database passes these checks.
Use the exported mutation predicates rather than directly asserting records.

## Decision policy

Eligibility is a hard filter: well-formed, unfinished, unarchived task; active
goal; enough available minutes; and completed prerequisites.

Eligible tasks are ordered lexicographically by these fields:

1. Urgency band: overdue, due today, due within the next two calendar days,
   scheduled later, then no deadline.
2. User priority: urgent, high, medium, low.
3. Energy mismatch: smaller difficulty-minus-capacity gap first.
4. Already in progress before pending.
5. Higher progress percentage.
6. Earlier deadline within the remaining tie; for overdue work, older first.
7. Shorter remaining duration.
8. Task ID in lexical order for a reproducible final tie-break.

Each earlier field takes precedence over every later field. For example, overdue
medium-priority work outranks a high-priority task due tomorrow. This is a
deliberate policy choice, not a claim that it is ideal for every person.

Difficulty demand is easy=1, moderate=2, hard=3, very_hard=4. Energy capacity is
low=1, medium=2, high=4. The penalty is `max(0, demand-capacity)`.
Energy is a soft preference: a hard urgent task is still visible at low energy.
No arbitrary weighted total can allow several small bonuses to overpower
deadline urgency. `ranking_key/4` exposes the exact comparison fields.

The session planner repeatedly selects the best eligible task that fits the
remaining budget. It treats earlier selections as hypothetically finished,
allowing dependent work later in the session. It never updates actual progress.
It is a greedy, priority-first planner, not a globally optimal time-filling
algorithm. Breaks, task splitting, energy depletion, and clock-time scheduling
are outside this version; durations are assumed to be uninterrupted work time.

## Menu and storage

The menu lists goals/tasks; adds goals/tasks; updates progress; recommends work;
plans sessions; explains exclusions; changes goal status; edits dependencies;
archives/restores tasks; saves/loads JSON; and displays allowed values and counts.

Enter fields as plain text without a trailing Prolog period. Use `none` for no
deadline. Context prompts accept `demo` for 2026-10-26, an explicit ISO date,
or Enter for today's Asia/Manila date. Query predicates always take an explicit
reference date; calendar day differences use UTC midnight arithmetic.

Changes are session-only until **Save** (13). **Load** (14) explicitly replaces
the current session with `state.json` next to the source files. The program does
not automatically load saved data on startup, preserving reproducible sample
queries. Start the menu and choose Load when continuing saved work.

Saving writes a temporary file before replacing the snapshot. Loading checks
the schema and complete knowledge base in a transaction; invalid data leaves
the existing session unchanged. JSON input is data and is never executed as
Prolog code. Errors return to the menu; end-of-input exits cleanly.

Programmatic examples:

```prolog
?- add_goal(g_logic, 'Learn logic programming', academic).
?- add_task(logic_reading, g_logic, 'Read a chapter', study,
            25, easy, high, date(2026,10,28)).
?- update_progress(logic_reading, 40, 15).
?- set_goal_status(g_logic, paused).
?- set_goal_status(g_logic, active).
?- save_state('my_tasks.json').
?- load_state('my_tasks.json').
```

At the query prompt, storage paths are relative to the current working directory.
The menu uses a path relative to the source folder. Invalid public updates throw
an explanatory error and roll back. A recommended task of `none` means there is
no eligible work for the supplied time, with a structured explanation.

## Demonstration and rubric evidence

Run `demo` on freshly loaded sample data. For 60 minutes, medium energy, and
2026-10-26, the recommendation is `submit_report`. The proposed session is
`[submit_report,revise_notes,water_plants]`, using exactly 60 minutes. The demo
also explains why proofreading is blocked by unfinished prerequisite work.

For a presentation: show the fact base; run the recommendation; shorten the
available time to 15 minutes; inspect a blocked task; complete its prerequisite;
then show a changed recommendation or eligibility result. Finish by running
the tests and `validate_kb/1`. Restart Prolog to recover the baseline sample data.

- **Fact base quantity and depth:** 314 real clauses with varied task records,
  categories, progress states, dates, and relationships.
- **Rule complexity:** `RULE_GUIDE.md` identifies 25 substantive reasoning and
  integrity predicates, including recursive traversal/planning and rule chaining.
  Simple fact lookups, module directives, and menu wrappers do not count here.
- **Test queries and validation:** `TEST_QUERIES.md` documents more than ten
  queries with expected results; `tests.pl` checks the associated behavior and
  additional edge cases automatically.
- **Correctness:** verified compilation, full automated tests, fixed-date demo,
  scripted menu flows, cycle termination, persistence, and invalid-input handling.
- **Documentation and presentation:** module descriptions, argument-mode comments,
  policy explanations, query examples, an executable demo, and stored evidence.

This is evidence toward the rubric's Excellent criteria, not a guaranteed grade.
See `verification/VERIFICATION.md` for the actual verification results.

## Official references

- [SWI-Prolog module system](https://www.swi-prolog.org/pldoc/man?section=modules)
- [Transactions and rollback](https://www.swi-prolog.org/pldoc/man?predicate=transaction/1)
- [Prolog Unit Tests](https://www.swi-prolog.org/pldoc/doc_for?object=section('packages/plunit.html'))
- [SWI-Prolog stable download](https://www.swi-prolog.org/download/stable)

The local runtime was extracted from the official `swipl-10.0.2-1.x64.exe`
without running its installer. Its SHA256 matched the official value:
`2ec1f25be0eafb92e559004782b130774c12573fb4b7e8a917e534754a641ad6`.
