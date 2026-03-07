# comment-email-notifier

Sends queued email jobs from `public.email_jobs` using Resend.

## Required env vars

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `RESEND_API_KEY`
- `EMAIL_FROM` (for example: `KanbanFlow <no-reply@yourdomain.com>`)
- `CRON_SECRET` (optional but recommended)

## Deploy

```bash
supabase functions deploy comment-email-notifier
```

## Set function secrets

```bash
supabase secrets set RESEND_API_KEY=xxx EMAIL_FROM="KanbanFlow <no-reply@yourdomain.com>" CRON_SECRET=your-secret
```

## Invoke manually

```bash
curl -X POST "https://<project-ref>.functions.supabase.co/comment-email-notifier" \
  -H "x-cron-secret: your-secret"
```

## Schedule

Call this function every 1 minute from:

- Supabase Scheduled Functions (if enabled in your project), or
- an external scheduler (GitHub Actions/cron job/Cloudflare cron/etc).

The function processes up to 50 pending jobs per run.
