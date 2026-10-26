:- use_module('proj.pl').
:- use_module(library(plunit)).
:- use_module(library(time)).
:- use_module(library(http/json)).

/** <module> Reproducible behavioral and integrity tests

Run: swipl -q -s tests.pl -g run_tests -t halt
All calendar-sensitive queries use 2026-10-26. Mutating tests use setup_call_cleanup/3 to restore the exact initial facts,
including when a test throws or fails. Tests intentionally run sequentially.
File tests use unique OS temporary paths and clean up after themselves.
*/

:- begin_tests(task_planner).

:- meta_predicate with_test_state(0).

% Capture and restore ground records explicitly, avoiding nested transactions
% inside SWI snapshot/1. Product mutations still use their real transactions.
with_test_state(Goal) :-
    setup_call_cleanup(task_planner:state_dict(Before), Goal,
                       (task_planner:clear_state, task_planner:restore_state(Before))).

reference(date(2026, 10, 26)).

precedes(A, B, List) :-
    once((append(_, [A|Tail], List), memberchk(B, Tail))).

% A small isolated scenario makes recursive planning expectations independently
% checkable: 20 + 30 + 10 minutes, with middle -> first and last -> middle.
isolated_chain :-
    task_planner:clear_state,
    add_goal(g_test, 'Finish a three step exercise', academic),
    add_task(first, g_test, 'Read the problem', study, 20, easy, high, none),
    add_task(middle, g_test, 'Solve the problem', assignment, 30, easy, high, none),
    add_task(last, g_test, 'Review the answer', review, 10, easy, high, none),
    add_dependency(middle, first), add_dependency(last, middle).

delete_if_present(File) :- (exists_file(File) -> delete_file(File) ; true).

write_json(File, Dict) :-
    setup_call_cleanup(open(File, write, Out, [encoding(utf8)]),
                       json_write_dict(Out, Dict), close(Out)).

test(sample_integrity, true(Errors == [])) :- validate_kb(Errors).

test(meaningful_fact_base) :-
    knowledge_stats(S), assertion(S.facts == 314), assertion(S.facts > 100),
    assertion(S.goals == 11), assertion(S.tasks == 33), assertion(S.dependencies == 5).

test(valid_leap_day) :- valid_date(date(2024, 2, 29)).
test(invalid_nonleap_day, [fail]) :- valid_date(date(2026, 2, 29)).
test(invalid_normalized_date, [fail]) :- valid_date(date(2026, 2, 30)).
test(invalid_month, [fail]) :- valid_date(date(2026, 13, 1)).
test(invalid_day_zero, [fail]) :- valid_date(date(2026, 10, 0)).
test(calendar_year_boundary, true(Days == 1)) :-
    days_between(date(2026, 12, 31), date(2027, 1, 1), Days).
test(calendar_leap_boundary, true(Days == 2)) :-
    days_between(date(2024, 2, 28), date(2024, 3, 1), Days).

test(overdue_task) :- reference(D), overdue(submit_report, D).
test(completed_task_not_overdue, [fail]) :- reference(D), overdue(research_sources, D).
test(deadline_today, true(Band-Days == due_today-0)) :-
    reference(D), deadline_info(revise_notes, D, Band, Days).
test(near_deadline_inclusive_boundary, true(Band-Days == due_soon-2)) :-
    reference(D), deadline_info(read_article, D, Band, Days).
test(scheduled_boundary, true(Band-Days == scheduled-3)) :-
    reference(D), deadline_info(laundry, D, Band, Days).
test(no_deadline, true(Band-Days == no_deadline-none)) :-
    reference(D), deadline_info(walk, D, Band, Days).
test(reference_date_changes_urgency, true(Band == due_today)) :-
    deadline_info(submit_report, date(2026, 10, 25), Band, _).

test(exact_time_fit) :- reference(D), eligible(submit_report, 30, medium, D).
test(one_minute_too_short, [fail]) :- reference(D), eligible(submit_report, 29, medium, D).
test(completed_excluded, [fail]) :- reference(D), eligible(resume_edit, 60, high, D).
test(archived_excluded, [fail]) :- reference(D), eligible(archived_task, 60, high, D).
test(paused_goal_excluded, [fail]) :- reference(D), eligible(paused_reading, 60, high, D).
test(abandoned_goal_excluded, [fail]) :- reference(D), eligible(abandoned_plan, 60, high, D).
test(unknown_task_excluded, [fail]) :- reference(D), eligible(missing_task, 60, high, D).
test(energy_is_a_soft_preference) :- reference(D), eligible(exam_review, 90, low, D).

test(default_recommendation, true(Task == submit_report)) :-
    reference(D), recommend(60, medium, D, Task, _).
test(short_session_recommendation, true(Task == revise_notes)) :-
    reference(D), recommend(25, medium, D, Task, _).
test(fifteen_minute_recommendation, true(Task == send_application)) :-
    reference(D), recommend(15, low, D, Task, _).
test(five_minute_recommendation, true(Task == water_plants)) :-
    reference(D), recommend(5, low, D, Task, _).
test(zero_time_has_clear_result) :-
    reference(D), recommend(0, medium, D, Task, E), assertion(Task == none),
    assertion(E.blockers == [no_eligible_tasks]).
test(no_task_fits, true(Task == none)) :- reference(D), recommend(4, high, D, Task, _).
test(empty_database_has_clear_result) :-
    with_test_state((task_planner:clear_state, reference(D),
              recommend(60, high, D, Task, _), assertion(Task == none),
              validate_kb(E), assertion(E == []))).

test(low_energy_prefers_easy_work_within_same_priority) :-
    reference(D), ranked_tasks(60, low, D, Tasks), assertion(precedes(walk, coding_practice, Tasks)).
test(adequate_energy_prefers_work_in_progress) :-
    reference(D), ranked_tasks(60, medium, D, Tasks), assertion(precedes(coding_practice, walk, Tasks)).
test(urgency_precedes_energy) :-
    reference(D), recommend(60, low, D, Task, _), assertion(Task == submit_report).
test(priority_within_same_urgency_band) :-
    reference(D), ranked_tasks(60, high, D, Tasks), assertion(precedes(solve_exercises, read_article, Tasks)).
test(stable_id_tie_breaking) :-
    reference(D), ranked_tasks(60, high, D, Tasks), assertion(precedes(organize_drawer, sort_shelf, Tasks)).
test(recommendation_is_deterministic, true(Tasks == [submit_report])) :-
    reference(D), findall(T, recommend(60, medium, D, T, _), Tasks).

test(completed_prerequisite_allows_task) :-
    reference(D), eligible(outline_paper, 35, medium, D).
test(unfinished_prerequisite_blocks_task, [fail]) :-
    reference(D), eligible(write_paper, 120, high, D).
test(transitive_dependency_path, true(Path == [proofread_paper,write_paper,outline_paper,research_sources])) :-
    once(prerequisite_path(proofread_paper, research_sources, Path)).
test(transitive_blockers, true(Blockers == [outline_paper,write_paper])) :-
    blocked_by(proofread_paper, Blockers).
test(blocker_explanation) :-
    reference(D), explain_task(proofread_paper, 60, medium, D, E),
    assertion(E.eligible == false),
    assertion(memberchk(unfinished_prerequisites([outline_paper,write_paper]), E.blockers)).
test(positive_explanation) :-
    reference(D), explain_task(submit_report, 60, medium, D, E),
    assertion(E.eligible == true), assertion(E.blockers == []),
    assertion(memberchk(deadline(overdue,-1), E.reasons)),
    assertion(memberchk(time_required(30,60), E.reasons)).
test(cycle_update_rejected_and_rolled_back) :-
    with_test_state((catch(add_dependency(outline_paper, proofread_paper),
                    error(validation_error(Errors), _), true),
              nonvar(Errors), assertion(memberchk(dependency_cycle(outline_paper), Errors)),
              assertion(\+ depends_on(outline_paper, proofread_paper)),
              validate_kb(After), assertion(After == []))).
test(corrupt_cycle_queries_terminate) :-
    with_test_state((assertz(task_facts:depends_on(outline_paper, proofread_paper)),
              call_with_time_limit(2, once(dependency_cycle(outline_paper, Path))),
              assertion(Path == [outline_paper,proofread_paper,write_paper,outline_paper]),
              reference(D), call_with_time_limit(2, \+ eligible(write_paper, 120, high, D)),
              call_with_time_limit(2, session_plan(300, high, D, Plan, _, _)),
              assertion(\+ memberchk(write_paper, Plan)))).
test(missing_prerequisite_detected_and_blocked) :-
    with_test_state((assertz(task_facts:depends_on(walk, nonexistent)),
              validate_kb(Errors), assertion(memberchk(invalid_dependency(walk,nonexistent), Errors)),
              reference(D), assertion(\+ eligible(walk, 60, high, D)))).

test(sixty_minute_plan, true(Plan-Used-Unused == [submit_report,revise_notes,water_plants]-60-0)) :-
    reference(D), session_plan(60, medium, D, Plan, Used, Unused).
test(zero_time_plan, true(Plan-Used-Unused == []-0-0)) :-
    reference(D), session_plan(0, medium, D, Plan, Used, Unused).
test(plan_respects_budget_and_uniqueness) :-
    reference(D), session_plan(500, high, D, Plan, Used, Unused),
    maplist(remaining_minutes, Plan, Durations), sum_list(Durations, Sum),
    assertion(Sum == Used), assertion(Used =< 500), assertion(Used + Unused =:= 500),
    sort(Plan, Unique), length(Plan, N), length(Unique, N).
test(plan_unlocks_prerequisites_without_mutating_database) :-
    with_test_state((isolated_chain, reference(D),
              session_plan(60, high, D, Plan, Used, Unused),
              assertion(Plan == [first,middle,last]), assertion(Used == 60), assertion(Unused == 0),
              assertion(task_status(first, pending)), assertion(progress(first, 0)),
              assertion(\+ prerequisites_complete(middle)))).
test(plan_stops_when_next_prerequisite_will_not_fit) :-
    with_test_state((isolated_chain, reference(D), session_plan(40, high, D, Plan, Used, Unused),
              assertion(Plan == [first]), assertion(Used == 20), assertion(Unused == 20))).
test(branching_dag_deduplicates_shared_ancestors) :-
    with_test_state((isolated_chain, add_dependency(last, first),
                    blocked_by(last, Blockers), assertion(Blockers == [first,middle]),
                    validate_kb(Errors), assertion(Errors == []), reference(D),
                    session_plan(60, high, D, Plan, _, _),
                    assertion(Plan == [first,middle,last]))).
test(planning_is_deterministic) :-
    reference(D), findall(P, session_plan(60, medium, D, P, _, _), Plans),
    assertion(Plans == [[submit_report,revise_notes,water_plants]]).

test(new_goal_and_task) :-
    with_test_state((add_goal(g_new, 'Learn logical reasoning', academic),
              add_task(new_task, g_new, 'Read a logic chapter', study, 20, easy, medium, none),
              assertion(task_status(new_task, pending)), assertion(progress(new_task, 0)),
              reference(D), assertion(eligible(new_task, 20, low, D)))).
test(duplicate_goal_rejected, [throws(error(validation_error(duplicate_goal(g_home)),_))]) :-
    add_goal(g_home, 'Another home goal', household).
test(duplicate_task_rejected, [throws(error(validation_error(duplicate_task(walk)),_))]) :-
    add_task(walk, g_health, 'Another walk', exercise, 10, easy, low, none).
test(task_type_must_match_goal_category, [throws(error(validation_error(invalid_task_fields),_))]) :-
    add_task(bad_type, g_health, 'Study in a health category', study, 20, easy, low, none).
test(invalid_deadline_rejected, [throws(error(validation_error(invalid_task_fields),_))]) :-
    add_task(bad_date, g_health, 'A walk', exercise, 20, easy, low, date(2026,2,30)).
test(zero_duration_pending_task_rejected, [throws(error(validation_error(invalid_task_fields),_))]) :-
    add_task(bad_time, g_health, 'A walk', exercise, 0, easy, low, none).
test(unknown_goal_rejected, [throws(error(validation_error(invalid_task_fields),_))]) :-
    add_task(bad_goal, g_missing, 'A walk', exercise, 20, easy, low, none).
test(invalid_id_rejected, [throws(error(validation_error(invalid_goal_fields),_))]) :-
    add_goal('Invalid ID', 'Example', academic).
test(blank_title_rejected, [throws(error(validation_error(invalid_goal_fields),_))]) :-
    add_goal(g_blank, '   ', academic).

test(progress_updates_status_and_remaining_estimate) :-
    with_test_state((update_progress(walk, 50, 8),
              assertion(task_status(walk, in_progress)), assertion(progress(walk, 50)),
              assertion(remaining_minutes(walk, 8)), reference(D),
              assertion(eligible(walk, 8, low, D)))).
test(completion_unlocks_dependant) :-
    with_test_state((update_progress(outline_paper, 100, 0), reference(D),
              assertion(task_status(outline_paper, completed)),
              assertion(eligible(write_paper, 90, high, D)))).
test(blocked_task_cannot_be_marked_complete) :-
    with_test_state((catch(update_progress(write_paper, 100, 0), error(validation_error(Errors),_), true),
              nonvar(Errors), assertion(task_status(write_paper, pending)),
              assertion(remaining_minutes(write_paper, 90)), assertion(progress(write_paper, 0)))).
test(reopening_prerequisite_of_completed_work_rolls_back) :-
    with_test_state((update_progress(outline_paper, 100, 0),
                    catch(update_progress(research_sources, 50, 10),
                          error(validation_error(Errors),_), true), nonvar(Errors),
                    assertion(task_status(research_sources, completed)),
                    assertion(progress(research_sources, 100)),
                    assertion(remaining_minutes(research_sources, 0)))).
test(inconsistent_completion_rejected, [throws(error(validation_error(inconsistent_progress_or_minutes),_))]) :-
    update_progress(walk, 100, 5).
test(invalid_progress_rejected, [throws(error(validation_error(invalid_progress_or_minutes),_))]) :-
    update_progress(walk, 101, 5).
test(pausing_goal_changes_recommendations) :-
    with_test_state((set_goal_status(g_course, paused), reference(D),
              recommend(60, medium, D, Task, _), assertion(Task == send_application))).
test(archive_and_restore) :-
    with_test_state((set_archived(walk, true), reference(D), assertion(\+ eligible(walk,60,high,D)),
              set_archived(walk, false), assertion(task_status(walk, pending)),
              assertion(eligible(walk,60,high,D)))).
test(archived_progress_update_rejected, [throws(error(validation_error(restore_archived_task_first),_))]) :-
    update_progress(archived_task, 60, 10).
test(add_and_remove_dependency) :-
    with_test_state((add_dependency(walk, stretch), assertion(depends_on(walk, stretch)),
              remove_dependency(walk, stretch), assertion(\+ depends_on(walk, stretch)))).
test(self_dependency_rejected) :-
    with_test_state((catch(add_dependency(walk, walk), error(validation_error(Errors),_), true),
              nonvar(Errors), assertion(\+ depends_on(walk, walk)))).
test(missing_dependency_task_rejected, [throws(error(validation_error(unknown_dependency_task),_))]) :-
    add_dependency(walk, missing).

test(goal_progress_average, true(Percent == 20)) :- goal_progress(g_paper, Percent).
test(empty_goal_progress) :-
    with_test_state((add_goal(g_empty, 'An empty goal', personal), goal_progress(g_empty, P), assertion(P == 0))).
test(duplicate_attribute_detected) :-
    with_test_state((assertz(task_facts:priority(walk, urgent)), validate_kb(E),
              assertion(memberchk(invalid_task(walk), E)))).
test(missing_attribute_detected) :-
    with_test_state((retractall(task_facts:deadline(walk, _)), validate_kb(E),
              assertion(memberchk(invalid_task(walk), E)))).
test(orphan_attribute_detected) :-
    with_test_state((assertz(task_facts:priority(missing, low)), validate_kb(E),
              assertion(memberchk(orphan_attribute(priority,missing), E)))).
test(malformed_task_never_recommended) :-
    with_test_state((retractall(task_facts:remaining_minutes(submit_report, _)), reference(D),
              recommend(60, medium, D, Task, _), assertion(Task == revise_notes))).

test(json_round_trip) :-
    tmp_file(task_planner_roundtrip, File),
    setup_call_cleanup(true,
      with_test_state((task_planner:state_dict(Before), save_state(File),
                add_goal(g_temporary, 'An unsaved goal', personal), load_state(File),
                task_planner:state_dict(After), assertion(Before =@= After),
                assertion(\+ goal(g_temporary, _, _, _)),
                validate_kb(Errors), assertion(Errors == []))), delete_if_present(File)).
test(json_invalid_schema_preserves_database) :-
    tmp_file(task_planner_bad_schema, File),
    setup_call_cleanup(write_json(File, _{version:99}),
      with_test_state((catch(load_state(File), error(validation_error(invalid_snapshot_schema),_), Caught=true),
                assertion(Caught == true), knowledge_stats(S), assertion(S.tasks == 33))),
      delete_if_present(File)).
test(json_invalid_reference_rolls_back) :-
    tmp_file(task_planner_bad_reference, File),
    setup_call_cleanup(true,
      with_test_state((task_planner:state_dict(State), Bad = State.put(goals, []), write_json(File, Bad),
                catch(load_state(File), error(validation_error(Errors),_), true), nonvar(Errors),
                knowledge_stats(S), assertion(S.tasks == 33), assertion(S.goals == 11),
                validate_kb(After), assertion(After == []))), delete_if_present(File)).
test(json_trailing_content_rejected) :-
    tmp_file(task_planner_trailing, File),
    setup_call_cleanup(true,
      with_test_state((save_state(File),
                      setup_call_cleanup(open(File, append, Out), write(Out, ' extra'), close(Out)),
                      catch(load_state(File), error(validation_error(trailing_snapshot_content),_), Caught=true),
                      assertion(Caught == true), validate_kb(Errors), assertion(Errors == []))),
      delete_if_present(File)).
test(save_overwrites_previous_snapshot_atomically) :-
    tmp_file(task_planner_overwrite, File),
    setup_call_cleanup(true,
      with_test_state((save_state(File), update_progress(walk,50,8), save_state(File),
                update_progress(walk,60,6), load_state(File), assertion(progress(walk,50)),
                atom_concat(File, '.tmp', Temporary), assertion(\+ exists_file(Temporary)))),
      delete_if_present(File)).

test(negative_time_rejected, [throws(error(domain_error(nonnegative_minutes,-1),_))]) :-
    reference(D), recommend(-1, medium, D, _, _).
test(fractional_time_rejected, [throws(error(type_error(integer,1.5),_))]) :-
    reference(D), recommend(1.5, medium, D, _, _).
test(unknown_energy_rejected, [throws(error(domain_error(energy_level,extreme),_))]) :-
    reference(D), recommend(60, extreme, D, _, _).
test(invalid_reference_date_rejected, [throws(error(domain_error(calendar_date,date(2026,2,30)),_))]) :-
    recommend(60, medium, date(2026,2,30), _, _).
test(final_database_unchanged, true(Errors == [])) :-
    knowledge_stats(S), assertion(S.tasks == 33), assertion(S.facts == 314), validate_kb(Errors).

:- end_tests(task_planner).
