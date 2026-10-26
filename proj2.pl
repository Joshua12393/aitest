% Academic
task_type(study,               academic).
task_type(assignment,          academic).
task_type(research,            academic).
task_type(review,              academic).
task_type(exam_preparation,    academic).
task_type(thesis_writing,      academic).
task_type(lab_work,            academic).
task_type(presentation_prep,   academic).
task_type(group_project,       academic).

% Professional
task_type(job_application,     professional).
task_type(interview_prep,      professional).
task_type(resume_building,     professional).
task_type(meeting,             professional).
task_type(report_writing,      professional).
task_type(project_planning,    professional).
task_type(portfolio_building,  professional).

% Skill development
task_type(practice,            skill_development).
task_type(tutorial,            skill_development).
task_type(coding,              skill_development).
task_type(language_learning,   skill_development).

% Health
task_type(exercise,            health).
task_type(workout,             health).
task_type(meditation,          health).
task_type(stretching,          health).
task_type(meal_prep,           health).
task_type(medical_checkup,     health).

% Creative
task_type(writing,             creative).
task_type(drawing,             creative).
task_type(music_composition,   creative).
task_type(video_editing,       creative).
task_type(photography,         creative).

% Social
task_type(volunteering,        social).
task_type(family_time,         social).
task_type(socializing,         social).

% Household
task_type(cleaning,            household).
task_type(grocery_shopping,    household).
task_type(errands,             household).

% Goal category
goal_category(personal).
goal_category(academic).
goal_category(professional).
goal_category(skill_development).
goal_category(health).
goal_category(creative).
goal_category(social).
goal_category(household).

% Priority level
priority_level(urgent).
priority_level(high).
priority_level(medium).
priority_level(low).

% Category priority
category_priority(academic,     high).
category_priority(professional, high).
category_priority(health,       medium).
category_priority(personal,     medium).
category_priority(social,       low).
category_priority(creative,     low).

% Task status value
task_status_value(pending).
task_status_value(in_progress).
task_status_value(completed).
task_status_value(overdue).
task_status_value(archived).

% Goal status value
goal_status_value(active).
goal_status_value(completed).
goal_status_value(paused).
goal_status_value(abandoned).

% Day of week
day_of_week(monday).
day_of_week(tuesday).
day_of_week(wednesday).
day_of_week(thursday).
day_of_week(friday).
day_of_week(saturday).
day_of_week(sunday).

% Time period
time_period(morning).
time_period(afternoon).
time_period(evening).
time_period(night).

% Duration category
duration_category(short,    30).
duration_category(medium,   60).
duration_category(long,    120).
duration_category(extended,240).

% Difficulty level
difficulty_level(easy).
difficulty_level(moderate).
difficulty_level(hard).
difficulty_level(very_hard).

% Session type
session_type(focus_session).
session_type(break).
session_type(review_session).
session_type(planning_session).

% Reminder frequency
reminder_frequency(daily).
reminder_frequency(weekly).
reminder_frequency(before_deadline).
reminder_frequency(custom).

% Notification type
notification_type(reminder).
notification_type(deadline_alert).
notification_type(recommendation).
notification_type(achievement).
notification_type(motivational).
notification_type(weekly_summary).

% Skill category
skill_category(design).
skill_category(programming).
skill_category(writing).
skill_category(marketing).
skill_category(language).
skill_category(fitness).
skill_category(music).
skill_category(photography).


% Progress percentage
progress_percentage(0).
progress_percentage(10).
progress_percentage(20).
progress_percentage(30).
progress_percentage(40).
progress_percentage(50).
progress_percentage(60).
progress_percentage(70).
progress_percentage(80).
progress_percentage(90).
progress_percentage(100).


% ============================================================
% SIMPLE GOAL AND TASK RECOMMENDATION SYSTEM
%
% Load this file in a fresh SWI-Prolog session: [proj2].
% Then try: recommend_task(Task, 60).
% The number 60 means the user has 60 minutes available.
% ============================================================

% SAMPLE GOALS
% goal(GoalName, Category, Status).

goal(pass_subjects,    academic,          active).
goal(find_job,         professional,      active).
goal(improve_coding,   skill_development, active).
goal(stay_healthy,     health,            active).
goal(keep_home_clean,  household,         active).
goal(learn_drawing,    creative,          paused).

% SAMPLE TASKS
% task(Name, Type, MinutesLeft, Priority, DaysLeft, Difficulty, Status, Progress).
%
% MinutesLeft is the estimated REMAINING work, not the original duration.
% DaysLeft: -1 = overdue by one day, 0 = today, 1 = tomorrow.
% Use none for a task without a deadline. Update DaysLeft as days pass.
% Progress uses your existing facts: 0, 10, 20, ..., 100.
% Add or edit these task facts to represent the users own tasks.

task(lab_report,      lab_work,          30, urgent, -1,   moderate, in_progress, 80).
task(review_notes,    review,            25, high,    0,   easy,     in_progress, 60).
task(math_homework,   assignment,        45, high,    1,   hard,     pending,      0).
task(send_resume,     job_application,   15, high,    0,   easy,     pending,      0).
task(practice_code,   coding,            60, medium,  3,   hard,     in_progress, 40).
task(short_walk,      exercise,          15, medium, none,easy,     pending,      0).
task(clean_room,      cleaning,          30, low,    none,easy,     pending,      0).
task(finished_study,  study,              0, high,   -2,   easy,     completed,  100).
task(old_assignment,  assignment,        20, urgent, -3,   easy,     archived,    50).
task(practice_art,    drawing,           20, high,    0,   easy,     pending,      0).
task(prepare_slides,  presentation_prep, 20, high,    2,   moderate, in_progress, 90).

% Connect each task to one goal. Keep task names unique.
% task_goal(TaskName, GoalName).

task_goal(lab_report,     pass_subjects).
task_goal(review_notes,   pass_subjects).
task_goal(math_homework,  pass_subjects).
task_goal(send_resume,    find_job).
task_goal(practice_code,  improve_coding).
task_goal(short_walk,     stay_healthy).
task_goal(clean_room,     keep_home_clean).
task_goal(finished_study, pass_subjects).
task_goal(old_assignment,pass_subjects).
task_goal(practice_art,   learn_drawing).
task_goal(prepare_slides, pass_subjects).

% Points for the users chosen priority.
priority_points(urgent, 40).
priority_points(high,   30).
priority_points(medium, 20).
priority_points(low,    10).


% ============================================================
% RULES
% :- means "if". A comma means "and". \+ means "cannot prove".
% An underscore (_) means a field is not needed in that rule.
% ============================================================

% 1. A deadline is either none or a whole number of days left.
valid_deadline(none).
valid_deadline(DaysLeft) :-
    integer(DaysLeft).

% 2. Status, progress, and remaining minutes must agree.
valid_progress(completed, 100, 0).
valid_progress(pending, 0, Minutes) :-
    Minutes > 0.
valid_progress(in_progress, Progress, Minutes) :-
    Progress > 0, Progress < 100, Minutes > 0.
valid_progress(overdue, Progress, Minutes) :-
    Progress < 100, Minutes > 0.
valid_progress(archived, Progress, Minutes) :-
    (Progress =:= 100 -> Minutes =:= 0 ; Minutes > 0).

% 3. Check a task against your allowed values and its goals category.
valid_task(Task) :-
    task(Task, Type, Minutes, Priority, DaysLeft, Difficulty, Status, Progress),
    task_type(Type, Category),
    task_goal(Task, Goal),
    goal(Goal, Category, GoalStatus),
    goal_category(Category),
    goal_status_value(GoalStatus),
    integer(Minutes), Minutes >= 0,
    priority_level(Priority),
    valid_deadline(DaysLeft),
    difficulty_level(Difficulty),
    task_status_value(Status),
    progress_percentage(Progress),
    valid_progress(Status, Progress, Minutes),
    (Status == overdue -> integer(DaysLeft), DaysLeft < 0 ; true).

% 4. Find the tasks category using its type.
task_category(Task, Category) :-
    task(Task, Type, _, _, _, _, _, _),
    task_type(Type, Category).

% 5. Completed and archived tasks are not unfinished work.
unfinished_task(Task) :-
    task(Task, _, _, _, _, _, Status, Progress),
    member(Status, [pending, in_progress, overdue]),
    Progress < 100.

% 6. The task must belong to an active goal.
active_goal_task(Task) :-
    task_goal(Task, Goal),
    goal(Goal, _, active).

% 7. Remaining work must fit the users available minutes.
fits_time(Task, AvailableMinutes) :-
    integer(AvailableMinutes), AvailableMinutes >= 0,
    task(Task, _, Minutes, _, _, _, _, _),
    Minutes > 0, Minutes =< AvailableMinutes.

% 8. Negative days left means unfinished work is overdue.
overdue_task(Task) :-
    unfinished_task(Task),
    task(Task, _, _, _, DaysLeft, _, _, _),
    integer(DaysLeft), DaysLeft < 0.

% 9. A near deadline is today or within the next two days.
due_soon_task(Task) :-
    unfinished_task(Task),
    task(Task, _, _, _, DaysLeft, _, _, _),
    integer(DaysLeft), DaysLeft >= 0, DaysLeft =< 2.

% 10. High and urgent priorities deserve attention.
high_priority_task(Task) :-
    task(Task, _, _, Priority, _, _, _, _),
    member(Priority, [high, urgent]).

% 11. Identify easy work for the explanation.
easy_task(Task) :-
    task(Task, _, _, _, _, easy, _, _).

% 12. Use your short-duration fact as the upper limit.
short_task(Task) :-
    duration_category(short, Limit),
    task(Task, _, Minutes, _, _, _, _, _),
    Minutes > 0, Minutes =< Limit.

% 13. An unfinished task at 80% or 90% is almost done.
almost_done(Task) :-
    unfinished_task(Task),
    task(Task, _, _, _, _, _, _, Progress),
    Progress >= 80.

% 14. Combine the basic checks before considering a recommendation.
eligible_task(Task, AvailableMinutes) :-
    valid_task(Task),
    unfinished_task(Task),
    active_goal_task(Task),
    fits_time(Task, AvailableMinutes).

% 15. Deadline points: overdue = 200, near = 100, otherwise = 0.
% The if-then-else chooses exactly one case for each task.
deadline_score(Task, Points) :-
    task(Task, _, _, _, DaysLeft, _, _, _),
    valid_deadline(DaysLeft),
    ( DaysLeft == none -> Points = 0
    ; DaysLeft < 0     -> Points = 200
    ; DaysLeft =< 2    -> Points = 100
    ; Points = 0
    ).

% 16. Combine urgency, priority, and progress into one score.
% Example: lab_report = 200 + 40 + 8 = 248.
% Progress is a small bonus; it does not reduce MinutesLeft again.
task_score(Task, Score) :-
    valid_task(Task),
    task(Task, _, _, Priority, _, _, _, Progress),
    priority_points(Priority, PriorityPoints),
    deadline_score(Task, DeadlinePoints),
    Score is DeadlinePoints + PriorityPoints + Progress // 10.

% 17. Recommend a task when no other eligible task has a higher score.
% Equal top scores return multiple choices when you press ; at the prompt.
% If nothing fits, the query returns false.
recommend_task(Task, AvailableMinutes) :-
    eligible_task(Task, AvailableMinutes),
    task_score(Task, Score),
    \+ (eligible_task(Other, AvailableMinutes),
        task_score(Other, OtherScore),
        OtherScore > Score).

% 18. Explain the recommended tasks characteristics.
% Difficulty is descriptive here; it does not override urgency or priority.
recommendation_reason(Task, overdue) :- overdue_task(Task).
recommendation_reason(Task, near_deadline) :- due_soon_task(Task).
recommendation_reason(Task, high_priority) :- high_priority_task(Task).
recommendation_reason(Task, almost_finished) :- almost_done(Task).
recommendation_reason(Task, easy_work) :- easy_task(Task).
recommendation_reason(Task, short_duration) :- short_task(Task).

% 19. Collect all reasons for the recommendation into a list.
recommendation(Task, AvailableMinutes, Reasons) :-
    recommend_task(Task, AvailableMinutes),
    findall(Reason, recommendation_reason(Task, Reason), Reasons).

% 20. Recursion: add the remaining minutes of a supplied list of tasks.
% The empty list needs 0 minutes. Each step handles one task, then the rest.
% This totals duration only; it does not automatically select a session plan.
total_duration([], 0).
total_duration([Task|Rest], TotalMinutes) :-
    valid_task(Task),
    task(Task, _, Minutes, _, _, _, _, _),
    total_duration(Rest, RestMinutes),
    TotalMinutes is Minutes + RestMinutes.


% ============================================================
% TEST QUERIES AND EXPECTED ANSWERS
% Type these at the Prolog prompt after loading proj2.pl.
% ============================================================
%
% 1.  recommend_task(Task, 60).
%     Task = lab_report.
%
% 2.  recommend_task(Task, 25).
%     Task = prepare_slides. It is almost finished and due soon.
%
% 3.  recommend_task(Task, 15).
%     Task = send_resume.
%
% 4.  recommend_task(_, 5).
%     false. No unfinished task fits five minutes.
%
% 5.  eligible_task(lab_report, 30).
%     true. An exact time match is allowed.
%
% 6.  eligible_task(lab_report, 29).
%     false. It needs 30 minutes.
%
% 7.  eligible_task(finished_study, 60).
%     false. It is already completed.
%
% 8.  eligible_task(old_assignment, 60).
%     false. Archived tasks are excluded even when overdue.
%
% 9.  eligible_task(practice_art, 60).
%     false. Its goal is paused.
%
% 10. due_soon_task(prepare_slides).
%     true. Two days is inside the near-deadline range.
%
% 11. due_soon_task(short_walk).
%     false. It has no deadline.
%
% 12. task_score(lab_report, Score).
%     Score = 248.
%
% 13. recommendation(Task, 60, Reasons).
%     Task = lab_report,
%     Reasons = [overdue,high_priority,almost_finished,short_duration].
%
% 14. total_duration([lab_report, review_notes, send_resume], Minutes).
%     Minutes = 70.
%
% 15. total_duration([], Minutes).
%     Minutes = 0. This is the recursions stopping case.
%
% 16. forall(task(Task,_,_,_,_,_,_,_), valid_task(Task)).
%     true. All sample tasks use valid values and matching goal categories.
%
% To use your own data, edit/add goal, task, and task_goal facts above,
% then reload this file. Change the minutes in your query for each session.
