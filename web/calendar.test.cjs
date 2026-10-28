const test = require('node:test');
const assert = require('node:assert/strict');
const calendar = require('./public/calendar.js');

test('month grid starts on Monday and includes adjoining month dates', () => {
  const days = calendar.days('2026-10');
  assert.equal(days.length, 42);
  assert.equal(days[0], '2026-09-28');
  assert.equal(days[41], '2026-11-08');
  assert.equal(new Set(days).size, 42);
  assert.equal(days.filter(day => day.startsWith('2026-10')).length, 31);
});

test('February has 29 days in a leap year and 28 otherwise', () => {
  assert.ok(calendar.days('2028-02').includes('2028-02-29'));
  assert.equal(calendar.days('2028-02').filter(day => day.startsWith('2028-02')).length, 29);
  assert.equal(calendar.days('2026-02').filter(day => day.startsWith('2026-02')).length, 28);
  assert.ok(!calendar.days('2026-02').includes('2026-02-29'));
});

test('month navigation crosses year boundaries without skipping short months', () => {
  assert.equal(calendar.shiftMonth('2026-12', 1), '2027-01');
  assert.equal(calendar.shiftMonth('2027-01', -1), '2026-12');
  assert.equal(calendar.shiftMonth('2028-03', -1), '2028-02');
  assert.equal(calendar.shiftMonth('2028-02', 1), '2028-03');
});

test('navigation stays inside supported calendar years', () => {
  assert.equal(calendar.shiftMonth('1900-01', -1), '1900-01');
  assert.equal(calendar.shiftMonth('9999-12', 1), '9999-12');
});

test('date selection uses exact due dates and includes completed records', () => {
  const tasks = [
    {id:'a',due_date:'2026-10-30',status:'pending'},
    {id:'b',due_date:'2026-10-31',status:'pending'},
    {id:'c',due_date:'2026-10-30',status:'completed'}
  ];
  assert.deepEqual(calendar.tasksOn(tasks,'2026-10-30').map(task=>task.id), ['a','c']);
  assert.deepEqual(calendar.tasksOn(tasks,'2026-11-01'), []);
  assert.equal(tasks.length,3);
});

test('display dates do not depend on the computer timezone', () => {
  const original = process.env.TZ;
  try {
    for (const timezone of ['Pacific/Honolulu','Asia/Manila','Pacific/Kiritimati']) {
      process.env.TZ = timezone;
      assert.equal(calendar.format('2026-10-30',{weekday:'long',month:'long',day:'numeric',year:'numeric'}), 'Friday, October 30, 2026');
      assert.equal(calendar.days('2026-10')[0], '2026-09-28');
    }
  } finally {
    if (original === undefined) delete process.env.TZ;
    else process.env.TZ = original;
  }
});
