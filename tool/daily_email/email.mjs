// Builds the morning summary email from a user's tasks. Pure functions, no I/O,
// so it can be previewed and tested locally.

/** YYYY-MM-DD of an instant in a time zone. */
export function localDate(date, timeZone) {
  const p = Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone, year: 'numeric', month: '2-digit', day: '2-digit',
    }).formatToParts(date).map((x) => [x.type, x.value]),
  );
  return `${p.year}-${p.month}-${p.day}`;
}

/** Hour 0-23 of an instant in a time zone. */
export function localHour(date, timeZone) {
  return Number(
    new Intl.DateTimeFormat('en-US', { timeZone, hour: 'numeric', hourCycle: 'h23' })
      .format(date),
  );
}

function addDays(ymd, n) {
  const [y, m, d] = ymd.split('-').map(Number);
  const t = new Date(Date.UTC(y, m - 1, d + n));
  return t.toISOString().slice(0, 10);
}

function prettyDate(ymd, opts = { weekday: 'short', month: 'short', day: 'numeric' }) {
  const [y, m, d] = ymd.split('-').map(Number);
  return new Intl.DateTimeFormat('en-US', { ...opts, timeZone: 'UTC' })
    .format(new Date(Date.UTC(y, m - 1, d)));
}

function dueLabel(dueYmd, today) {
  if (!dueYmd) return '';
  if (dueYmd === today) return 'Due today';
  if (dueYmd === addDays(today, 1)) return 'Due tomorrow';
  if (dueYmd === addDays(today, -1)) return 'Due yesterday';
  if (dueYmd < today) {
    const days = Math.round((Date.parse(today) - Date.parse(dueYmd)) / 86400000);
    return `${days} days overdue`;
  }
  return `Due ${prettyDate(dueYmd)}`;
}

/**
 * Normalises raw task documents into what the email needs.
 * `dueDate`/`completedAt` may be Date, Firestore Timestamp, or null.
 */
export function normaliseTasks(rawTasks, timeZone) {
  const toDate = (v) => (v == null ? null : typeof v.toDate === 'function' ? v.toDate() : new Date(v));
  return rawTasks.map((t) => {
    const steps = Array.isArray(t.steps) ? t.steps : [];
    const current =
      steps.find((s) => s.id === t.currentStepId && s.status !== 3) ||
      steps.find((s) => s.status !== 3) ||
      null;
    const due = toDate(t.dueDate);
    const completed = toDate(t.completedAt);
    // Step dates are stored as "YYYY-MM-DD" already.
    const stepDue = (st) => (typeof st.dueDate === 'string' && /^\d{4}-\d{2}-\d{2}/.test(st.dueDate) ? st.dueDate.slice(0, 10) : null);
    return {
      title: (t.title || 'Untitled task').trim(),
      status: Number(t.status) || 1,
      priority: Number(t.priority) || 0,
      tags: Array.isArray(t.tags) ? t.tags : [],
      archived: !!t.archived,
      due: due ? localDate(due, timeZone) : null,
      completed: completed ? localDate(completed, timeZone) : null,
      stepsDone: steps.filter((s) => s.status === 3).length,
      stepsTotal: steps.length,
      currentStep: current ? (current.title || '').trim() : null,
      currentStepDue: current ? stepDue(current) : null,
      openSteps: steps
        .filter((st) => st.status !== 3)
        .map((st) => ({ title: (st.title || '').trim(), due: stepDue(st), status: Number(st.status) || 1 })),
    };
  });
}

/** Groups tasks into the email's sections. Each open task appears once. */
export function buildDigest(tasks, today) {
  const live = tasks.filter((t) => !t.archived);
  const open = live.filter((t) => t.status !== 3);
  const byDue = (a, b) => (a.due || '9999').localeCompare(b.due || '9999');
  const used = new Set();
  const take = (list) => {
    const out = list.filter((t) => !used.has(t));
    out.forEach((t) => used.add(t));
    return out;
  };

  const high = take(open.filter((t) => t.priority === 3).sort(byDue));
  const overdue = take(open.filter((t) => t.due && t.due < today).sort(byDue));
  const dueToday = take(open.filter((t) => t.due === today).sort((a, b) => b.priority - a.priority));
  const inProgress = take(open.filter((t) => t.status === 2).sort((a, b) => b.priority - a.priority || byDue(a, b)));
  const weekEnd = addDays(today, 7);
  const upcoming = take(open.filter((t) => t.due && t.due > today && t.due <= weekEnd).sort(byDue));
  // Everything still open that didn't fit above, so no task is ever left out.
  const other = take(open.slice().sort((a, b) => b.priority - a.priority || byDue(a, b)));

  // Steps that are overdue or due today, from any open task (high priority first).
  const stepsDue = open
    .flatMap((t) => t.openSteps
      .filter((st) => st.due && st.due <= today)
      .map((st) => ({ ...st, task: t.title, priority: t.priority })))
    .sort((a, b) => a.due.localeCompare(b.due) || b.priority - a.priority);

  return {
    today,
    openCount: open.length,
    stepsDue,
    stepsOverdueCount: stepsDue.filter((st) => st.due < today).length,
    high,
    overdue,
    dueToday,
    inProgress,
    upcoming,
    other,
    highCount: open.filter((t) => t.priority === 3).length,
    overdueCount: open.filter((t) => t.due && t.due < today).length,
    dueTodayCount: open.filter((t) => t.due === today).length,
    doneYesterday: live.filter((t) => t.status === 3 && t.completed === addDays(today, -1)).length,
  };
}

export function subjectFor(d) {
  const bits = [];
  if (d.highCount) bits.push(`${d.highCount} high priority`);
  if (d.overdueCount) bits.push(`${d.overdueCount} overdue`);
  if (d.dueTodayCount) bits.push(`${d.dueTodayCount} due today`);
  if (d.stepsDue.length) bits.push(`${d.stepsDue.length} step${d.stepsDue.length === 1 ? '' : 's'} due`);
  if (!bits.length) bits.push(`${d.openCount} open task${d.openCount === 1 ? '' : 's'}`);
  return `Your day: ${bits.join(', ')}`;
}

const esc = (s) =>
  String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

const C = {
  bg: '#F4F6FA', card: '#FFFFFF', text: '#111827', muted: '#6B7280', line: '#E5E7EB',
  brand: '#0676E0', red: '#DC2626', amber: '#D97706', blue: '#2563EB', green: '#16A34A',
};

function pill(text, color) {
  return `<span style="display:inline-block;padding:2px 8px;margin:0 6px 4px 0;border-radius:6px;font-size:12px;font-weight:600;color:${color};background:${color}1A;">${esc(text)}</span>`;
}

function taskRow(t, today) {
  const meta = [];
  if (t.priority === 3) meta.push(pill('High', C.red));
  else if (t.priority === 2) meta.push(pill('Medium', C.amber));
  if (t.due) meta.push(pill(dueLabel(t.due, today), t.due < today ? C.red : t.due === today ? C.amber : C.muted));
  if (t.status === 2) meta.push(pill('In progress', C.blue));
  for (const tag of t.tags.slice(0, 3)) meta.push(pill(`#${tag}`, C.brand));

  const progress = t.stepsTotal
    ? `<div style="margin-top:6px;height:5px;background:${C.line};border-radius:4px;overflow:hidden;"><div style="height:5px;width:${Math.round((t.stepsDone / t.stepsTotal) * 100)}%;background:${C.brand};"></div></div>
       <div style="font-size:12px;color:${C.muted};margin-top:3px;">${t.stepsDone} of ${t.stepsTotal} step${t.stepsTotal === 1 ? '' : 's'}</div>`
    : '';
  const stepDue = t.currentStepDue
    ? ` <span style="font-weight:600;color:${t.currentStepDue < today ? C.red : t.currentStepDue === today ? C.amber : C.muted};">&middot; ${esc(dueLabel(t.currentStepDue, today))}</span>`
    : '';
  const step = t.currentStep
    ? `<div style="font-size:13px;color:${C.muted};margin-top:2px;">&#8627; ${esc(t.currentStep)}${stepDue}</div>`
    : '';
  return `<tr><td style="padding:12px 0;border-top:1px solid ${C.line};">
    <div style="font-size:15px;font-weight:600;color:${C.text};">${esc(t.title)}</div>
    ${step}
    <div style="margin-top:6px;">${meta.join('')}</div>
    ${progress}
  </td></tr>`;
}

function stepRow(st, today) {
  const color = st.due < today ? C.red : C.amber;
  return `<tr><td style="padding:10px 0;border-top:1px solid ${C.line};">
    <div style="font-size:14px;font-weight:600;color:${C.text};">${esc(st.title || 'Untitled step')}</div>
    <div style="font-size:13px;color:${C.muted};margin-top:2px;">in ${esc(st.task)}${st.priority === 3 ? ` ${pill('High', C.red)}` : ''}</div>
    <div style="margin-top:4px;">${pill(dueLabel(st.due, today), color)}${st.status === 2 ? pill('In progress', C.blue) : ''}</div>
  </td></tr>`;
}

function stepSection(steps, today) {
  if (!steps.length) return '';
  return `<tr><td style="padding:20px 24px 4px;">
    <div style="font-size:12px;font-weight:700;letter-spacing:1px;text-transform:uppercase;color:${C.amber};">Steps due &middot; ${steps.length}</div>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:6px;">${steps.map((st) => stepRow(st, today)).join('')}</table>
  </td></tr>`;
}

function section(title, color, tasks, today, note = '') {
  if (!tasks.length) return '';
  return `<tr><td style="padding:20px 24px 4px;">
    <div style="font-size:12px;font-weight:700;letter-spacing:1px;text-transform:uppercase;color:${color};">${esc(title)} &middot; ${tasks.length}</div>
    ${note ? `<div style="font-size:12px;color:${C.muted};margin-top:2px;">${esc(note)}</div>` : ''}
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:6px;">${tasks.map((t) => taskRow(t, today)).join('')}</table>
  </td></tr>`;
}

function stat(value, label, color) {
  return `<td align="center" width="25%" style="padding:12px 4px;">
    <div style="font-size:24px;font-weight:700;color:${color};line-height:1;">${value}</div>
    <div style="font-size:12px;color:${C.muted};margin-top:4px;">${esc(label)}</div></td>`;
}

export function renderHtml(d, { name, appUrl }) {
  const hello = name ? `Good morning, ${esc(name)}` : 'Good morning';
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(subjectFor(d))}</title></head>
<body style="margin:0;padding:0;background:${C.bg};font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${C.bg};padding:24px 12px;"><tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:${C.card};border-radius:16px;overflow:hidden;">
  <tr><td style="padding:20px 24px 0;">
    <table role="presentation" cellpadding="0" cellspacing="0"><tr>
      <td style="vertical-align:middle;"><img src="${esc(appUrl)}/mark.png" width="32" height="32" alt="" style="display:block;border:0;width:32px;height:32px;"></td>
      <td style="vertical-align:middle;padding-left:10px;font-size:15px;font-weight:700;color:${C.text};">Task Tracker</td>
    </tr></table>
  </td></tr>
  <tr><td style="padding:16px 24px 8px;">
    <div style="font-size:13px;color:${C.muted};">${esc(prettyDate(d.today, { weekday: 'long', month: 'long', day: 'numeric' }))}</div>
    <div style="font-size:22px;font-weight:700;color:${C.text};margin-top:4px;">${hello}</div>
    <div style="font-size:14px;color:${C.muted};margin-top:4px;">Here's where your tasks stand.</div>
  </td></tr>
  <tr><td style="padding:8px 16px;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:${C.bg};border-radius:12px;"><tr>
      ${stat(d.highCount, 'High priority', C.red)}
      ${stat(d.overdueCount, 'Overdue', d.overdueCount ? C.red : C.muted)}
      ${stat(d.dueTodayCount, 'Due today', C.amber)}
      ${stat(d.doneYesterday, 'Done yesterday', C.green)}
    </tr></table>
  </td></tr>
  ${section('High priority', C.red, d.high, d.today)}
  ${section('Overdue', C.red, d.overdue, d.today)}
  ${section('Due today', C.amber, d.dueToday, d.today)}
  ${stepSection(d.stepsDue, d.today)}
  ${section('In progress', C.blue, d.inProgress, d.today)}
  ${section('Coming up this week', C.muted, d.upcoming, d.today)}
  ${section('Other open tasks', C.muted, d.other, d.today)}
  <tr><td align="center" style="padding:24px;">
    <a href="${esc(appUrl)}" style="display:inline-block;background:${C.brand};color:#fff;text-decoration:none;font-weight:600;font-size:15px;padding:12px 22px;border-radius:10px;">Open Task Tracker</a>
  </td></tr>
</table>
<div style="max-width:600px;font-size:12px;color:${C.muted};padding:16px 8px;text-align:center;">
  You get this because the daily summary is on. Turn it off or change the time in Task Tracker &rarr; Settings.
</div>
</td></tr></table></body></html>`;
}

export function renderText(d, { name, appUrl }) {
  const lines = [`${name ? `Good morning, ${name}` : 'Good morning'}: ${prettyDate(d.today)}`, ''];
  lines.push(`${d.highCount} high priority · ${d.overdueCount} overdue · ${d.dueTodayCount} due today · ${d.doneYesterday} done yesterday`, '');
  const sec = (title, list) => {
    if (!list.length) return;
    lines.push(`${title.toUpperCase()} (${list.length})`);
    for (const t of list) {
      const meta = [t.priority === 3 ? 'High' : '', t.due ? dueLabel(t.due, d.today) : '', t.stepsTotal ? `${t.stepsDone}/${t.stepsTotal} step${t.stepsTotal === 1 ? '' : 's'}` : '']
        .filter(Boolean).join(' · ');
      lines.push(`- ${t.title}${meta ? ` (${meta})` : ''}`);
      if (t.currentStep) lines.push(`    -> ${t.currentStep}${t.currentStepDue ? ` (${dueLabel(t.currentStepDue, d.today)})` : ''}`);
    }
    lines.push('');
  };
  sec('High priority', d.high);
  sec('Overdue', d.overdue);
  sec('Due today', d.dueToday);
  if (d.stepsDue.length) {
    lines.push(`STEPS DUE (${d.stepsDue.length})`);
    for (const st of d.stepsDue) lines.push(`- ${st.title} (in ${st.task}; ${dueLabel(st.due, d.today)})`);
    lines.push('');
  }
  sec('In progress', d.inProgress);
  sec('Coming up this week', d.upcoming);
  sec('Other open tasks', d.other);
  lines.push(`Open Task Tracker: ${appUrl}`, '', 'Turn this email off in Task Tracker > Settings.');
  return lines.join('\n');
}
