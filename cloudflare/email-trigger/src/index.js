// Cloudflare Worker: on a schedule, starts the "Daily email" GitHub workflow.
//
// GitHub's own cron is best-effort (runs are often late or skipped), but a
// workflow started through the API begins within seconds. Cloudflare's cron
// fires on time, so this Worker is the clock and GitHub does the work.
//
// Runs every 15 minutes because every time zone is a multiple of 15 minutes
// from UTC (India +5:30, Nepal +5:45...), so 9:00 local is always a run time.
//
// Secret: GITHUB_TOKEN, a fine-grained token with Actions: read & write on
// praveendhra/task_tracker_app only.

const REPO = 'praveendhra/task_tracker_app';
const WORKFLOW = 'daily-email.yml';

async function dispatch(env) {
  const res = await fetch(
    `https://api.github.com/repos/${REPO}/actions/workflows/${WORKFLOW}/dispatches`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.GITHUB_TOKEN}`,
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'task-tracker-email-trigger',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ ref: 'main' }),
    },
  );
  // GitHub answers 204 No Content on success.
  if (res.status !== 204) {
    throw new Error(`GitHub dispatch failed: ${res.status} ${await res.text()}`);
  }
}

export default {
  async scheduled(event, env, ctx) {
    if (!env.GITHUB_TOKEN) {
      console.error('GITHUB_TOKEN secret is not set');
      return;
    }
    ctx.waitUntil(dispatch(env));
  },

  // Visiting the Worker's URL shows that it is alive; it never triggers a run.
  async fetch() {
    return new Response('Task Tracker email trigger: runs every 15 minutes.\n', {
      headers: { 'content-type': 'text/plain' },
    });
  },
};
