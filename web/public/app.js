'use strict';
const $ = id => document.getElementById(id);
const pretty = s => String(s).replaceAll('_', ' ').replace(/\b\w/g, c => c.toUpperCase());
const esc = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let state;
let busy = false;
let noticeTimer;

async function api(path, body) {
  const response = await fetch(path, body === undefined ? {} : {
    method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(body)
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || `Request failed (${response.status}).`);
  return data;
}

function showError(error) {
  $('notice').hidden = true;
  $('error').textContent = error.message || 'Unable to connect. Check that the local server is running.';
  $('error').hidden = false;
  $('error').scrollIntoView({behavior:'smooth', block:'nearest'});
}

function notice(message) {
  $('error').hidden = true;
  $('notice').textContent = message;
  $('notice').hidden = false;
  clearTimeout(noticeTimer);
  noticeTimer = setTimeout(() => { $('notice').hidden = true; }, 4500);
}

function deadline(days) {
  if (days < 0) return `${-days}d overdue`;
  if (days === 0) return 'Due today';
  if (days === 1) return 'Due tomorrow';
  return `Due in ${days} days`;
}

function taskCard(task, completed = false) {
  return `<article class="task-card"><div class="task-top">
    <button class="task-check" data-action="${completed ? 'reopen' : 'complete'}" data-id="${esc(task.id)}" aria-label="${completed ? 'Reopen' : 'Complete'} ${esc(task.title)}">${completed ? '✓' : ''}</button>
    <div class="task-info"><h4 class="task-title">${esc(task.title)}</h4><div class="task-meta"><span>${esc(pretty(task.type))}</span><span>·</span><span>${task.minutes} min</span><span>·</span><span>${esc(task.due_date)}</span></div></div>
    <button class="delete" data-action="delete-task" data-id="${esc(task.id)}" aria-label="Delete ${esc(task.title)}">×</button></div>
    ${completed ? '' : `<p class="task-reason">${esc(task.reason)}</p><div class="task-tags"><span class="tag ${task.days_left <= 2 ? 'due' : ''}">${esc(deadline(task.days_left))}</span><span class="tag ${task.fits_time ? 'fits' : 'long'}">${task.fits_time ? 'Fits your time' : 'Needs more time'}</span><span class="tag">${esc(pretty(task.priority))} priority</span><span class="tag">${esc(pretty(task.difficulty))} · ${esc(task.energy)} energy</span></div>`}</article>`;
}

function render() {
  const pending = state.tasks.filter(task => task.status === 'pending');
  const completed = state.tasks.filter(task => task.status === 'completed');
  $('pending-count').textContent = pending.length;
  $('completed-count').textContent = completed.length;
  $('class-count').textContent = state.classes.length;
  $('fact-count').textContent = state.system_fact_count;
  const date = new Date(`${state.today}T12:00:00+08:00`);
  $('today').textContent = date.toLocaleDateString('en-PH', {timeZone:'Asia/Manila', weekday:'long',month:'long',day:'numeric'}).toUpperCase();
  const groups = [
    ['do_first','Do First','Due in 2 days or less','No urgent tasks. A little breathing room.'],
    ['do_next','Do Next','Due in 3–5 days','Nothing coming up in the next 3–5 days.'],
    ['do_later','Do Later','Due after 5 days','Your longer-term tasks will appear here.']
  ];
  $('board').innerHTML = groups.map(([id,title,range,empty]) => {
    const tasks = pending.filter(task => task.bucket === id);
    return `<section class="bucket ${id}" aria-label="${title}"><div class="bucket-heading"><div class="bucket-title"><span class="dot" aria-hidden="true"></span><h3>${title}</h3><small>${range}</small></div><span class="count">${tasks.length}</span></div>${tasks.length ? tasks.map(task => taskCard(task)).join('') : `<p class="empty">${empty}</p>`}</section>`;
  }).join('');
  $('completed-label').textContent = `${completed.length} task${completed.length === 1 ? '' : 's'}`;
  $('completed').innerHTML = completed.length ? completed.map(task => taskCard(task,true)).join('') : '<p class="empty">Your finished tasks will appear here.</p>';
  $('classes').innerHTML = state.classes.length ? state.classes.map(item => `<div class="class-row"><span class="class-day">${esc(item.day.slice(0,3))}</span><div class="class-info"><strong>${esc(item.subject)}</strong><span>${esc(pretty(item.day))} · ${clock(item.start)}–${clock(item.end)}</span></div><button class="delete" data-action="delete-class" data-id="${esc(item.id)}" aria-label="Delete ${esc(item.subject)} class">×</button></div>`).join('') : '<p class="empty">No classes yet. Add your first weekly class on the left.</p>';
}

function clock(minutes) {
  const hour = Math.floor(minutes/60);
  return `${hour%12 || 12}:${String(minutes%60).padStart(2,'0')} ${hour < 12 || hour === 24 ? 'AM' : 'PM'}${hour === 24 ? ' (next day)' : ''}`;
}

function updateType() {
  const type = state.types.find(type => type.id === $('task-type').value);
  if (!type) return;
  $('task-minutes').value = type.minutes;
  $('type-info').textContent = `${pretty(type.category)} · ${pretty(type.priority)} priority · ${pretty(type.difficulty)} · ${type.energy} energy`;
}

async function refresh() {
  state = await api(`/api/state?minutes=${encodeURIComponent($('available').value)}`);
  render();
}

async function change(path, body, message, onSaved = () => {}) {
  if (busy) return;
  busy = true;
  document.querySelectorAll('button').forEach(button => { button.disabled = true; });
  try {
    await api(path, body);
    onSaved();
    await refresh();
    notice(message);
  } catch (error) { showError(error); }
  finally {
    busy = false;
    document.querySelectorAll('button').forEach(button => { button.disabled = false; });
  }
}

$('task-type').addEventListener('change', updateType);
$('task-form').addEventListener('submit', event => {
  event.preventDefault();
  change('/api/tasks', {title:$('task-title').value, type:$('task-type').value,
    days_left:Number($('task-days').value), minutes:Number($('task-minutes').value)},
    'Task saved. Your next steps are up to date.', () => { $('task-title').value = ''; $('task-title').focus(); });
});
$('class-form').addEventListener('submit', event => {
  event.preventDefault();
  const minuteValue = value => { const [h,m] = value.split(':').map(Number); return h*60+m; };
  const start = minuteValue($('class-start').value), end = minuteValue($('class-end').value);
  if (end <= start) { showError(new Error('Class end must be after its start on the same day.')); return; }
  change('/api/classes', {subject:$('class-subject').value,day:$('class-day').value,start,end},
    'Class saved to your weekly schedule.', () => { $('class-subject').value = ''; });
});
$('time-form').addEventListener('submit', async event => {
  event.preventDefault();
  if (busy) return;
  try { await refresh(); $('error').hidden = true; } catch (error) { showError(error); }
});
document.addEventListener('click', event => {
  const button = event.target.closest('button[data-action]');
  if (!button || busy) return;
  const {action,id} = button.dataset;
  if (action === 'complete' || action === 'reopen') {
    change('/api/task_status', {id,status:action === 'complete' ? 'completed' : 'pending'},
      action === 'complete' ? 'One less thing on your plate. Task completed.' : 'Task reopened.');
  } else if (action === 'delete-task') {
    change('/api/delete_task', {id}, 'Task deleted.');
  } else if (action === 'delete-class') {
    change('/api/delete_class', {id}, 'Class deleted.');
  }
});

async function init() {
  await refresh();
  $('task-type').innerHTML = state.types.map(type => `<option value="${esc(type.id)}">${esc(pretty(type.id))}</option>`).join('');
  $('task-type').value = 'assignment';
  $('task-type').disabled = false;
  document.querySelectorAll('button[type="submit"]').forEach(button => { button.disabled = false; });
  updateType();
}
init().catch(showError);
// Refresh date-relative rules when a tab resumes or stays open past midnight.
document.addEventListener('visibilitychange', () => { if (!document.hidden && state && !busy) refresh().catch(showError); });
setInterval(() => { if (!document.hidden && state && !busy) refresh().catch(showError); },60000);
