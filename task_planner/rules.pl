:- module(task_rules, [
    valid_date/1, days_between/3, deadline_info/4, overdue/2, due_soon/2,
    unfinished/1, active_goal_task/1, fits_time/2, energy_penalty/3,
    prerequisite_path/3, dependency_cycle/2, prerequisites_complete/1,
    blocked_by/2, eligible/4, ranking_key/4, ranked_tasks/4, recommend/5,
    explain_task/5, session_plan/6, goal_progress/2, validate_kb/1,
    knowledge_stats/1, add_goal/3, add_task/8, update_progress/3,
    set_goal_status/2, set_archived/2, add_dependency/2, remove_dependency/2,
    check_context/3, require_valid_kb/0
]).

:- use_module('facts.pl').
:- use_module(library(error)).
:- use_module(library(lists)).
:- use_module(library(pairs)).

/** <module> Explainable, deterministic task selection

Public queries use explicit context (Minutes, Energy, Today). They do not read
the clock or change the database. This makes demonstrations reproducible.
Modes: + means input, - means output; task predicates also enumerate task IDs.
Public mutation predicates validate the resulting database in a transaction:
failure or an exception rolls back the whole update.
*/

%% valid_date(+Date) is semidet.
% A round trip rejects normalized invalid dates such as February 30.
valid_date(date(Y, M, D)) :-
    integer(Y), between(1900, 9999, Y),
    integer(M), between(1, 12, M), integer(D), between(1, 31, D),
    catch((date_stamp(date(Y, M, D), Stamp),
           stamp_date_time(Stamp, date(Y, M, D, 0, 0, _, _, _, _), 'UTC')),
          _, fail).

date_stamp(date(Y, M, D), Stamp) :-
    date_time_stamp(date(Y, M, D, 0, 0, 0, 0, 'UTC', false), Stamp).

%% days_between(+From, +To, -Days) is semidet.
% Calendar days in UTC avoid daylight-saving and local-time rounding problems.
days_between(From, To, Days) :-
    valid_date(From), valid_date(To),
    date_stamp(From, A), date_stamp(To, B), Days is round((B - A) / 86400).

%% deadline_info(+Task, +Today, -Band, -Days) is semidet.
% An if-then-else chooses ONE disjoint band; none has no numeric day distance.
deadline_info(Task, Today, Band, Days) :-
    valid_date(Today), deadline(Task, Due),
    ( Due == none -> Band = no_deadline, Days = none
    ; days_between(Today, Due, Days),
      ( Days < 0 -> Band = overdue
      ; Days =:= 0 -> Band = due_today
      ; Days =< 2 -> Band = due_soon
      ; Band = scheduled
      )
    ).

overdue(Task, Today) :-
    unfinished(Task), deadline_info(Task, Today, overdue, _).

due_soon(Task, Today) :-
    unfinished(Task), deadline_info(Task, Today, Band, _),
    memberchk(Band, [due_today, due_soon]).

unfinished(Task) :-
    task(Task, _, _, _), task_status(Task, Status),
    memberchk(Status, [pending, in_progress]), progress(Task, P), P < 100.

active_goal_task(Task) :-
    task(Task, Goal, _, _), goal(Goal, _, _, active).

fits_time(Task, Available) :-
    integer(Available), Available >= 0,
    remaining_minutes(Task, Needed), Needed > 0, Needed =< Available.

%% energy_penalty(+Task, +Energy, -Penalty) is semidet.
% Energy is a SOFT preference; it never silently hides urgent difficult work.
energy_penalty(Task, Energy, Penalty) :-
    difficulty(Task, Difficulty), difficulty_level(Difficulty, Demand),
    energy_level(Energy, Capacity), Penalty is max(0, Demand - Capacity).

%% prerequisite_path(+Task, +Prerequisite, -Path) is nondet.
% Depth-first traversal follows dependencies. Visited nodes bound recursion,
% while checking the destination first allows a cycle to be reported.
prerequisite_path(Task, Prerequisite, Path) :-
    task(Task, _, _, _), task(Prerequisite, _, _, _),
    dependency_path(Task, Prerequisite, [Task], Path).

dependency_path(From, To, Visited, [From|Tail]) :-
    depends_on(From, Next),
    ( Next == To -> Tail = [To]
    ; \+ memberchk(Next, Visited),
      dependency_path(Next, To, [Next|Visited], Tail)
    ).

dependency_cycle(Task, Path) :-
    task(Task, _, _, _), once(dependency_path(Task, Task, [Task], Path)).

%% prerequisites_complete(+Task) is semidet.
% All direct AND transitive prerequisites must be complete. A visited guard
% rejects circular chains even if corrupt data marks their members complete.
prerequisites_complete(Task) :-
    task(Task, _, _, _), ready_dependencies(Task, [], [Task]).

ready_dependencies(Task, AssumedDone, Visited) :-
    forall(depends_on(Task, Prerequisite),
           (task(Prerequisite, _, _, _),
            \+ memberchk(Prerequisite, Visited),
            (task_status(Prerequisite, completed)
             ; memberchk(Prerequisite, AssumedDone)),
            ready_dependencies(Prerequisite, AssumedDone,
                               [Prerequisite|Visited]))).

%% blocked_by(+Task, -Prerequisites) is det for known tasks.
% sort/2 removes duplicates when several dependency paths meet at one ancestor.
blocked_by(Task, Prerequisites) :-
    task(Task, _, _, _),
    findall(P, (prerequisite_path(Task, P, _),
                \+ task_status(P, completed)), Raw),
    sort(Raw, Prerequisites).

%% check_context(+Minutes, +Energy, +Today) is det or throws.
check_context(Minutes, Energy, Today) :-
    must_be(integer, Minutes),
    ( Minutes >= 0 -> true ; domain_error(nonnegative_minutes, Minutes) ),
    must_be(atom, Energy),
    ( energy_level(Energy, _) -> true ; domain_error(energy_level, Energy) ),
    ( ground(Today), valid_date(Today) -> true
    ; domain_error(calendar_date, Today)
    ).

%% eligible(?Task, +Minutes, +Energy, +Today) is nondet.
eligible(Task, Minutes, Energy, Today) :-
    check_context(Minutes, Energy, Today),
    eligible_assuming(Task, Minutes, []).

eligible_assuming(Task, Minutes, Done) :-
    task(Task, _, _, _), task_well_formed(Task),
    unfinished(Task), active_goal_task(Task), fits_time(Task, Minutes),
    \+ memberchk(Task, Done), ready_dependencies(Task, Done, [Task]).

%% ranking_key(+Task, +Energy, +Today, -Key) is semidet.
% Prolog term ordering compares the fields lexicographically, left to right.
% Urgency > priority > energy > started work > progress > earlier deadline >
% shorter duration > task ID. ID is a stable final tie-breaker.
ranking_key(Task, Energy, Today,
            key(Urgency, Priority, Penalty, Started, NegativeProgress,
                DueOrder, Minutes, Task)) :-
    deadline_info(Task, Today, Band, Days), urgency_rank(Band, Urgency),
    priority(Task, PriorityName), priority_level(PriorityName, Priority),
    energy_penalty(Task, Energy, Penalty),
    task_status(Task, Status), (Status == in_progress -> Started = 0 ; Started = 1),
    progress(Task, Percent), NegativeProgress is -Percent,
    (Days == none -> DueOrder = 10000000 ; DueOrder = Days),
    remaining_minutes(Task, Minutes).

urgency_rank(overdue, 0).
urgency_rank(due_today, 1).
urgency_rank(due_soon, 2).
urgency_rank(scheduled, 3).
urgency_rank(no_deadline, 4).

ranked_tasks(Minutes, Energy, Today, Tasks) :-
    check_context(Minutes, Energy, Today),
    ranked_assuming(Minutes, Energy, Today, [], Tasks).

ranked_assuming(Minutes, Energy, Today, Done, Tasks) :-
    findall(Key-Task,
            (eligible_assuming(Task, Minutes, Done),
             ranking_key(Task, Energy, Today, Key)), Pairs),
    keysort(Pairs, Sorted), pairs_values(Sorted, Tasks).

%% recommend(+Minutes, +Energy, +Today, -TaskOrNone, -Explanation) is det.
recommend(Minutes, Energy, Today, Task, Explanation) :-
    ranked_tasks(Minutes, Energy, Today, Tasks),
    ( Tasks = [Task|_] -> explain_task(Task, Minutes, Energy, Today, Explanation)
    ; Task = none,
      Explanation = explanation{eligible:false, blockers:[no_eligible_tasks],
                                reasons:[], task:none, title:'No task fits'}
    ).

%% explain_task(+Task, +Minutes, +Energy, +Today, -Explanation) is semidet.
% Blocker terms give machine-readable evidence, translated by the menu.
explain_task(Task, Minutes, Energy, Today, Explanation) :-
    check_context(Minutes, Energy, Today), task(Task, _, Title, _),
    findall(B, exclusion_reason(Task, Minutes, B), Raw), sort(Raw, Blockers),
    ( Blockers == [] -> IsEligible = true ; IsEligible = false ),
    ( task_well_formed(Task) ->
      deadline_info(Task, Today, Band, Days), priority(Task, Priority),
      energy_penalty(Task, Energy, Penalty), progress(Task, Progress),
      remaining_minutes(Task, Needed), blocked_by(Task, Blocked),
      Reasons = [deadline(Band, Days), priority(Priority),
                 time_required(Needed, Minutes), energy_gap(Penalty),
                 progress(Progress), unfinished_prerequisites(Blocked)]
    ; Reasons = []
    ),
    Explanation = explanation{task:Task, title:Title, eligible:IsEligible,
                              blockers:Blockers, reasons:Reasons}.

exclusion_reason(Task, _, invalid_task_record) :- \+ task_well_formed(Task).
exclusion_reason(Task, _, completed) :- task_status(Task, completed).
exclusion_reason(Task, _, archived) :- task_status(Task, archived).
exclusion_reason(Task, _, inactive_goal(Goal, Status)) :-
    task(Task, Goal, _, _), goal(Goal, _, _, Status), Status \== active.
exclusion_reason(Task, Available, insufficient_time(Needed, Available)) :-
    remaining_minutes(Task, Needed), Needed > Available.
exclusion_reason(Task, _, unfinished_prerequisites(Blocked)) :-
    blocked_by(Task, Blocked), Blocked \== [].
exclusion_reason(Task, _, cyclic_dependencies) :-
    \+ ready_dependencies_acyclic(Task, [Task]).

ready_dependencies_acyclic(Task, Visited) :-
    forall(depends_on(Task, P),
           (task(P, _, _, _), \+ memberchk(P, Visited),
            ready_dependencies_acyclic(P, [P|Visited]))).

%% session_plan(+Minutes, +Energy, +Today, -Tasks, -Used, -Unused) is det.
% Greedy, priority-first planning, not a global knapsack optimizer. Each step
% consumes positive minutes AND adds a new ID, providing two termination bounds.
% Selected tasks are assumed finished ONLY in the hypothetical plan; the real
% database is never changed. This unlocks later prerequisites within the session.
session_plan(Minutes, Energy, Today, Tasks, Used, Unused) :-
    check_context(Minutes, Energy, Today),
    plan_steps(Minutes, Energy, Today, [], Tasks, Unused),
    Used is Minutes - Unused.

plan_steps(Available, Energy, Today, Done, Tasks, Unused) :-
    ranked_assuming(Available, Energy, Today, Done, Candidates),
    ( Candidates = [Task|_] ->
      remaining_minutes(Task, Needed), Left is Available - Needed,
      Tasks = [Task|Tail],
      plan_steps(Left, Energy, Today, [Task|Done], Tail, Unused)
    ; Tasks = [], Unused = Available
    ).

%% goal_progress(+Goal, -Percent) is semidet.
% Arithmetic mean of non-archived task progress; an empty goal is 0%.
goal_progress(Goal, Percent) :-
    goal(Goal, _, _, _),
    findall(P, (task(Task, Goal, _, _), \+ task_status(Task, archived),
                progress(Task, P)), Values),
    ( Values == [] -> Percent = 0
    ; sum_list(Values, Total), length(Values, Count), Percent is round(Total/Count)
    ).

% ----- Data integrity -------------------------------------------------------

valid_id(Id) :-
    atom(Id), atom_codes(Id, [First|Rest]), between(97, 122, First),
    forall(member(C, Rest),
           (between(97, 122, C); between(48, 57, C); C =:= 95)).

valid_title(Title) :-
    atom(Title), atom_length(Title, N), N > 0, N =< 200,
    normalize_space(atom(Trimmed), Title), Trimmed \== ''.

valid_goal_record(Id, Title, Category, Status) :-
    valid_id(Id), valid_title(Title), goal_category(Category),
    goal_status_value(Status).

attribute(remaining_minutes).
attribute(difficulty).
attribute(priority).
attribute(deadline).
attribute(task_status).
attribute(progress).

single_attribute(Name, Id, Value) :-
    Term =.. [Name, Id, V], findall(V, task_facts:Term, [Value]).

task_well_formed(Id) :-
    findall(record(G, Title, Type), task(Id, G, Title, Type),
            [record(Goal, Title, Type)]),
    single_attribute(remaining_minutes, Id, Minutes),
    single_attribute(difficulty, Id, Difficulty),
    single_attribute(priority, Id, Priority),
    single_attribute(deadline, Id, Due),
    single_attribute(task_status, Id, Status),
    single_attribute(progress, Id, Percent),
    valid_task_record(Id, Goal, Title, Type, Minutes, Difficulty, Priority,
                      Due, Status, Percent).

valid_task_record(Id, Goal, Title, Type, Minutes, Difficulty, Priority,
                  Due, Status, Percent) :-
    valid_id(Id), valid_title(Title),
    goal(Goal, _, Category, _), task_type(Type, Category),
    integer(Minutes), Minutes >= 0, difficulty_level(Difficulty, _),
    priority_level(Priority, _), (Due == none -> true ; valid_date(Due)),
    task_status_value(Status), integer(Percent), between(0, 100, Percent),
    consistent_state(Status, Percent, Minutes).

consistent_state(pending, 0, Minutes) :- Minutes > 0.
consistent_state(in_progress, Percent, Minutes) :-
    Percent > 0, Percent < 100, Minutes > 0.
consistent_state(completed, 100, 0).
consistent_state(archived, Percent, Minutes) :-
    (Percent =:= 100 -> Minutes =:= 0 ; Minutes > 0).

%% validate_kb(-Errors) is det.
% A sorted list exposes every detected problem rather than stopping at the first.
validate_kb(Errors) :-
    findall(Error, validation_error(Error), Raw), sort(Raw, Errors).

validation_error(invalid_goal(Id)) :-
    goal(Id, Title, Category, Status),
    \+ valid_goal_record(Id, Title, Category, Status).
validation_error(duplicate_goal(Id)) :-
    goal(Id, _, _, _), findall(1, goal(Id, _, _, _), Matches), length(Matches, N), N > 1.
validation_error(invalid_task(Id)) :-
    task(Id, _, _, _), \+ task_well_formed(Id).
validation_error(orphan_attribute(Name, Id)) :-
    attribute(Name), Term =.. [Name, Id, _], task_facts:Term,
    \+ task(Id, _, _, _).
validation_error(invalid_dependency(Task, Prerequisite)) :-
    depends_on(Task, Prerequisite),
    (\+ task(Task, _, _, _); \+ task(Prerequisite, _, _, _)).
validation_error(duplicate_dependency(Task, Prerequisite)) :-
    depends_on(Task, Prerequisite),
    findall(1, depends_on(Task, Prerequisite), L), length(L, N), N > 1.
validation_error(dependency_cycle(Task)) :- dependency_cycle(Task, _).
validation_error(completed_task_has_unfinished_prerequisites(Task)) :-
    task_status(Task, completed), \+ prerequisites_complete(Task).

require_valid_kb :-
    validate_kb(Errors),
    (Errors == [] -> true ; throw(error(validation_error(Errors), _))).

knowledge_stats(stats{facts:Facts, goals:Goals, tasks:Tasks, dependencies:Dependencies}) :-
    module_property(task_facts, exports(Predicates)),
    findall(1, (member(Name/Arity, Predicates), functor(Head, Name, Arity),
                clause(task_facts:Head, true)), FactClauses),
    length(FactClauses, Facts), findall(G, goal(G, _, _, _), GL), length(GL, Goals),
    findall(T, task(T, _, _, _), TL), length(TL, Tasks),
    findall(T-P, depends_on(T, P), DL), length(DL, Dependencies).

% ----- Validated mutations --------------------------------------------------

ensure(Condition, Detail) :-
    (call(Condition) -> true ; throw(error(validation_error(Detail), _))).

add_goal(Id, Title, Category) :-
    ensure(ground(goal(Id, Title, Category)), ground_goal_required),
    ensure(valid_goal_record(Id, Title, Category, active), invalid_goal_fields),
    ensure(\+ goal(Id, _, _, _), duplicate_goal(Id)),
    transaction((assertz(task_facts:goal(Id, Title, Category, active)), require_valid_kb)).

%% add_task(+Id,+Goal,+Title,+Type,+Minutes,+Difficulty,+Priority,+Deadline).
% New tasks start pending at 0%; all fields must be supplied explicitly.
add_task(Id, Goal, Title, Type, Minutes, Difficulty, Priority, Due) :-
    ensure(ground(task(Id, Goal, Title, Type, Minutes, Difficulty, Priority, Due)),
           ground_task_required),
    ensure(\+ task(Id, _, _, _), duplicate_task(Id)),
    ensure(valid_task_record(Id, Goal, Title, Type, Minutes, Difficulty, Priority,
                             Due, pending, 0), invalid_task_fields),
    transaction((assertz(task_facts:task(Id, Goal, Title, Type)),
                 assertz(task_facts:remaining_minutes(Id, Minutes)),
                 assertz(task_facts:difficulty(Id, Difficulty)),
                 assertz(task_facts:priority(Id, Priority)),
                 assertz(task_facts:deadline(Id, Due)),
                 assertz(task_facts:task_status(Id, pending)),
                 assertz(task_facts:progress(Id, 0)), require_valid_kb)).

update_progress(Task, Percent, Minutes) :-
    ensure(ground(update(Task, Percent, Minutes)), ground_update_required),
    ensure(task(Task, _, _, _), unknown_task(Task)),
    ensure(\+ task_status(Task, archived), restore_archived_task_first),
    ensure((integer(Percent), between(0, 100, Percent), integer(Minutes),
            Minutes >= 0), invalid_progress_or_minutes),
    status_for_progress(Percent, Status),
    ensure(consistent_state(Status, Percent, Minutes), inconsistent_progress_or_minutes),
    transaction((retractall(task_facts:progress(Task, _)),
                 retractall(task_facts:remaining_minutes(Task, _)),
                 retractall(task_facts:task_status(Task, _)),
                 assertz(task_facts:progress(Task, Percent)),
                 assertz(task_facts:remaining_minutes(Task, Minutes)),
                 assertz(task_facts:task_status(Task, Status)), require_valid_kb)).

status_for_progress(Percent, Status) :-
    (Percent =:= 100 -> Status = completed
    ; Percent =:= 0 -> Status = pending
    ; Status = in_progress).

set_goal_status(Goal, Status) :-
    ensure(ground(goal(Goal, Status)), ground_update_required),
    ensure(goal(Goal, Title, Category, _), unknown_goal(Goal)),
    ensure(goal_status_value(Status), invalid_goal_status(Status)),
    transaction((retractall(task_facts:goal(Goal, _, _, _)),
                 assertz(task_facts:goal(Goal, Title, Category, Status)), require_valid_kb)).

set_archived(Task, Archived) :-
    ensure(ground(archive(Task, Archived)), ground_update_required),
    ensure(task(Task, _, _, _), unknown_task(Task)),
    ensure(memberchk(Archived, [true, false]), boolean_required),
    progress(Task, Percent),
    (Archived == true -> Status = archived ; status_for_progress(Percent, Status)),
    transaction((retractall(task_facts:task_status(Task, _)),
                 assertz(task_facts:task_status(Task, Status)), require_valid_kb)).

add_dependency(Task, Prerequisite) :-
    ensure(ground(depends_on(Task, Prerequisite)), ground_dependency_required),
    ensure((task(Task, _, _, _), task(Prerequisite, _, _, _)), unknown_dependency_task),
    ensure(\+ depends_on(Task, Prerequisite), duplicate_dependency(Task, Prerequisite)),
    transaction((assertz(task_facts:depends_on(Task, Prerequisite)), require_valid_kb)).

remove_dependency(Task, Prerequisite) :-
    ensure(ground(depends_on(Task, Prerequisite)), ground_dependency_required),
    ensure(depends_on(Task, Prerequisite), unknown_dependency(Task, Prerequisite)),
    transaction((retractall(task_facts:depends_on(Task, Prerequisite)), require_valid_kb)).
