'use strict';

// Calendar days are ISO dates supplied by the planner in Asia/Manila. Use UTC
// for display arithmetic so the computer's timezone cannot move a deadline.
const PlannerCalendar = (() => {
  function date(iso) {
    return new Date(`${iso}T12:00:00Z`);
  }

  function key(value) {
    return value.toISOString().slice(0, 10);
  }

  function shiftMonth(month, offset) {
    const first = date(`${month}-01`);
    first.setUTCMonth(first.getUTCMonth() + offset);
    // Keep navigation within the calendar years accepted by the planner.
    if (first.getUTCFullYear() < 1900 || first.getUTCFullYear() > 9999) return month;
    return key(first).slice(0, 7);
  }

  function days(month) {
    const first = date(`${month}-01`);
    const mondayOffset = (first.getUTCDay() + 6) % 7;
    first.setUTCDate(1 - mondayOffset);
    return Array.from({length:42}, (_, index) => {
      const day = new Date(first);
      day.setUTCDate(first.getUTCDate() + index);
      return key(day);
    });
  }

  function format(iso, options) {
    return date(iso).toLocaleDateString('en-PH', {timeZone:'UTC', ...options});
  }

  function tasksOn(tasks, iso) {
    return tasks.filter(task => task.due_date === iso);
  }

  return {days, shiftMonth, format, tasksOn};
})();

// Allow date-boundary checks with Node's built-in test runner; no build step.
if (typeof module !== 'undefined') module.exports = PlannerCalendar;
