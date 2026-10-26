:- module(task_facts, [
    goal_category/1, goal_status_value/1, task_status_value/1,
    priority_level/2, difficulty_level/2, energy_level/2, task_type/2,
    demo_date/1, goal/4, task/4, remaining_minutes/2, difficulty/2,
    priority/2, deadline/2, task_status/2, progress/2, depends_on/2
]).

/** <module> Task Planner knowledge base

All sample records are fictional. Dates are ISO calendar dates, represented as
date(Year, Month, Day), or the atom none when a task has no deadline.

The eight task predicates describe one task together:
  task(Id, GoalId, Title, Type), remaining_minutes(Id, Minutes),
  difficulty(Id, Level), priority(Id, Level), deadline(Id, DateOrNone),
  task_status(Id, Status), progress(Id, Percent), depends_on(Id, Prerequisite).

Remaining minutes is a CURRENT estimate, not the original total duration.
Progress never scales that estimate a second time. Overdue is derived from a
reference date; storing it as a status would become stale as the date changes.
The dynamic declarations allow validated updates through rules.pl.
*/

:- dynamic goal/4, task/4, remaining_minutes/2, difficulty/2, priority/2.
:- dynamic deadline/2, task_status/2, progress/2, depends_on/2.
% Group attributes by task for readability rather than by predicate.
:- discontiguous task/4, remaining_minutes/2, difficulty/2, priority/2.
:- discontiguous deadline/2, task_status/2, progress/2.

demo_date(date(2026, 10, 26)).

goal_category(academic).
goal_category(professional).
goal_category(skill_development).
goal_category(health).
goal_category(household).
goal_category(creative).
goal_category(social).
goal_category(personal).

goal_status_value(active).
goal_status_value(paused).
goal_status_value(completed).
goal_status_value(abandoned).

task_status_value(pending).
task_status_value(in_progress).
task_status_value(completed).
task_status_value(archived).

% Lower numeric ranks are preferred. These are policy facts, not hidden weights.
priority_level(urgent, 0).
priority_level(high, 1).
priority_level(medium, 2).
priority_level(low, 3).

difficulty_level(easy, 1).
difficulty_level(moderate, 2).
difficulty_level(hard, 3).
difficulty_level(very_hard, 4).

energy_level(low, 1).
energy_level(medium, 2).
energy_level(high, 4).

task_type(study, academic).
task_type(assignment, academic).
task_type(research, academic).
task_type(review, academic).
task_type(exam_preparation, academic).
task_type(thesis_writing, academic).
task_type(lab_work, academic).
task_type(presentation_prep, academic).
task_type(group_project, academic).
task_type(job_application, professional).
task_type(interview_prep, professional).
task_type(resume_building, professional).
task_type(meeting, professional).
task_type(report_writing, professional).
task_type(project_planning, professional).
task_type(portfolio_building, professional).
task_type(practice, skill_development).
task_type(tutorial, skill_development).
task_type(coding, skill_development).
task_type(language_learning, skill_development).
task_type(exercise, health).
task_type(workout, health).
task_type(meditation, health).
task_type(stretching, health).
task_type(meal_prep, health).
task_type(medical_checkup, health).
task_type(writing, creative).
task_type(drawing, creative).
task_type(music_composition, creative).
task_type(video_editing, creative).
task_type(photography, creative).
task_type(volunteering, social).
task_type(family_time, social).
task_type(socializing, social).
task_type(cleaning, household).
task_type(grocery_shopping, household).
task_type(errands, household).
task_type(reading, personal).
task_type(organization, personal).

goal(g_course, 'Complete course requirements', academic, active).
goal(g_paper, 'Submit a research paper', academic, active).
goal(g_career, 'Prepare for a first job', professional, active).
goal(g_code, 'Improve programming skills', skill_development, active).
goal(g_health, 'Build a healthy routine', health, active).
goal(g_home, 'Keep the home organized', household, active).
goal(g_art, 'Develop a creative portfolio', creative, active).
goal(g_family, 'Stay connected with family and community', social, active).
goal(g_read, 'Read a personal development book', personal, paused).
goal(g_done, 'Finish the introductory course', academic, completed).
goal(g_old, 'Organize an old collection', personal, abandoned).

% Academic work: overdue, due today, urgent, completed, and dependency chains.
task(submit_report, g_course, 'Finish and submit the lab report', lab_work).
remaining_minutes(submit_report, 30).
difficulty(submit_report, moderate).
priority(submit_report, urgent).
deadline(submit_report, date(2026, 10, 25)).
task_status(submit_report, in_progress).
progress(submit_report, 80).

task(revise_notes, g_course, 'Revise lecture notes', review).
remaining_minutes(revise_notes, 25).
difficulty(revise_notes, easy).
priority(revise_notes, high).
deadline(revise_notes, date(2026, 10, 26)).
task_status(revise_notes, in_progress).
progress(revise_notes, 60).

task(solve_exercises, g_course, 'Solve practice exercises', assignment).
remaining_minutes(solve_exercises, 45).
difficulty(solve_exercises, moderate).
priority(solve_exercises, high).
deadline(solve_exercises, date(2026, 10, 27)).
task_status(solve_exercises, pending).
progress(solve_exercises, 0).

task(exam_review, g_course, 'Complete a mock examination', exam_preparation).
remaining_minutes(exam_review, 90).
difficulty(exam_review, very_hard).
priority(exam_review, urgent).
deadline(exam_review, date(2026, 10, 27)).
task_status(exam_review, pending).
progress(exam_review, 0).

task(read_article, g_paper, 'Read a background article', research).
remaining_minutes(read_article, 20).
difficulty(read_article, easy).
priority(read_article, medium).
deadline(read_article, date(2026, 10, 28)).
task_status(read_article, pending).
progress(read_article, 0).

task(research_sources, g_paper, 'Collect reliable research sources', research).
remaining_minutes(research_sources, 0).
difficulty(research_sources, moderate).
priority(research_sources, high).
deadline(research_sources, date(2026, 10, 24)).
task_status(research_sources, completed).
progress(research_sources, 100).

task(outline_paper, g_paper, 'Write the research paper outline', thesis_writing).
remaining_minutes(outline_paper, 35).
difficulty(outline_paper, moderate).
priority(outline_paper, high).
deadline(outline_paper, date(2026, 10, 27)).
task_status(outline_paper, pending).
progress(outline_paper, 0).

task(write_paper, g_paper, 'Write the research paper draft', thesis_writing).
remaining_minutes(write_paper, 90).
difficulty(write_paper, hard).
priority(write_paper, high).
deadline(write_paper, date(2026, 10, 28)).
task_status(write_paper, pending).
progress(write_paper, 0).

task(proofread_paper, g_paper, 'Proofread the research paper', review).
remaining_minutes(proofread_paper, 20).
difficulty(proofread_paper, easy).
priority(proofread_paper, high).
deadline(proofread_paper, date(2026, 10, 29)).
task_status(proofread_paper, pending).
progress(proofread_paper, 0).

% Professional work includes a completed prerequisite.
task(send_application, g_career, 'Send a job application', job_application).
remaining_minutes(send_application, 15).
difficulty(send_application, easy).
priority(send_application, high).
deadline(send_application, date(2026, 10, 26)).
task_status(send_application, pending).
progress(send_application, 0).

task(resume_edit, g_career, 'Update the resume', resume_building).
remaining_minutes(resume_edit, 0).
difficulty(resume_edit, moderate).
priority(resume_edit, high).
deadline(resume_edit, date(2026, 10, 25)).
task_status(resume_edit, completed).
progress(resume_edit, 100).

task(practice_interview, g_career, 'Practice interview answers', interview_prep).
remaining_minutes(practice_interview, 40).
difficulty(practice_interview, moderate).
priority(practice_interview, medium).
deadline(practice_interview, date(2026, 10, 30)).
task_status(practice_interview, pending).
progress(practice_interview, 0).

task(coding_practice, g_code, 'Practice recursive predicates', practice).
remaining_minutes(coding_practice, 30).
difficulty(coding_practice, moderate).
priority(coding_practice, medium).
deadline(coding_practice, none).
task_status(coding_practice, in_progress).
progress(coding_practice, 40).

task(watch_tutorial, g_code, 'Watch a debugging tutorial', tutorial).
remaining_minutes(watch_tutorial, 20).
difficulty(watch_tutorial, easy).
priority(watch_tutorial, low).
deadline(watch_tutorial, none).
task_status(watch_tutorial, pending).
progress(watch_tutorial, 0).

task(build_feature, g_code, 'Build a small practice feature', coding).
remaining_minutes(build_feature, 60).
difficulty(build_feature, hard).
priority(build_feature, high).
deadline(build_feature, date(2026, 10, 29)).
task_status(build_feature, pending).
progress(build_feature, 0).

task(walk, g_health, 'Take a short walk', exercise).
remaining_minutes(walk, 15).
difficulty(walk, easy).
priority(walk, medium).
deadline(walk, none).
task_status(walk, pending).
progress(walk, 0).

task(stretch, g_health, 'Complete a stretching routine', stretching).
remaining_minutes(stretch, 10).
difficulty(stretch, easy).
priority(stretch, low).
deadline(stretch, none).
task_status(stretch, pending).
progress(stretch, 0).

task(workout, g_health, 'Complete the planned workout', workout).
remaining_minutes(workout, 45).
difficulty(workout, hard).
priority(workout, high).
deadline(workout, date(2026, 10, 27)).
task_status(workout, pending).
progress(workout, 0).

task(meal_prep, g_health, 'Prepare meals for tomorrow', meal_prep).
remaining_minutes(meal_prep, 40).
difficulty(meal_prep, moderate).
priority(meal_prep, medium).
deadline(meal_prep, date(2026, 10, 28)).
task_status(meal_prep, pending).
progress(meal_prep, 0).

task(clean_desk, g_home, 'Clean the study desk', cleaning).
remaining_minutes(clean_desk, 15).
difficulty(clean_desk, easy).
priority(clean_desk, low).
deadline(clean_desk, none).
task_status(clean_desk, pending).
progress(clean_desk, 0).

task(groceries, g_home, 'Buy household groceries', grocery_shopping).
remaining_minutes(groceries, 30).
difficulty(groceries, easy).
priority(groceries, medium).
deadline(groceries, date(2026, 10, 27)).
task_status(groceries, pending).
progress(groceries, 0).

task(laundry, g_home, 'Wash and fold the laundry', cleaning).
remaining_minutes(laundry, 50).
difficulty(laundry, easy).
priority(laundry, low).
deadline(laundry, date(2026, 10, 29)).
task_status(laundry, pending).
progress(laundry, 0).

task(sketch, g_art, 'Draw a portfolio sketch', drawing).
remaining_minutes(sketch, 25).
difficulty(sketch, easy).
priority(sketch, low).
deadline(sketch, none).
task_status(sketch, pending).
progress(sketch, 0).

task(edit_video, g_art, 'Edit a portfolio video', video_editing).
remaining_minutes(edit_video, 75).
difficulty(edit_video, hard).
priority(edit_video, medium).
deadline(edit_video, date(2026, 10, 30)).
task_status(edit_video, pending).
progress(edit_video, 0).

task(call_family, g_family, 'Call the family', family_time).
remaining_minutes(call_family, 20).
difficulty(call_family, easy).
priority(call_family, high).
deadline(call_family, date(2026, 10, 26)).
task_status(call_family, pending).
progress(call_family, 0).

task(volunteer, g_family, 'Help at a community event', volunteering).
remaining_minutes(volunteer, 60).
difficulty(volunteer, moderate).
priority(volunteer, medium).
deadline(volunteer, date(2026, 11, 1)).
task_status(volunteer, pending).
progress(volunteer, 0).

% Inactive and archived records ensure urgency never bypasses eligibility.
task(paused_reading, g_read, 'Read the next book chapter', reading).
remaining_minutes(paused_reading, 10).
difficulty(paused_reading, easy).
priority(paused_reading, urgent).
deadline(paused_reading, date(2026, 10, 25)).
task_status(paused_reading, pending).
progress(paused_reading, 0).

task(finished_course, g_done, 'Complete the introductory assessment', assignment).
remaining_minutes(finished_course, 0).
difficulty(finished_course, moderate).
priority(finished_course, high).
deadline(finished_course, date(2026, 10, 20)).
task_status(finished_course, completed).
progress(finished_course, 100).

task(archived_task, g_course, 'Revise a superseded assignment', assignment).
remaining_minutes(archived_task, 20).
difficulty(archived_task, easy).
priority(archived_task, urgent).
deadline(archived_task, date(2026, 10, 24)).
task_status(archived_task, archived).
progress(archived_task, 50).

task(abandoned_plan, g_old, 'Sort the old collection', organization).
remaining_minutes(abandoned_plan, 30).
difficulty(abandoned_plan, easy).
priority(abandoned_plan, urgent).
deadline(abandoned_plan, date(2026, 10, 24)).
task_status(abandoned_plan, pending).
progress(abandoned_plan, 0).

% These real activities share ranking fields, exercising stable ID tie-breaking.
task(organize_drawer, g_home, 'Organize the desk drawer', cleaning).
remaining_minutes(organize_drawer, 30).
difficulty(organize_drawer, easy).
priority(organize_drawer, medium).
deadline(organize_drawer, date(2026, 10, 31)).
task_status(organize_drawer, pending).
progress(organize_drawer, 0).

task(sort_shelf, g_home, 'Sort the bookshelf', cleaning).
remaining_minutes(sort_shelf, 30).
difficulty(sort_shelf, easy).
priority(sort_shelf, medium).
deadline(sort_shelf, date(2026, 10, 31)).
task_status(sort_shelf, pending).
progress(sort_shelf, 0).

task(water_plants, g_home, 'Water the indoor plants', errands).
remaining_minutes(water_plants, 5).
difficulty(water_plants, easy).
priority(water_plants, low).
deadline(water_plants, none).
task_status(water_plants, pending).
progress(water_plants, 0).

depends_on(outline_paper, research_sources).
depends_on(write_paper, outline_paper).
depends_on(proofread_paper, write_paper).
depends_on(send_application, resume_edit).
depends_on(build_feature, coding_practice).
