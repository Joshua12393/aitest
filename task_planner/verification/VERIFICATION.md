# Historical verification record

The source, tests, and generated evidence referenced below were removed during cleanup. This Markdown record is preserved for reference and describes the earlier command-line prototype.

# Verification results

Verified on **2026-10-26 (Asia/Manila)** with **SWI-Prolog 10.0.2, Windows x64**.

## Results

- 90/90 automated PlUnit tests passed, with no warnings or residual-choicepoint
  warnings. Full output: `tests.log`.
- 27/27 documented query scenarios matched their expected outputs. Each query
  was executed in a separate fresh Prolog process. Evidence: `query_results.txt`.
- 15/15 scripted menu flows passed. Evidence: `menu_results.txt`.
- SWI-Prolog source checking (`check/0`, including undefined-predicate checking)
  completed successfully with no diagnostics.
- The fixed-date demonstration completed successfully. Output: `demo_output.txt`.
- The PowerShell launcher successfully ran its check and demo modes.
- The application source consists of exactly `facts.pl`, `rules.pl`, `proj.pl`,
  and `tests.pl` in the new project's root.
- Knowledge-base validation returned `[]`. Baseline counts were 314 facts,
  11 goals, 33 tasks, and 5 prerequisite edges.

Machine-readable results: `results.json`.

## Menu checks

Verified normal exit, end-of-input, unrecognized input treated as text, negative
minutes, invalid energy, impossible dates, recommendations, blocked-task
explanations, session planning, goal/task creation and progress updates, category
mismatch rejection, paused-goal behavior, dependency-cycle rejection, archive
and restore, and save/load session restoration. Save/load verification preserved
any preexisting state file and removed its temporary demonstration state.

## Original file preservation

The original file is `D:\Codes Kyeruu\prolog\final\proj.pl`. Its SHA-256 before
and after implementation was identical:

```text
22E88D4C6B41AAF16DA765B25E446A76640E8EA2F5E8F9EF6B1129125D8D6D36
```

All implementation files, runtime files, and verification outputs were placed
under `D:\Codes Kyeruu\prolog\final\task_planner`.

## Reproduce the main checks

From the new project folder:

```powershell
.\run.ps1 -Mode test
.\run.ps1 -Mode check
.\run.ps1 -Mode demo
```

On another machine, install SWI-Prolog and use the direct commands in the README.
The optional local `.tools/` directory is not required when SWI-Prolog is installed.

These results cover the supplied academic dataset and the tested edge cases.
The session planner follows the documented greedy policy; these checks do not
claim globally optimal scheduling, a production deployment, or an instructor's
final grading decision.
