// Writes preview.html / preview.txt from sample tasks: `node preview.mjs`.
import { writeFileSync } from 'node:fs';
import { buildDigest, normaliseTasks, renderHtml, renderText, subjectFor } from './email.mjs';

const tz = 'America/New_York';
const day = (n) => new Date(Date.now() + n * 86400000);
const raw = [
  { title: 'Migrate BackupCare pipelines to GitHub Actions', status: 2, priority: 3, dueDate: day(2), tags: ['work', 'devops'],
    steps: [{ id: 'a', title: 'Inventory', status: 3 }, { id: 'b', title: 'Port build pipelines', status: 3 }, { id: 'c', title: 'Port release pipelines with approvals', status: 2 }, { id: 'd', title: 'Cut over', status: 1 }], currentStepId: 'c' },
  { title: 'Rotate SQL Managed Instance credentials', status: 1, priority: 2, dueDate: day(-1), tags: ['security'],
    steps: [{ id: 'q', title: 'Generate new secrets in Key Vault', status: 1 }] },
  { title: 'Book flights for December', status: 1, priority: 3, dueDate: day(0) },
  { title: 'Weekend groceries', status: 1, priority: 0, dueDate: day(0) },
  { title: 'Refresh portfolio site', status: 2, priority: 1, dueDate: day(5), steps: [{ id: 'p', title: 'Write project blurbs', status: 2 }] },
  { title: 'Publish Terraform modules v2', status: 3, priority: 2, completedAt: day(-1) },
];
const tasks = normaliseTasks(raw, tz);
const d = buildDigest(tasks, new Intl.DateTimeFormat('en-CA', { timeZone: tz }).format(new Date()));
const opts = { name: 'Pravii', appUrl: 'https://task.praveendhra.com' };
writeFileSync('preview.html', renderHtml(d, opts));
writeFileSync('preview.txt', renderText(d, opts));
console.log(subjectFor(d));
console.log(renderText(d, opts));
