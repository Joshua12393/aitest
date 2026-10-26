:- module(planner, [init_store/0, mutate/1, snapshot/2, user_task/5, user_class/4,
                    urgent/1, soon/1, can_wait/1, do_first/1, do_next/1, do_later/1]).
:- use_module('system_facts.pl').
:- use_module(library(http/json)).
:- use_module(library(filesex)).
:- use_module(library(uuid)).
:- use_module(library(date)).
:- use_module(library(pairs)).
:- dynamic user_task/5, user_class/4, task_details/3, class_details/5, store_path/1.
:- prolog_load_context(directory, Dir),
   directory_file_path(Dir, 'data/state.json', File), assertz(store_path(File)).

% SYSTEM facts describe task types; these dynamic predicates describe actual users.
% user_task(Id, Type, DaysLeft, EstimatedMinutes, Status).
% user_class(Day, StartMinuteOfDay, EndMinuteOfDay, Subject).
% Keep real due dates as metadata so DaysLeft can be refreshed as days pass.

urgent(Task) :- user_task(Task, _, Days, _, pending), Days =< 2.
soon(Task) :- user_task(Task, _, Days, _, pending), Days >= 3, Days =< 5.
can_wait(Task) :- user_task(Task, _, Days, _, pending), Days > 5.
do_first(Task) :- urgent(Task).
do_next(Task) :- soon(Task).
do_later(Task) :- can_wait(Task).

check(Goal, Message) :-
    (call(Goal) -> true ; throw(error(validation_error(Message), _))).

field(Body, Key, Value) :-
    check(is_dict(Body), 'Expected an object.'),
    format(string(Message), 'Missing field: ~w.', [Key]),
    check(get_dict(Key, Body, Value), Message).

text_field(Body, Key, Atom) :-
    field(Body, Key, Text),
    check(string(Text), 'Text fields must be strings.'),
    normalize_space(string(Clean), Text), string_length(Clean, N),
    check((N > 0, N =< 200), 'Text must contain 1 to 200 characters.'),
    atom_string(Atom, Clean).

integer_field(Body, Key, Min, Max, Value) :-
    field(Body, Key, Value),
    format(string(Message), '~w must be a whole number between ~w and ~w.', [Key, Min, Max]),
    check((integer(Value), between(Min, Max, Value)), Message).

% UTC midnight arithmetic prevents DST and time-of-day rounding errors.
today_day(Day) :-
    get_time(Now), Manila is Now + 8*3600,
    Day is floor(Manila / 86400).

iso_day(Text, Day) :-
    string(Text), string_length(Text, 10),
    split_string(Text, "-", "", [YS, MS, DS]),
    maplist(number_string, [Y,M,D], [YS,MS,DS]),
    integer(Y), integer(M), integer(D), between(1900, 9999, Y),
    catch(date_time_stamp(date(Y,M,D,0,0,0,0,-,-), Stamp), _, fail),
    stamp_date_time(Stamp, date(Y,M,D,_,_,_,_,_,_), 'UTC'),
    format_time(string(Text), '%Y-%m-%d', date(Y,M,D,0,0,0,0,'UTC',-)),
    Day is floor(Stamp / 86400).

day_iso(Day, Text) :-
    Stamp is Day*86400, stamp_date_time(Stamp, Date, 'UTC'),
    format_time(string(Text), '%Y-%m-%d', Date).

refresh_deadlines :-
    today_day(Today),
    forall(task_details(Id, _, Due),
           (retract(user_task(Id, Type, _, Minutes, Status)),
            Days is Due-Today, assertz(user_task(Id, Type, Days, Minutes, Status)))).

add_task(Body) :-
    text_field(Body, title, Title), text_field(Body, type, Type),
    check(system_task(Type), 'Choose a known task type.'),
    integer_field(Body, days_left, -36500, 36500, Days),
    integer_field(Body, minutes, 1, 10080, Minutes),
    today_day(Today), Due is Today+Days, uuid(Id),
    assertz(user_task(Id, Type, Days, Minutes, pending)),
    assertz(task_details(Id, Title, Due)).

set_status(Body) :-
    text_field(Body, id, Id), text_field(Body, status, Status),
    check(memberchk(Status, [pending, completed]), 'Status must be pending or completed.'),
    check(retract(user_task(Id, Type, Days, Minutes, _)), 'Task no longer exists.'),
    assertz(user_task(Id, Type, Days, Minutes, Status)).

remove_task(Body) :-
    text_field(Body, id, Id),
    check(retract(user_task(Id, _, _, _, _)), 'Task no longer exists.'),
    retractall(task_details(Id, _, _)).

day_name(Day) :- memberchk(Day, [monday,tuesday,wednesday,thursday,friday,saturday,sunday]).

class_fields(Body, Day, Start, End, Subject) :-
    text_field(Body, day, Day), check(day_name(Day), 'Choose a valid weekday.'),
    text_field(Body, subject, Subject),
    integer_field(Body, start, 0, 1439, Start),
    integer_field(Body, end, 1, 1440, End),
    check(End > Start, 'Class end must be after its start on the same day.').

add_class(Body) :-
    class_fields(Body, Day, Start, End, Subject),
    check(\+ user_class(Day, Start, End, Subject), 'This class is already saved.'),
    uuid(Id), assertz(user_class(Day, Start, End, Subject)),
    assertz(class_details(Id, Day, Start, End, Subject)).

remove_class(Body) :-
    text_field(Body, id, Id),
    check(retract(class_details(Id, Day, Start, End, Subject)), 'Class no longer exists.'),
    retractall(user_class(Day, Start, End, Subject)).

% All HTTP threads share one local planner. Serialize read/write and persist each
% change before acknowledging it. A failed save rolls the Prolog transaction back.
mutate(Action) :-
    with_mutex(planner_state, transaction((apply_action(Action), save_store))).

apply_action(add_task(Body)) :- add_task(Body).
apply_action(set_status(Body)) :- set_status(Body).
apply_action(remove_task(Body)) :- remove_task(Body).
apply_action(add_class(Body)) :- add_class(Body).
apply_action(remove_class(Body)) :- remove_class(Body).

bucket(Id, do_first) :- do_first(Id), !.
bucket(Id, do_next) :- do_next(Id), !.
bucket(Id, do_later) :- do_later(Id), !.
bucket(_, completed).

priority_order(high, 0).
priority_order(medium, 1).
priority_order(low, 2).
difficulty_order(hard, 0).
difficulty_order(medium, 1).
difficulty_order(easy, 2).

% Deadline first; system priority, difficulty, duration, and ID break ties.
task_json(Available, key(Days, P, D, Minutes, Id), Json) :-
    user_task(Id, Type, Days, Minutes, Status), task_details(Id, Title, Due),
    task_category(Type, Category), task_priority(Type, Priority),
    task_difficulty(Type, Difficulty), task_energy(Type, Energy),
    typical_minutes(Type, Typical), priority_order(Priority, P), difficulty_order(Difficulty, D),
    bucket(Id, Bucket), day_iso(Due, DueText),
    (Minutes =< Available -> Fits = true ; Fits = false),
    reason(Bucket, Days, Reason),
    Json = _{id:Id, title:Title, type:Type, category:Category, days_left:Days,
             due_date:DueText, minutes:Minutes, status:Status, bucket:Bucket,
             priority:Priority, difficulty:Difficulty, energy:Energy,
             typical_minutes:Typical, fits_time:Fits, reason:Reason}.

reason(completed, _, 'Completed tasks are excluded from recommendations.') :- !.
reason(_, Days, Text) :-
    (Days < 0 -> Late is -Days, format(string(Text), 'Overdue by ~w day(s); do this first.', [Late])
    ; Days =:= 0 -> Text = 'Due today; do this first.'
    ; Days =< 2 -> format(string(Text), 'Due in ~w day(s), within the urgent 2-day window.', [Days])
    ; Days =< 5 -> format(string(Text), 'Due in ~w days, within the 3-5 day window.', [Days])
    ; format(string(Text), 'Due in ~w days; more than 5 days remain.', [Days])).

type_json(Json) :-
    system_task(Type), task_category(Type, Category), typical_minutes(Type, Minutes),
    task_difficulty(Type, Difficulty), task_priority(Type, Priority), task_energy(Type, Energy),
    Json = _{id:Type, category:Category, minutes:Minutes, difficulty:Difficulty,
             priority:Priority, energy:Energy}.

class_json(key(DayOrder, Start, Id), Json) :-
    class_details(Id, Day, Start, End, Subject),
    nth1(DayOrder, [monday,tuesday,wednesday,thursday,friday,saturday,sunday], Day),
    Json = _{id:Id, day:Day, start:Start, end:End, subject:Subject}.

snapshot(Available, State) :-
    check((integer(Available), between(0,10080,Available)), 'Invalid available minutes.'),
    with_mutex(planner_state, snapshot_locked(Available, State)).

snapshot_locked(Available, State) :-
    refresh_deadlines,
    findall(Key-Json, task_json(Available, Key, Json), Pairs), keysort(Pairs, Sorted),
    pairs_values(Sorted, Tasks),
    findall(Key-Json, class_json(Key, Json), ClassPairs), keysort(ClassPairs, ClassesSorted),
    pairs_values(ClassesSorted, Classes), findall(Type, type_json(Type), Types),
    system_fact_count(FactCount), today_day(Today), day_iso(Today, TodayText),
    State = _{today:TodayText, timezone:'Asia/Manila', available_minutes:Available,
              tasks:Tasks, classes:Classes, types:Types, system_fact_count:FactCount}.

system_fact_count(Count) :-
    module_property(system_facts, exports(Predicates)),
    findall(1, (member(Name/Arity, Predicates), functor(Head, Name, Arity),
                clause(system_facts:Head, true)), Facts), length(Facts, Count).

saved_task(Json) :-
    user_task(Id, Type, _, Minutes, Status), task_details(Id, Title, Due), day_iso(Due, ISO),
    Json = _{id:Id, title:Title, type:Type, due_date:ISO, minutes:Minutes, status:Status}.

save_store :-
    store_path(File), file_directory_name(File, Dir), make_directory_path(Dir),
    atom_concat(File, '.tmp', Temp),
    findall(T, saved_task(T), Tasks), findall(C, class_json(_, C), Classes),
    catch((setup_call_cleanup(open(Temp, write, Out, [encoding(utf8)]),
                             json_write_dict(Out, _{schema:1, tasks:Tasks, classes:Classes}),
                             close(Out)),
           rename_file(Temp, File)), Error,
          ((exists_file(Temp) -> delete_file(Temp) ; true), throw(Error))).

init_store :-
    (getenv('PLANNER_STATE', Override) -> retractall(store_path(_)), assertz(store_path(Override)) ; true),
    store_path(File),
    (exists_file(File)
    -> setup_call_cleanup(open(File, read, In, [encoding(utf8)]), json_read_dict(In, Data), close(In)),
       transaction(load_data(Data))
    ; true).

load_data(Data) :-
    check((is_dict(Data), Data.get(schema) == 1,
           is_list(Data.get(tasks)), is_list(Data.get(classes))), 'Unsupported saved data.'),
    reset_user_data,
    maplist(load_task, Data.tasks), maplist(load_class, Data.classes).

load_task(Data) :-
    text_field(Data, id, Id), text_field(Data, title, Title), text_field(Data, type, Type),
    text_field(Data, status, Status), field(Data, due_date, ISO),
    integer_field(Data, minutes, 1, 10080, Minutes),
    check((system_task(Type), memberchk(Status,[pending,completed]),
           \+ user_task(Id,_,_,_,_)), 'Invalid or duplicate saved task.'),
    check(iso_day(ISO, Due), 'Invalid saved deadline.'), today_day(Today), Days is Due-Today,
    assertz(user_task(Id, Type, Days, Minutes, Status)), assertz(task_details(Id, Title, Due)).

load_class(Data) :-
    text_field(Data, id, Id), class_fields(Data, Day, Start, End, Subject),
    check((\+ class_details(Id,_,_,_,_), \+ user_class(Day,Start,End,Subject)), 'Duplicate saved class.'),
    assertz(class_details(Id,Day,Start,End,Subject)), assertz(user_class(Day,Start,End,Subject)).

reset_user_data :-
    retractall(user_task(_,_,_,_,_)), retractall(task_details(_,_,_)),
    retractall(user_class(_,_,_,_)), retractall(class_details(_,_,_,_,_)).
