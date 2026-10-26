# Rule guide and design defense

These 25 predicate definitions implement distinct reasoning or integrity
operations in `rules.pl`. The list excludes simple wrappers, numeric lookup
facts, UI commands, and module declarations. A predicate may have several clauses;
those clauses are not counted as separate unique rules in this inventory.

## Calendar and suitability

1. **`valid_date/1`:** constrains numeric fields and round-trips a UTC calendar
   date, rejecting dates that a time library might silently normalize.
2. **`days_between/3`:** validates both dates and derives signed calendar-day
   distance across month, year, and leap-day boundaries.
3. **`deadline_info/4`:** selects one mutually exclusive urgency band and handles
   absent deadlines without mixing an atom into arithmetic.
4. **`unfinished/1`:** combines existence, operational status, and progress;
   completed or archived records are excluded.
5. **`active_goal_task/1`:** joins task ownership to goal lifecycle status.
6. **`fits_time/2`:** requires positive remaining work bounded by available time,
   including exact equality.
7. **`energy_penalty/3`:** joins task difficulty and user energy capacity and
   derives a nonnegative mismatch penalty.

## Dependencies and eligibility

8. **`dependency_path/4`:** recursive depth-first traversal accumulates an actual
   path while tracking visited IDs. Destination checking before the visited
   guard permits a cycle to be reported without endlessly following it.
9. **`ready_dependencies/3`:** recursively requires all prerequisite ancestors
   to be completed, or already selected earlier in a hypothetical session.
   Repeated nodes on the same path cause failure. Branching DAGs are allowed
   because the visited list is local to each path.
10. **`blocked_by/2`:** finds direct and transitive unfinished prerequisites,
    collecting and deduplicating results from multiple paths.
11. **`eligible_assuming/3`:** chains record validation, unfinished state, active
    goal, time fit, uniqueness, and dependency readiness into one eligibility
    decision. Its assumed-completed list supports the recursive session planner.

## Selection and explanation

12. **`ranking_key/4`:** combines eight ordered criteria into a lexicographic
    comparison term with an explicit deterministic tie-break.
13. **`ranked_assuming/5`:** gathers only eligible tasks, attaches comparison
    keys, sorts them, and returns a reproducible ordered recommendation list.
14. **`recommend/5`:** chooses the best candidate and produces evidence, or a
    structured `none` result when the candidate set is empty.
15. **`exclusion_reason/3`:** multiple clauses infer distinct exclusion causes
    from task state, goal state, time, and dependency integrity.
16. **`explain_task/5`:** aggregates blockers and positive evidence into a
    structured explanation usable both from queries and the text interface.
17. **`plan_steps/6`:** recursively replans against a shrinking time budget and
    an expanding assumed-completed set. This supports same-session dependency
    unlocking without modifying the real knowledge base.
18. **`goal_progress/2`:** aggregates progress for non-archived tasks, handles
    empty goals, and computes a rounded mean instead of assuming every goal
    has the same task count.

## Consistency and updates

19. **`task_well_formed/1`:** enforces exactly one core record and one value for
    every required attribute before checking the joined record's semantics.
20. **`valid_task_record/10`:** joins goal category to task type and verifies
    identifiers, title, duration, difficulty, priority, deadline, and progress.
21. **`consistent_state/3`:** relates status, progress percentage, and remaining
    duration, including separate archived-state constraints.
22. **`validation_error/1`:** discovers malformed goals/tasks, duplicate records,
    orphan metadata, missing dependency endpoints, cycles, and completed tasks
    with unfinished prerequisites. `validate_kb/1` collects all these findings.
23. **`add_task/8`:** validates an entire new task and inserts its seven related
    facts atomically, preserving the database when any constraint fails.
24. **`update_progress/3`:** derives lifecycle status from progress, validates
    the new remaining estimate, and checks dependency consistency in one
    transaction before committing the related attribute changes.
25. **`add_dependency/2`:** verifies endpoint existence and uniqueness, inserts
    the relationship provisionally, and rejects it if graph validation detects
    a cycle or an inconsistent completed task.

## Why recursion and rule chaining are useful here

An example chain is:

```text
proofread_paper -> write_paper -> outline_paper -> research_sources
```

The dependency rule does not hard-code three levels. It follows any finite
chain in the data. The session planner similarly handles a variable number of
tasks, stopping when nothing else fits. Guards ensure both recursions terminate.

The recommendation chain is:

```text
goal/task facts + current context
    -> record integrity + eligibility
    -> deadline/priority/energy/progress key
    -> ranked candidates
    -> selected task + explanation
```

These are multiple meaningful inference stages, rather than fifteen renamed
wrappers around a single lookup. The implementation uses if-then-else for
exclusive classifications. No explicit cut (`!`) is needed: the rubric gives
recursion, cuts, and complex chaining as examples, and this system demonstrates
recursion and chaining for actual domain requirements.

## Termination and limitations

- Path traversal never expands a node already visited along that path.
- Dependency readiness fails on a repeated node or missing prerequisite.
- Each planning step selects a new task and consumes positive minutes. Even
  a very large budget cannot make the planner repeat work indefinitely.
- Dependency traversal can explore multiple paths through a dense DAG; this is
  appropriate for the small academic dataset, not a claim of large-scale speed.
- The planner is greedy. It prioritizes the documented policy and does not
  search every task subset to maximize duration utilization or global utility.
- Energy is a user-supplied preference. The system does not predict fatigue or
  automatically override the user's priority based on category.
- Goal progress is an equal-task mean, not an estimate weighted by original
  effort, because original total durations are not part of this data model.
