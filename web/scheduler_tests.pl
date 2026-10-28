:- use_module('scheduler.pl').
:- use_module(library(plunit)).
:- use_module(library(lists)).

:- begin_tests(scheduler).

settings(_{day_start:480,day_end:1320}).
class(Id,Day,Start,End,_{id:Id,day:Day,start:Start,end:End,subject:Id}).
task(Id,Minutes,Date,Time,_{id:Id,title:Id,minutes:Minutes,due_date:Date,
                          deadline_time:Time,subject:'Networks',status:pending}).
classes(Classes) :-
    class(networks,wednesday,480,540,A),class(ai,wednesday,540,600,B),
    class(software,wednesday,660,720,C),Classes=[A,B,C].

test(fixed_review_reserves_time_and_keeps_total) :-
    settings(S),classes(C),task(review,180,"2026-10-29",0,T),
    F=_{id:chosen,task_id:review,date:"2026-10-28",start:900,end:960},
    build_plan("2026-10-28",480,S,[T],C,[F],P),
    P.sessions=[Pinned,A,B],Pinned.manual_id == chosen,
    A.start=:=600,A.end=:=660,B.start=:=720,B.end=:=780,
    P.tasks=[Summary],Summary.required_minutes=:=180,Summary.scheduled_minutes=:=180.

test(other_work_avoids_fixed_session) :-
    settings(S),task(one,60,"2026-10-29",0,A),task(two,180,"2026-10-29",0,B),
    F=_{id:chosen,task_id:one,date:"2026-10-28",start:540,end:600},
    build_plan("2026-10-28",480,S,[A,B],[],[F],P),
    forall((member(E,P.sessions),E.task_id == two),(E.end =< 540; E.start >= 600)).

test(completed_fixed_work_is_excluded) :-
    settings(S),task(one,60,"2026-10-29",0,T),Done=T.put(status,completed),
    F=_{id:chosen,task_id:one,date:"2026-10-28",start:540,end:600},
    build_plan("2026-10-28",480,S,[Done],[],[F],P),P.sessions == [],P.tasks == [].

test(interleaves_work_between_classes) :-
    settings(S),classes(C),task(review,60,"2026-10-29",0,T),
    build_plan("2026-10-28",480,S,[T],C,P),
    P.sessions=[Session],Session.start=:=600,Session.end=:=660,
    day_timeline("2026-10-28","2026-10-28",480,S,C,P,Timeline),
    findall(Kind,(member(E,Timeline.events),Kind=E.kind),[class,class,task,class,free]).

test(three_hour_review_split_across_gaps) :-
    settings(S),classes(C),task(review,180,"2026-10-29",0,T),
    build_plan("2026-10-28",480,S,[T],C,P),
    P.sessions=[A,B],A.start=:=600,A.end=:=660,B.start=:=720,B.end=:=840,
    P.tasks=[Summary],Summary.scheduled_minutes=:=180,Summary.unscheduled_minutes=:=0.

test(overlapping_classes_are_one_occupied_interval) :-
    settings(S),class(a,wednesday,480,600,A),class(b,wednesday,540,660,B),
    task(review,60,"2026-10-29",0,T),build_plan("2026-10-28",480,S,[T],[A,B],P),
    P.sessions=[Session],Session.start=:=660,Session.end=:=720.

test(nested_and_adjacent_classes) :-
    settings(S),class(a,wednesday,480,660,A),class(b,wednesday,540,600,B),
    class(c,wednesday,660,720,C),task(review,60,"2026-10-29",0,T),
    build_plan("2026-10-28",480,S,[T],[A,B,C],P),P.sessions=[E],E.start=:=720.

test(past_time_is_never_suggested) :-
    settings(S),task(review,60,"2026-10-29",0,T),
    build_plan("2026-10-28",637,S,[T],[],P),P.sessions=[E],E.start=:=637.

test(full_today_continues_tomorrow) :-
    settings(S),class(a,wednesday,480,1320,C),task(review,180,"2026-10-30",0,T),
    build_plan("2026-10-28",480,S,[T],[C],P),
    P.sessions=[E],E.date=="2026-10-29",E.start=:=480,E.end=:=660.

test(exact_deadline_clips_a_session_and_reports_shortage) :-
    settings(S),class(a,wednesday,480,600,C),task(review,90,"2026-10-28",630,T),
    build_plan("2026-10-28",480,S,[T],[C],P),P.sessions=[E],E.start=:=600,E.end=:=630,
    P.tasks=[Summary],Summary.unscheduled_minutes=:=60.

test(no_space_does_not_hide_shortage) :-
    settings(S),class(a,wednesday,480,1320,C),task(review,180,"2026-10-29",0,T),
    build_plan("2026-10-28",480,S,[T],[C],P),P.sessions==[],
    P.tasks=[Summary],Summary.unscheduled_minutes=:=180.

test(overdue_task_does_not_get_an_after_deadline_slot) :-
    settings(S),task(review,60,"2026-10-27",1200,T),
    build_plan("2026-10-28",480,S,[T],[],P),P.sessions==[],
    P.tasks=[Summary],Summary.unscheduled_minutes=:=60.

test(completed_work_is_not_allocated) :-
    settings(S),task(review,60,"2026-10-29",0,T),put_dict(status,T,completed,Done),
    build_plan("2026-10-28",480,S,[Done],[],P),P.sessions==[],P.tasks==[].

test(multiple_tasks_never_overlap) :-
    settings(S),task(a,120,"2026-10-29",0,A),task(b,180,"2026-10-30",0,B),
    build_plan("2026-10-28",480,S,[A,B],[],P),P.sessions=[First,Second],
    First.start=:=480,First.end=:=600,Second.start=:=600,Second.end=:=780.

test(earlier_clock_deadline_comes_before_later_clock) :-
    settings(S),task(later,60,"2026-10-28",720,A),task(earlier,60,"2026-10-28",540,B),
    build_plan("2026-10-28",480,S,[A,B],[],P),P.sessions=[First,Second],
    First.task_id==earlier,First.end=:=540,Second.task_id==later.

test(respects_changed_planning_hours) :-
    S=_{day_start:600,day_end:660},task(review,90,"2026-10-29",0,T),
    build_plan("2026-10-28",0,S,[T],[],P),P.sessions=[E],E.start=:=600,E.end=:=660,
    P.tasks=[Summary],Summary.unscheduled_minutes=:=30.

test(classes_outside_planning_hours_still_appear) :-
    settings(S),class(a,wednesday,420,480,C),
    build_plan("2026-10-28",480,S,[],[C],P),
    day_timeline("2026-10-28","2026-10-28",480,S,[C],P,Timeline),
    Timeline.events=[First|_],First.kind==class,First.start=:=420.

test(weekly_class_recurrence_across_month_boundary) :-
    settings(S),class(a,sunday,480,540,C),
    build_plan("2026-10-28",480,S,[],[C],P),
    day_timeline("2026-11-01","2026-10-28",480,S,[C],P,T),
    T.events=[First|_],First.kind==class,First.start=:=480.

test(no_future_suggestions_on_past_dates) :-
    settings(S),classes(C),build_plan("2026-10-29",480,S,[],C,P),
    day_timeline("2026-10-28","2026-10-29",480,S,C,P,T),
    forall(member(E,T.events),E.kind==class),T.free_minutes=:=0.

test(does_not_allocate_the_same_work_on_every_calendar_query) :-
    settings(S),task(review,180,"2026-10-30",0,Task),
    build_plan("2026-10-28",480,S,[Task],[],P),
    day_timeline("2026-10-28","2026-10-28",480,S,[],P,A),
    day_timeline("2026-10-29","2026-10-28",480,S,[],P,B),
    A.scheduled_minutes=:=180,B.scheduled_minutes=:=0.

:- end_tests(scheduler).
