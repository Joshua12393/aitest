:- module(task_planner, [main/0, demo/0, today/1, save_state/1, load_state/1]).

:- reexport('facts.pl').
:- reexport('rules.pl').
:- use_module(library(readutil)).
:- use_module(library(http/json)).
:- use_module(library(error)).
:- use_module(library(lists)).
:- use_module(library(pairs)).

/** <module> Task Planner entry point, menu, and JSON storage

Run: swipl -q -s proj.pl -g main -t halt
Demo: swipl -q -s proj.pl -g demo -t halt
Queries: swipl -q -s proj.pl, then recommend(60, medium, date(2026,10,26), T, E).

All input is read as plain text. No menu input is executed as Prolog code.
Loading this module has no menu or file-writing side effects. Save/load are
explicit actions. A saved snapshot is JSON data, never consulted as source.
*/

%% today(-Date) is det.
% The project uses the user's Asia/Manila calendar date (UTC+8, no DST).
today(date(Y, M, D)) :-
    get_time(Now), Manila is Now + 8*3600,
    stamp_date_time(Manila, date(Y, M, D, _, _, _, _, _, _), 'UTC').

main :-
    writeln('TASK PLANNER - Explainable Prolog recommendations'),
    writeln('Changes are kept in this session. Use Save before exiting.'),
    catch(menu_loop, Stop, finish_menu(Stop)).

finish_menu(stop_menu) :- writeln('Goodbye.').
finish_menu(end_of_input) :- writeln('\nInput closed. Goodbye.').

menu_loop :-
    nl,
    writeln('1 Goals              2 Tasks              3 Add goal'),
    writeln('4 Add task           5 Update progress    6 Recommend next'),
    writeln('7 Plan a session     8 Explain a task     9 Goal status'),
    writeln('10 Add dependency   11 Remove dependency 12 Archive/restore'),
    writeln('13 Save             14 Load              15 Validate / counts'),
    writeln('16 Fixed-date demo  17 Allowed values     0 Exit'),
    prompt_line('Choice: ', Choice),
    catch((menu_action(Choice) -> true ; writeln('Action could not complete.')),
          Error, menu_error(Error)),
    menu_loop.

menu_error(stop_menu) :- throw(stop_menu).
menu_error(end_of_input) :- throw(end_of_input).
menu_error(error(validation_error(Details), _)) :-
    format('Please check the data: ~w~n', [Details]).
menu_error(error(domain_error(Domain, Value), _)) :-
    format('Expected ~w; received ~w.~n', [Domain, Value]).
menu_error(error(type_error(Type, Value), _)) :-
    format('Expected ~w; received ~w.~n', [Type, Value]).
menu_error(Error) :- message_to_string(Error, Message), writeln(Message).

menu_action("0") :- throw(stop_menu).
menu_action("1") :- show_goals.
menu_action("2") :- show_tasks.
menu_action("3") :-
    prompt_atom('Goal ID (lowercase letters, digits, underscores): ', Id),
    prompt_atom('Title: ', Title), show_categories,
    prompt_atom('Category: ', Category), add_goal(Id, Title, Category),
    writeln('Goal added.').
menu_action("4") :-
    show_goals,
    prompt_atom('Task ID (lowercase letters, digits, underscores): ', Id),
    prompt_atom('Goal ID: ', Goal), prompt_atom('Title: ', Title),
    show_types_for_goal(Goal), prompt_atom('Task type: ', Type),
    prompt_integer('Estimated remaining minutes (> 0): ', Minutes),
    prompt_atom('Difficulty (easy/moderate/hard/very_hard): ', Difficulty),
    prompt_atom('Priority (urgent/high/medium/low): ', Priority),
    prompt_deadline(Due), add_task(Id, Goal, Title, Type, Minutes, Difficulty, Priority, Due),
    writeln('Task added at 0% progress.').
menu_action("5") :-
    prompt_atom('Task ID: ', Task),
    prompt_integer('Progress percent (0 to 100): ', Percent),
    prompt_integer('Remaining minutes (0 only when complete): ', Minutes),
    update_progress(Task, Percent, Minutes), writeln('Progress and status updated.').
menu_action("6") :-
    prompt_context(Minutes, Energy, Date),
    recommend(Minutes, Energy, Date, _, Explanation), print_explanation(Explanation).
menu_action("7") :-
    prompt_context(Minutes, Energy, Date),
    session_plan(Minutes, Energy, Date, Tasks, Used, Unused),
    print_plan(Tasks, Used, Unused).
menu_action("8") :-
    prompt_atom('Task ID: ', Task), known_task(Task),
    prompt_context(Minutes, Energy, Date),
    explain_task(Task, Minutes, Energy, Date, Explanation), print_explanation(Explanation).
menu_action("9") :-
    prompt_atom('Goal ID: ', Goal),
    prompt_atom('Status (active/paused/completed/abandoned): ', Status),
    set_goal_status(Goal, Status), writeln('Goal status updated.').
menu_action("10") :-
    prompt_atom('Task that must wait: ', Task),
    prompt_atom('Prerequisite task ID: ', Prerequisite),
    add_dependency(Task, Prerequisite), writeln('Dependency added.').
menu_action("11") :-
    prompt_atom('Task ID: ', Task), prompt_atom('Prerequisite task ID: ', Prerequisite),
    remove_dependency(Task, Prerequisite), writeln('Dependency removed.').
menu_action("12") :-
    prompt_atom('Task ID: ', Task),
    prompt_atom('Archive? true = archive; false = restore: ', Archived),
    set_archived(Task, Archived), writeln('Task status updated.').
menu_action("13") :-
    project_file('state.json', File), save_state(File), format('Saved: ~w~n', [File]).
menu_action("14") :-
    project_file('state.json', File), load_state(File),
    writeln('Saved data loaded and validated.').
menu_action("15") :- show_validation.
menu_action("16") :- demo.
menu_action("17") :- show_allowed_values.
menu_action(Choice) :-
    \+ memberchk(Choice, ["0","1","2","3","4","5","6","7","8","9",
                          "10","11","12","13","14","15","16","17"]),
    writeln('Choose a number from 0 to 17.').

prompt_line(Label, Text) :-
    format('~w', [Label]), flush_output,
    read_line_to_string(user_input, Raw),
    (Raw == end_of_file -> throw(end_of_input) ; normalize_space(string(Text), Raw)).

prompt_atom(Label, Atom) :- prompt_line(Label, Text), atom_string(Atom, Text).

prompt_integer(Label, Number) :-
    prompt_line(Label, Text),
    ( catch(number_string(Number, Text), _, fail), integer(Number) -> true
    ; throw(error(validation_error(integer_required(Text)), _))
    ).

prompt_deadline(Due) :-
    prompt_line('Deadline (YYYY-MM-DD or none): ', Text),
    (Text == "none" -> Due = none ; parse_date_text(Text, Due)).

parse_date_text(Text, date(Y, M, D)) :-
    ( split_string(Text, "-", "", [YS, MS, DS]),
      string_length(YS, 4), string_length(MS, 2), string_length(DS, 2),
      catch((number_string(Y, YS), number_string(M, MS), number_string(D, DS)), _, fail),
      valid_date(date(Y, M, D)) -> true
    ; throw(error(validation_error(invalid_date(Text)), _))
    ).

prompt_context(Minutes, Energy, Date) :-
    prompt_integer('Available minutes (0 or more): ', Minutes),
    prompt_atom('Energy (low/medium/high): ', Energy),
    today(Today), date_text(Today, Default),
    format('Today in Manila: ~w. Demo reference: 2026-10-26.~n', [Default]),
    prompt_line('Reference date (YYYY-MM-DD, demo, or Enter for today): ', Text),
    (Text == "" -> Date = Today
    ; Text == "demo" -> demo_date(Date)
    ; parse_date_text(Text, Date)),
    check_context(Minutes, Energy, Date).

known_task(Task) :-
    (task(Task, _, _, _) -> true ; throw(error(validation_error(unknown_task(Task)), _))).

show_goals :-
    forall(goal(Id, Title, Category, Status),
           (goal_progress(Id, Percent),
            format('~w | ~w | ~w | ~w | ~d%~n', [Id, Title, Category, Status, Percent]))).

show_tasks :-
    forall(task(Id, Goal, Title, Type),
           (remaining_minutes(Id, Minutes), priority(Id, Priority),
            difficulty(Id, Difficulty), deadline(Id, Due), date_text(Due, DueText),
            task_status(Id, Status), progress(Id, Percent),
            findall(P, depends_on(Id, P), Prerequisites),
            format('~n~w: ~w~n', [Id, Title]),
            format('  Goal: ~w; type: ~w; status: ~w; progress: ~d%~n',
                   [Goal, Type, Status, Percent]),
            format('  ~d min; ~w; priority ~w; due ~w; prerequisites ~w~n',
                   [Minutes, Difficulty, Priority, DueText, Prerequisites]))).

show_categories :-
    findall(C, goal_category(C), Categories), format('Categories: ~w~n', [Categories]).

show_types_for_goal(Goal) :-
    (goal(Goal, _, Category, _) ->
     findall(T, task_type(T, Category), Types), format('Task types: ~w~n', [Types])
    ; throw(error(validation_error(unknown_goal(Goal)), _))).

show_allowed_values :-
    show_categories,
    forall(goal_category(Category),
           (findall(T, task_type(T, Category), Types), format('~w: ~w~n', [Category, Types]))),
    writeln('Priorities: urgent, high, medium, low'),
    writeln('Difficulties: easy, moderate, hard, very_hard'),
    writeln('Energy levels: low, medium, high'),
    writeln('Task status follows progress; archive/restore is a separate action.').

show_validation :-
    knowledge_stats(S), validate_kb(Errors),
    format('Facts: ~d; goals: ~d; tasks: ~d; dependencies: ~d~n',
           [S.facts, S.goals, S.tasks, S.dependencies]),
    (Errors == [] -> writeln('Validation: no integrity errors.')
    ; format('Validation errors: ~w~n', [Errors])).

date_text(none, none).
date_text(date(Y, M, D), Text) :- format(atom(Text), '~|~`0t~d~4+-~|~`0t~d~2+-~|~`0t~d~2+', [Y, M, D]).

print_explanation(E) :-
    format('~n~w (~w)~n', [E.title, E.task]),
    (E.eligible == true -> writeln('Eligible for this session.')
    ; writeln('Not eligible for this session.')),
    forall(member(B, E.blockers), print_blocker(B)),
    forall(member(R, E.reasons), print_reason(R)).

print_blocker(no_eligible_tasks) :- writeln('  No unfinished, available task fits this context.').
print_blocker(completed) :- writeln('  This task is already completed.').
print_blocker(archived) :- writeln('  This task is archived.').
print_blocker(invalid_task_record) :- writeln('  This task has invalid or missing attributes.').
print_blocker(inactive_goal(Goal, Status)) :- format('  Goal ~w is ~w.~n', [Goal, Status]).
print_blocker(insufficient_time(Needed, Available)) :-
    format('  Needs ~d minutes; only ~d are available.~n', [Needed, Available]).
print_blocker(unfinished_prerequisites(Tasks)) :- format('  Finish prerequisites: ~w.~n', [Tasks]).
print_blocker(cyclic_dependencies) :- writeln('  A missing or circular dependency blocks this task.').

print_reason(deadline(Band, Days)) :-
    (Days == none -> writeln('  No deadline is set.')
    ; Days < 0 -> Late is -Days, format('  Overdue by ~d calendar day(s).~n', [Late])
    ; format('  Deadline: ~w; ~d calendar day(s) away.~n', [Band, Days])).
print_reason(priority(Priority)) :- format('  User-assigned priority: ~w.~n', [Priority]).
print_reason(time_required(Needed, Available)) :-
    format('  Estimated remaining work: ~d of ~d available minutes.~n', [Needed, Available]).
print_reason(energy_gap(Penalty)) :-
    (Penalty =:= 0 -> writeln('  Difficulty matches the current energy level.')
    ; writeln('  Difficulty exceeds current energy; deadline and priority still come first.')).
print_reason(progress(Percent)) :- format('  Progress: ~d%.~n', [Percent]).
print_reason(unfinished_prerequisites(Tasks)) :-
    (Tasks == [] -> writeln('  All prerequisites are complete.') ; true).

print_plan(Tasks, Used, Unused) :-
    writeln('\nSuggested order (assumes each selected task is finished):'),
    (Tasks == [] -> writeln('  No task fits.') ; print_plan_items(Tasks, 1)),
    format('Used: ~d minutes. Unused: ~d minutes.~n', [Used, Unused]),
    writeln('This is a priority-first plan; progress has not been changed.').

print_plan_items([], _).
print_plan_items([Task|Tail], Position) :-
    task(Task, _, Title, _), remaining_minutes(Task, Minutes),
    format('  ~d. ~w (~w, ~d min)~n', [Position, Title, Task, Minutes]),
    Next is Position + 1, print_plan_items(Tail, Next).

demo :-
    writeln('\nDEMONSTRATION - current data, fixed date 2026-10-26'),
    show_validation, demo_date(Date),
    recommend(60, medium, Date, _, Explanation), print_explanation(Explanation),
    session_plan(60, medium, Date, Tasks, Used, Unused), print_plan(Tasks, Used, Unused),
    writeln('\nWhy proofreading must wait:'),
    explain_task(proofread_paper, 60, medium, Date, Blocked), print_explanation(Blocked).

% ----- Explicit JSON persistence -------------------------------------------

project_file(Name, File) :-
    source_file(task_planner:main, Source), file_directory_name(Source, Directory),
    directory_file_path(Directory, Name, File).

%% save_state(+File) is det.
% Write a sibling temporary file and rename it only after a successful close.
save_state(File) :-
    must_be(atom, File), require_valid_kb, state_dict(State),
    atom_concat(File, '.tmp', Temporary),
    catch((setup_call_cleanup(open(Temporary, write, Out, [encoding(utf8)]),
                              json_write_dict(Out, State, [width(0)]), close(Out)),
           rename_file(Temporary, File)),
          Error, (catch(delete_file(Temporary), _, true), throw(Error))).

state_dict(_{version:1, goals:Goals, tasks:Tasks, dependencies:Dependencies}) :-
    findall(_{id:Id, title:Title, category:Category, status:Status},
            goal(Id, Title, Category, Status), Goals),
    findall(_{id:Id, goal:Goal, title:Title, type:Type, minutes:Minutes,
              difficulty:Difficulty, priority:Priority, deadline:DueJSON,
              status:Status, progress:Progress},
            (task(Id, Goal, Title, Type), remaining_minutes(Id, Minutes),
             difficulty(Id, Difficulty), priority(Id, Priority), deadline(Id, Due),
             date_json(Due, DueJSON), task_status(Id, Status), progress(Id, Progress)), Tasks),
    findall(_{task:Task, prerequisite:Prerequisite}, depends_on(Task, Prerequisite), Dependencies).

date_json(none, none).
date_json(date(Y, M, D), _{year:Y, month:M, day:D}).

%% load_state(+File) is det or throws.
% JSON is parsed as data. A transaction preserves the previous database if the
% snapshot has missing fields, bad references, invalid dates, or cycles.
load_state(File) :-
    must_be(atom, File),
    setup_call_cleanup(open(File, read, In, [encoding(utf8)]),
                       read_state_json(In, State), close(In)),
    (state_schema(State) -> true ; throw(error(validation_error(invalid_snapshot_schema), _))),
    transaction((clear_state, restore_state(State), require_valid_kb)).

read_state_json(In, State) :-
    json_read_dict(In, State, [value_string_as(atom)]),
    read_string(In, _, Rest), normalize_space(string(Trailing), Rest),
    (Trailing == "" -> true
    ; throw(error(validation_error(trailing_snapshot_content), _))).

has_keys(Dict, Expected) :-
    is_dict(Dict), dict_pairs(Dict, _, Pairs), pairs_keys(Pairs, Keys),
    sort(Expected, Sorted), Keys == Sorted.

state_schema(State) :-
    has_keys(State, [version, goals, tasks, dependencies]), State.version == 1,
    is_list(State.goals), is_list(State.tasks), is_list(State.dependencies),
    forall(member(G, State.goals), has_keys(G, [id, title, category, status])),
    forall(member(T, State.tasks),
           (has_keys(T, [id, goal, title, type, minutes, difficulty, priority,
                         deadline, status, progress]), valid_json_date(T.deadline))),
    forall(member(D, State.dependencies), has_keys(D, [task, prerequisite])).

valid_json_date(none).
valid_json_date(Date) :- has_keys(Date, [year, month, day]).

clear_state :-
    retractall(task_facts:goal(_, _, _, _)), retractall(task_facts:task(_, _, _, _)),
    retractall(task_facts:remaining_minutes(_, _)), retractall(task_facts:difficulty(_, _)),
    retractall(task_facts:priority(_, _)), retractall(task_facts:deadline(_, _)),
    retractall(task_facts:task_status(_, _)), retractall(task_facts:progress(_, _)),
    retractall(task_facts:depends_on(_, _)).

restore_state(State) :-
    forall(member(G, State.goals),
           assertz(task_facts:goal(G.id, G.title, G.category, G.status))),
    forall(member(T, State.tasks), restore_task(T)),
    forall(member(D, State.dependencies), assertz(task_facts:depends_on(D.task, D.prerequisite))).

restore_task(T) :-
    json_date(T.deadline, Due),
    assertz(task_facts:task(T.id, T.goal, T.title, T.type)),
    assertz(task_facts:remaining_minutes(T.id, T.minutes)),
    assertz(task_facts:difficulty(T.id, T.difficulty)),
    assertz(task_facts:priority(T.id, T.priority)), assertz(task_facts:deadline(T.id, Due)),
    assertz(task_facts:task_status(T.id, T.status)), assertz(task_facts:progress(T.id, T.progress)).

json_date(none, none).
json_date(Date, date(Y, M, D)) :- is_dict(Date), Y = Date.year, M = Date.month, D = Date.day.
