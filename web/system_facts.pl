:- module(system_facts, [system_task/1, task_category/2, typical_minutes/2,
                         task_difficulty/2, task_priority/2, task_energy/2]).
% 20 task types x 6 explicit, meaningful facts = 120 SYSTEM facts.
% User records are kept separately in planner.pl and data/state.json.
:- discontiguous system_task/1, task_category/2, typical_minutes/2,
                 task_difficulty/2, task_priority/2, task_energy/2.

system_task(exam_review).
task_category(exam_review, academic).
typical_minutes(exam_review, 60).
task_difficulty(exam_review, hard).
task_priority(exam_review, high).
task_energy(exam_review, high).

system_task(review_notes).
task_category(review_notes, academic).
typical_minutes(review_notes, 30).
task_difficulty(review_notes, easy).
task_priority(review_notes, medium).
task_energy(review_notes, low).

system_task(assignment).
task_category(assignment, academic).
typical_minutes(assignment, 60).
task_difficulty(assignment, medium).
task_priority(assignment, high).
task_energy(assignment, medium).

system_task(research).
task_category(research, academic).
typical_minutes(research, 90).
task_difficulty(research, hard).
task_priority(research, high).
task_energy(research, high).

system_task(reading).
task_category(reading, academic).
typical_minutes(reading, 30).
task_difficulty(reading, medium).
task_priority(reading, medium).
task_energy(reading, medium).

system_task(presentation).
task_category(presentation, academic).
typical_minutes(presentation, 60).
task_difficulty(presentation, hard).
task_priority(presentation, high).
task_energy(presentation, high).

system_task(programming).
task_category(programming, skill_development).
typical_minutes(programming, 90).
task_difficulty(programming, hard).
task_priority(programming, high).
task_energy(programming, high).

system_task(debugging).
task_category(debugging, skill_development).
typical_minutes(debugging, 45).
task_difficulty(debugging, hard).
task_priority(debugging, high).
task_energy(debugging, high).

system_task(group_work).
task_category(group_work, academic).
typical_minutes(group_work, 60).
task_difficulty(group_work, medium).
task_priority(group_work, high).
task_energy(group_work, medium).

system_task(work).
task_category(work, professional).
typical_minutes(work, 120).
task_difficulty(work, medium).
task_priority(work, high).
task_energy(work, medium).

system_task(meeting).
task_category(meeting, professional).
typical_minutes(meeting, 30).
task_difficulty(meeting, easy).
task_priority(meeting, medium).
task_energy(meeting, medium).

system_task(email).
task_category(email, professional).
typical_minutes(email, 15).
task_difficulty(email, easy).
task_priority(email, low).
task_energy(email, low).

system_task(exercise).
task_category(exercise, health).
typical_minutes(exercise, 30).
task_difficulty(exercise, medium).
task_priority(exercise, medium).
task_energy(exercise, high).

system_task(cleaning).
task_category(cleaning, household).
typical_minutes(cleaning, 45).
task_difficulty(cleaning, easy).
task_priority(cleaning, low).
task_energy(cleaning, medium).

system_task(planning).
task_category(planning, personal).
typical_minutes(planning, 20).
task_difficulty(planning, easy).
task_priority(planning, medium).
task_energy(planning, low).

system_task(preparation).
task_category(preparation, personal).
typical_minutes(preparation, 30).
task_difficulty(preparation, easy).
task_priority(preparation, medium).
task_energy(preparation, low).

system_task(lab_work).
task_category(lab_work, academic).
typical_minutes(lab_work, 90).
task_difficulty(lab_work, hard).
task_priority(lab_work, high).
task_energy(lab_work, high).

system_task(writing).
task_category(writing, creative).
typical_minutes(writing, 45).
task_difficulty(writing, medium).
task_priority(writing, medium).
task_energy(writing, medium).

system_task(practice).
task_category(practice, skill_development).
typical_minutes(practice, 30).
task_difficulty(practice, medium).
task_priority(practice, medium).
task_energy(practice, medium).

system_task(errands).
task_category(errands, household).
typical_minutes(errands, 45).
task_difficulty(errands, easy).
task_priority(errands, low).
task_energy(errands, low).
