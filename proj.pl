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