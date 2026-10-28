:- module(scheduler, [build_plan/6, build_plan/7, day_timeline/7]).
:- use_module(library(date)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).

% Pure scheduling: input dicts are already validated by planner.pl. No user
% facts are changed by viewing or recomputing a plan. All times are minutes
% after midnight on the planner's Asia/Manila calendar date.
iso_number(ISO, Number) :-
    split_string(ISO,"-","",[YS,MS,DS]), maplist(number_string,[Y,M,D],[YS,MS,DS]),
    date_time_stamp(date(Y,M,D,0,0,0,0,-,-), Stamp), Number is floor(Stamp/86400).
number_iso(Number, ISO) :-
    Stamp is Number*86400, stamp_date_time(Stamp,Date,'UTC'),
    format_time(string(ISO),'%Y-%m-%d',Date).
weekday(Number, Day) :-
    Stamp is Number*86400, stamp_date_time(Stamp,date(Y,M,D,_,_,_,_,_,_),'UTC'),
    day_of_the_week(date(Y,M,D),Index),
    nth1(Index,[monday,tuesday,wednesday,thursday,friday,saturday,sunday],Day).

class_on(Day, Class) :- get_dict(day,Class,Day).
class_interval(Class, Start-End) :- Start=Class.start, End=Class.end.

% Sorted overlapping or touching classes advance the cursor together. A gap
% is emitted only when no class occupies it, including nested overlaps.
free_intervals(Start, End, _, []) :- Start >= End, !.
free_intervals(Start, End, [], [Start-End]).
free_intervals(Start, End, [BusyStart-BusyEnd|Rest], Gaps) :-
    (BusyEnd =< Start -> free_intervals(Start,End,Rest,Gaps)
    ; BusyStart >= End -> Gaps=[Start-End]
    ; Next is max(Start,BusyEnd),
      (BusyStart > Start -> GapEnd is min(BusyStart,End), Gaps=[Start-GapEnd|Tail]
      ; Gaps=Tail),
      free_intervals(Next,End,Rest,Tail)).

day_free(Day, Today, Now, Settings, Classes, Gaps) :-
    weekday(Day,Name), include(class_on(Name),Classes,DayClasses),
    maplist(class_interval,DayClasses,Raw), sort(Raw,Busy),
    (Day < Today -> Start=Settings.day_end
    ; Day =:= Today -> Start is max(Settings.day_start,Now)
    ; Start=Settings.day_start),
    free_intervals(Start,Settings.day_end,Busy,Gaps).

pending(Task) :- Task.status == pending.
deadline_pair(Task, key(Task.due_date,Task.deadline_time)-Task).
build_plan(TodayISO, Now, Settings, Tasks, Classes, Plan) :-
    build_plan(TodayISO,Now,Settings,Tasks,Classes,[],Plan).

build_plan(TodayISO, Now, Settings, Tasks, Classes, Fixed, Plan) :-
    iso_number(TodayISO,Today), Last is Today+89,
    findall(slot(Day,Start,End),
            (between(Today,Last,Day),day_free(Day,Today,Now,Settings,Classes,Gaps),
             member(Start-End,Gaps)), Slots),
    % Tasks arrive in the planner's deadline/priority/difficulty order.
    include(pending,Tasks,Pending),maplist(deadline_pair,Pending,Pairs),keysort(Pairs,Sorted),
    pairs_values(Sorted,Ordered),
    findall(Event,(member(F,Fixed),member(T,Pending),T.id == F.task_id,
                  Length is F.end-F.start,
                  Event=_{kind:task,date:F.date,start:F.start,end:F.end,minutes:Length,
                    manual_id:F.id,task_id:T.id,title:T.title,subject:T.subject,
                    due_date:T.due_date,deadline_time:T.deadline_time,reason:'Time chosen by you.'}),Pinned),
    maplist(remaining_task(Pinned),Ordered,Remaining),
    reserve_slots(Slots,Pinned,FreeSlots),allocate_tasks(Remaining,FreeSlots,Auto,RawSummaries),
    maplist(full_summary(Pinned),RawSummaries,Summaries),append(Pinned,Auto,Sessions),
    number_iso(Last,EndISO),
    Plan=_{start_date:TodayISO,end_date:EndISO,sessions:Sessions,tasks:Summaries}, !.

reserved_minutes(Pinned,Id,Total) :-
    findall(N,(member(E,Pinned),E.task_id == Id,N=E.minutes),Lengths),sum_list(Lengths,Total).
remaining_task(Pinned,Task,Remaining) :-
    reserved_minutes(Pinned,Task.id,Total),N is Task.minutes-Total,Remaining=Task.put(minutes,N).
full_summary(Pinned,Raw,Summary) :-
    reserved_minutes(Pinned,Raw.task_id,Total),Required is Raw.required_minutes+Total,
    Scheduled is Raw.scheduled_minutes+Total,
    Summary=Raw.put(_{required_minutes:Required,scheduled_minutes:Scheduled}).
reserve_slots([],_,[]).
reserve_slots([slot(Day,Start,End)|Rest],Pinned,Free) :-
    number_iso(Day,ISO),findall(A-B,(member(E,Pinned),E.date == ISO,A=E.start,B=E.end),Raw),
    sort(Raw,Busy),free_intervals(Start,End,Busy,Gaps),
    findall(slot(Day,A,B),member(A-B,Gaps),Own),reserve_slots(Rest,Pinned,Others),append(Own,Others,Free).

allocate_tasks([], _, [], []).
allocate_tasks([Task|Rest], Slots, Sessions, [Summary|Summaries]) :-
    iso_number(Task.due_date,DueDay), Deadline is DueDay*1440+Task.deadline_time,
    place_task(Slots,Deadline,Task.minutes,Task,Own,RemainingSlots,Missing),
    Scheduled is Task.minutes-Missing,
    Summary=_{task_id:Task.id,title:Task.title,required_minutes:Task.minutes,
              scheduled_minutes:Scheduled,unscheduled_minutes:Missing,
              due_date:Task.due_date,deadline_time:Task.deadline_time},
    allocate_tasks(Rest,RemainingSlots,Other,Summaries), append(Own,Other,Sessions).

place_task(Slots, _, 0, _, [], Slots, 0) :- !.
place_task([], _, Left, _, [], [], Left) :- !.
place_task([slot(Day,Start,End)|Rest], Deadline, Left, Task, Sessions, After, Missing) :-
    AbsoluteStart is Day*1440+Start,
    (AbsoluteStart >= Deadline
    -> Sessions=[],After=[slot(Day,Start,End)|Rest],Missing=Left
    ; Limit is min(End,Deadline-Day*1440), Take is min(Left,Limit-Start),
      Finish is Start+Take, Remaining is Left-Take,
      (Finish < End -> Next=[slot(Day,Finish,End)|Rest] ; Next=Rest),
      number_iso(Day,ISO),
      Event=_{kind:task,date:ISO,start:Start,end:Finish,minutes:Take,
               task_id:Task.id,title:Task.title,subject:Task.subject,
               due_date:Task.due_date,deadline_time:Task.deadline_time,
               reason:'Suggested in vacant time before your deadline.'},
      Sessions=[Event|Tail], place_task(Next,Deadline,Remaining,Task,Tail,After,Missing)).

event_on(ISO, Event) :- Event.date == ISO.
event_pair(Event, key(Event.start,Event.end)-Event).
free_event(ISO, Start-End, _{kind:free,date:ISO,start:Start,end:End,minutes:Minutes,
                           title:'Vacant time'}) :- Minutes is End-Start.
event_minutes(Event, Minutes) :- Minutes is Event.end-Event.start.

day_timeline(ISO, TodayISO, Now, Settings, Classes, Plan, Timeline) :-
    iso_number(ISO,Day),iso_number(TodayISO,Today),weekday(Day,Name),
    findall(Event,
            (member(Class,Classes),Class.day == Name,
             Event=_{kind:class,date:ISO,start:Class.start,end:Class.end,
                     title:Class.subject,id:Class.id}),ClassEvents),
    include(event_on(ISO),Plan.sessions,Sessions),
    append(ClassEvents,Sessions,Occupied),maplist(class_interval,Occupied,Intervals),
    sort(Intervals,Busy),
    (Day < Today -> Start=Settings.day_end
    ; Day =:= Today -> Start is max(Settings.day_start,Now)
    ; Start=Settings.day_start),
    free_intervals(Start,Settings.day_end,Busy,Gaps),maplist(free_event(ISO),Gaps,Free),
    append(Occupied,Free,Events),maplist(event_pair,Events,Pairs),keysort(Pairs,Sorted),
    pairs_values(Sorted,Ordered),maplist(event_minutes,Free,FreeMinutes),sum_list(FreeMinutes,Vacant),
    maplist(event_minutes,Sessions,TaskMinutes),sum_list(TaskMinutes,Scheduled),
    (ISO @>= Plan.start_date,ISO @=< Plan.end_date -> InRange=true ; InRange=false),
    Timeline=_{date:ISO,events:Ordered,free_minutes:Vacant,scheduled_minutes:Scheduled,
               within_horizon:InRange}, !.
