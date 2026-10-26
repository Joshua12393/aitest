# Test queries and expected results

Load a fresh `proj.pl` in SWI-Prolog. Queries 1–24 are read-only and use the
fictional baseline data with reference date **2026-10-26**. The real current
date does not change these expected results. Run mutation examples 25–27 in a
fresh process when comparing baseline results. Type each query with a period.

The automated suite in `tests.pl` checks these behaviors plus additional
validation, dependency, date, determinism, and persistence cases. The query
verification output is stored in `verification/query_results.txt`.

## 1. Count meaningful facts and records

```prolog
knowledge_stats(Stats).
```

Expected: `Stats = stats{dependencies:5,facts:314,goals:11,tasks:33}`.

## 2. Validate the entire knowledge base

```prolog
validate_kb(Errors).
```

Expected: `Errors = []`.

## 3. Recommend work for a normal session

```prolog
recommend(60, medium, date(2026,10,26), Task, _).
```

Expected: `Task = submit_report`. It is overdue, urgent, in progress, and fits.

## 4. Adapt to a shorter session

```prolog
recommend(25, medium, date(2026,10,26), Task, _).
```

Expected: `Task = revise_notes`. The overdue report needs 30 minutes and is excluded.

## 5. Adapt to fifteen minutes and low energy

```prolog
recommend(15, low, date(2026,10,26), Task, _).
```

Expected: `Task = send_application`. Its resume prerequisite is already completed.

## 6. Return a clear result when no task fits

```prolog
recommend(4, high, date(2026,10,26), Task, _).
```

Expected: `Task = none`, rather than an exception or a fabricated recommendation.

## 7. Include a task that exactly fits

```prolog
eligible(submit_report, 30, medium, date(2026,10,26)).
```

Expected: `true`.

## 8. Reject a task one minute beyond the budget

```prolog
eligible(submit_report, 29, medium, date(2026,10,26)).
```

Expected: `false`.

## 9. Exclude completed work even if its old deadline has passed

```prolog
eligible(resume_edit, 60, high, date(2026,10,26)).
```

Expected: `false`. Zero remaining duration does not make completed work a candidate.

## 10. Exclude archived urgent work

```prolog
eligible(archived_task, 60, high, date(2026,10,26)).
```

Expected: `false` despite its overdue deadline and urgent priority.

## 11. Respect paused goals

```prolog
eligible(paused_reading, 60, high, date(2026,10,26)).
```

Expected: `false`. An urgent task cannot bypass its goal's inactive status.

## 12. Include the two-day urgency boundary

```prolog
deadline_info(read_article, date(2026,10,26), Band, Days).
```

Expected: `Band = due_soon, Days = 2`.

## 13. Handle tasks without deadlines

```prolog
deadline_info(walk, date(2026,10,26), Band, Days).
```

Expected: `Band = no_deadline, Days = none`.

## 14. Follow a transitive prerequisite chain

```prolog
prerequisite_path(proofread_paper, research_sources, Path).
```

Expected: `Path = [proofread_paper,write_paper,outline_paper,research_sources]`.

## 15. Identify unfinished ancestors, excluding completed ones

```prolog
blocked_by(proofread_paper, Blockers).
```

Expected: `Blockers = [outline_paper,write_paper]`. `research_sources` is complete.

## 16. Explain exclusion using structured evidence

```prolog
explain_task(proofread_paper, 60, medium, date(2026,10,26),
             explanation{task:proofread_paper,title:_,eligible:Eligible,
                         blockers:Blockers,reasons:_}).
```

Expected: `Eligible = false`,
`Blockers = [unfinished_prerequisites([outline_paper,write_paper])]`.

## 17. Calculate energy mismatch

```prolog
energy_penalty(workout, low, Penalty).
```

Expected: `Penalty = 2`: hard difficulty demand 3 minus low-energy capacity 1.

## 18. Keep difficult urgent work visible at low energy

```prolog
eligible(exam_review, 90, low, date(2026,10,26)).
```

Expected: `true`. Energy affects ranking, not hard eligibility.

## 19. Resolve otherwise equal rankings deterministically

```prolog
findall(T,
        (ranked_tasks(60, high, date(2026,10,26), Ranked),
         member(T, Ranked), memberchk(T, [organize_drawer,sort_shelf])),
        TiedTasks).
```

Expected: `TiedTasks = [organize_drawer,sort_shelf]`. Task IDs break the tie.

## 20. Construct a recursive session plan

```prolog
session_plan(60, medium, date(2026,10,26), Tasks, Used, Unused).
```

Expected: `Tasks = [submit_report,revise_notes,water_plants], Used = 60, Unused = 0`.

## 21. Terminate cleanly for a zero-minute session

```prolog
session_plan(0, medium, date(2026,10,26), Tasks, Used, Unused).
```

Expected: `Tasks = [], Used = 0, Unused = 0`.

## 22. Aggregate progress for a goal

```prolog
goal_progress(g_paper, Percent).
```

Expected: `Percent = 20`: five non-archived tasks with percentages 0,100,0,0,0.

## 23. Reject an invalid calendar date

```prolog
valid_date(date(2026,2,30)).
```

Expected: `false`. The date is rejected rather than normalized into March.

## 24. Reject invalid user context explicitly

```prolog
recommend(-1, medium, date(2026,10,26), _, _).
```

Expected: exception `error(domain_error(nonnegative_minutes,-1), _)`.
This is an intentional validation error, not an unexpected runtime failure.
The menu translates it into a message and continues.

## 25. Complete a prerequisite and observe changed eligibility

Run in a fresh session:

```prolog
update_progress(outline_paper, 100, 0),
eligible(write_paper, 90, high, date(2026,10,26)).
```

Expected: `true`. The outline becomes completed; writing is now eligible.
The updated duration is zero because the outline is finished.

## 26. Reject a dependency cycle without changing the database

Run in a fresh session:

```prolog
catch(add_dependency(outline_paper, proofread_paper),
      error(validation_error(Errors), _), true),
nonvar(Errors),
memberchk(dependency_cycle(outline_paper), Errors),
\+ depends_on(outline_paper, proofread_paper),
validate_kb([]).
```

Expected: success, with `Errors` containing cycle findings for `outline_paper`,
`proofread_paper`, and `write_paper`. The rejected edge is absent and the restored
database validates. The query terminates instead of recursing indefinitely.

## 27. Add a user goal and a task

Run in a fresh session:

```prolog
add_goal(g_logic, 'Learn logic programming', academic),
add_task(logic_reading, g_logic, 'Read a chapter', study,
         25, easy, high, date(2026,10,28)),
eligible(logic_reading, 25, low, date(2026,10,26)).
```

Expected: `true`. The new task is pending at 0% and associated with the user's goal.

## Additional automated coverage

`tests.pl` also verifies empty databases, leap years and year boundaries, duplicate
IDs, missing/duplicate attributes, category mismatches, malformed task exclusion,
deterministic outputs, circular raw data, branching traversal guards, hypothetical
prerequisite unlocking, unique budget-bounded plans, archive/restore, reopening
restrictions, atomic JSON replacement, corrupt snapshot rollback, and preservation
of the baseline after mutating tests. See test names for the exact assertions.
