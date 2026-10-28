:- use_module('planner.pl').
:- use_module('system_facts.pl').
:- use_module(library(plunit)).
:- use_module(library(http/json)).
:- ensure_loaded('scheduler_tests.pl').

:- begin_tests(adaptive_planner, [setup(planner:reset_user_data), cleanup(planner:reset_user_data)]).

add(Days, Type, Id) :-
    planner:add_task(_{title:"Test task", type:Type, days_left:Days, minutes:60}),
    findall(T, planner:user_task(T,_,_,_,_), All), last(All, Id).

test(system_knowledge_has_120_real_facts) :-
    planner:system_fact_count(120),
    findall(T, system_task(T), Types), length(Types,20),
    forall(member(Type,Types),
           (findall(C,task_category(Type,C),[_]), findall(M,typical_minutes(Type,M),[_]),
            findall(D,task_difficulty(Type,D),[_]), findall(P,task_priority(Type,P),[_]),
            findall(E,task_energy(Type,E),[_]))).

test(no_sample_user_records) :- \+ user_task(_,_,_,_,_), \+ user_class(_,_,_,_).

test(deadline_boundaries, [setup(planner:reset_user_data), cleanup(planner:reset_user_data)]) :-
    forall(member(Days-Group, [-1-do_first,0-do_first,1-do_first,2-do_first,
                              3-do_next,5-do_next,6-do_later,10-do_later]),
           (add(Days,"assignment",Id), planner:bucket(Id,Group))).

test(spec_examples, [setup(planner:reset_user_data), cleanup(planner:reset_user_data)]) :-
    add(1,"assignment",A), add(4,"reading",B), add(10,"cleaning",C),
    do_first(A), do_next(B), do_later(C),
    \+ soon(A), \+ urgent(B), \+ soon(C).

test(completed_excluded_and_reopen, [setup(planner:reset_user_data), cleanup(planner:reset_user_data)]) :-
    add(0,"assignment",Id), atom_string(Id,Text),
    planner:set_status(_{id:Text,status:"completed"}),
    \+ urgent(Id), \+ soon(Id), \+ can_wait(Id),
    planner:set_status(_{id:Text,status:"pending"}), urgent(Id).

test(time_fit_does_not_hide_urgent_tasks, [setup(planner:reset_user_data), cleanup(planner:reset_user_data)]) :-
    add(0,"assignment",_), snapshot(15,State), State.tasks = [Task],
    Task.bucket == do_first, Task.fits_time == false,
    snapshot(60,Exact), Exact.tasks = [Fits], Fits.fits_time == true.

test(deadline_before_type_priority, [setup(planner:reset_user_data), cleanup(planner:reset_user_data)]) :-
    add(2,"exam_review",Later), add(0,"cleaning",Earlier),
    snapshot(60,State), State.tasks = [First,Second], First.id == Earlier, Second.id == Later.

test(type_knowledge_breaks_equal_deadlines, [setup(planner:reset_user_data), cleanup(planner:reset_user_data)]) :-
    add(1,"cleaning",_), add(1,"exam_review",Exam),
    snapshot(60,State), State.tasks = [First|_], First.id == Exam,
    First.priority == high, First.difficulty == hard, First.energy == high.

test(deadlines_age_by_calendar_day, [setup(planner:reset_user_data), cleanup(planner:reset_user_data)]) :-
    add(3,"reading",Id), retract(planner:task_details(Id,Title,Due)),
    YesterdayDue is Due-1, assertz(planner:task_details(Id,Title,YesterdayDue)),
    snapshot(60,_), user_task(Id,reading,2,60,pending), urgent(Id).

test(same_title_gets_unique_ids, [setup(planner:reset_user_data), cleanup(planner:reset_user_data)]) :-
    add(1,"reading",A), add(1,"reading",B), A \== B.

test(text_is_data, [setup(planner:reset_user_data), cleanup(planner:reset_user_data)]) :-
    planner:add_task(_{title:"<script>alert('x')</script> :- halt.",type:"reading",days_left:2,minutes:30}),
    snapshot(60,State), State.tasks = [Task],
    Task.title == '<script>alert(\'x\')</script> :- halt.'.

test(invalid_type, [throws(error(validation_error(_),_))]) :- add(2,"unrecognized",_).
test(fractional_days, [throws(error(validation_error(_),_))]) :- add(1.5,"assignment",_).
test(blank_title, [throws(error(validation_error(_),_))]) :-
    planner:add_task(_{title:"   ",type:"assignment",days_left:1,minutes:60}).
test(missing_field, [throws(error(validation_error(_),_))]) :- planner:add_task(_{}).
test(zero_minutes, [throws(error(validation_error(_),_))]) :-
    planner:add_task(_{title:"Test",type:"assignment",days_left:1,minutes:0}).

test(class_minutes_and_weekday_order, [setup(planner:reset_user_data), cleanup(planner:reset_user_data)]) :-
    planner:add_class(_{day:"friday",subject:"AI",start:810,end:900}),
    planner:add_class(_{day:"monday",subject:"Networks",start:480,end:600}),
    user_class(monday,480,600,'Networks'), snapshot(60,State),
    State.classes = [First,Second], First.day == monday, Second.day == friday.

test(invalid_class_time, [throws(error(validation_error(_),_))]) :-
    planner:add_class(_{day:"monday",subject:"AI",start:600,end:480}).
test(invalid_weekday, [throws(error(validation_error(_),_))]) :-
    planner:add_class(_{day:"noday",subject:"AI",start:480,end:600}).
test(duplicate_class, [setup(planner:reset_user_data), cleanup(planner:reset_user_data),
                      throws(error(validation_error(_),_))]) :-
    Data = _{day:"monday",subject:"AI",start:480,end:600},
    planner:add_class(Data), planner:add_class(Data).

test(multiple_class_days,
     [setup(store_setup(File,Old)), cleanup(store_cleanup(File,Old))]) :-
    mutate(add_classes(_{days:["monday","wednesday","friday"],subject:"Networks",start:480,end:600})),
    planner:reset_user_data, init_store, snapshot(60,State),
    findall(Day, user_class(Day,480,600,'Networks'), Days),
    Days == [monday,wednesday,friday], length(State.classes,3).

test(empty_class_days, [throws(error(validation_error(_),_))]) :-
    planner:add_classes(_{days:[],subject:"AI",start:480,end:600}).

test(repeated_class_days, [throws(error(validation_error(_),_))]) :-
    planner:add_classes(_{days:["monday","monday"],subject:"AI",start:480,end:600}).

test(class_days_must_be_list, [throws(error(validation_error(_),_))]) :-
    planner:add_classes(_{days:"monday",subject:"AI",start:480,end:600}).

test(multiple_days_duplicate_rolls_back,
     [setup(store_setup(File,Old)), cleanup(store_cleanup(File,Old))]) :-
    mutate(add_classes(_{days:["wednesday"],subject:"AI",start:480,end:600})),
    catch(mutate(add_classes(_{days:["monday","wednesday"],subject:"AI",start:480,end:600})),
          error(validation_error(_),_), true),
    \+ user_class(monday,_,_,_), planner:reset_user_data, init_store,
    findall(Day,user_class(Day,_,_,_),[wednesday]).

test(multiple_days_invalid_rolls_back,
     [setup(store_setup(File,Old)), cleanup(store_cleanup(File,Old))]) :-
    catch(mutate(add_classes(_{days:["monday","noday"],subject:"AI",start:480,end:600})),
          error(validation_error(_),_), true),
    \+ user_class(_,_,_,_), \+ exists_file(File).

test(calendar_round_trip) :-
    planner:iso_day("2028-02-29", Day), planner:day_iso(Day,"2028-02-29"),
    \+ planner:iso_day("2026-02-30", _).

test(planning_preferences_and_task_options_persist,
     [setup(store_setup(File,Old)), cleanup(store_cleanup(File,Old))]) :-
    mutate(set_planning(_{day_start:540,day_end:1260})),
    mutate(add_task(_{title:"Quiz review",type:"exam_review",days_left:2,minutes:180,
                      subject:"Networks",deadline_time:600})),
    planner:reset_user_data,init_store,snapshot(60,State),
    State.planning_settings.day_start=:=540,State.planning_settings.day_end=:=1260,
    State.tasks=[T],T.subject=='Networks',T.deadline_time=:=600.

test(invalid_planning_hours,[throws(error(validation_error(_),_))]) :-
    planner:set_planning(_{day_start:1320,day_end:480}).

test(review_deadline_default_is_start_of_deadline_day,
     [setup(planner:reset_user_data),cleanup(planner:reset_user_data)]) :-
    add(2,"exam_review",Id),planner:task_options(Id,'',0).

test(persistence_and_atomic_replacement,
     [setup(store_setup(File,Old)), cleanup(store_cleanup(File,Old))]) :-
    mutate(add_task(_{title:"Keep me",type:"assignment",days_left:4,minutes:60})),
    mutate(add_class(_{day:"monday",subject:"AI",start:480,end:600})),
    planner:reset_user_data, init_store, snapshot(60,State),
    State.tasks = [Task], Task.title == 'Keep me', Task.bucket == do_next,
    State.classes = [Class], Class.subject == 'AI'.

test(save_failure_rolls_back,
     [setup(store_setup(File,Old)), cleanup(store_cleanup(File,Old))]) :-
    retractall(planner:store_path(_)),
    atom_concat(File,'/invalid/state.json',Impossible), assertz(planner:store_path(Impossible)),
    setup_call_cleanup(open(File,write,Out), write(Out,'occupied'), close(Out)),
    catch(mutate(add_task(_{title:"Rollback",type:"assignment",days_left:1,minutes:60})),_,true),
    \+ user_task(_,_,_,_,_).

test(invalid_load_rolls_back,
     [setup(planner:reset_user_data), cleanup(planner:reset_user_data)]) :-
    add(1,"assignment",Id),
    Bad = _{schema:1,tasks:[_{id:"bad",title:"Bad",type:"reading",due_date:"2026-02-30",minutes:30,status:"pending"}],classes:[]},
    catch(transaction(planner:load_data(Bad)),_,true), user_task(Id,_,_,_,_).

test(delete_task_and_class,
     [setup(planner:reset_user_data), cleanup(planner:reset_user_data)]) :-
    add(1,"assignment",Id), atom_string(Id,Text), planner:remove_task(_{id:Text}),
    \+ user_task(_,_,_,_,_), \+ planner:task_details(_,_,_),
    planner:add_class(_{day:"monday",subject:"AI",start:480,end:600}),
    planner:class_details(Class,_,_,_,_), atom_string(Class,ClassText),
    planner:remove_class(_{id:ClassText}), \+ user_class(_,_,_,_).

store_setup(File,Old) :-
    planner:reset_user_data, planner:store_path(Old), tmp_file(planner_tests,File),
    retractall(planner:store_path(_)), assertz(planner:store_path(File)).
store_cleanup(File,Old) :-
    planner:reset_user_data, retractall(planner:store_path(_)), assertz(planner:store_path(Old)),
    (exists_file(File) -> delete_file(File) ; true).

:- end_tests(adaptive_planner).
