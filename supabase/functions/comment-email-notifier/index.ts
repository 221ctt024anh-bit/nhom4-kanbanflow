import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type EmailJob = {
  id: string;
  recipient_email: string;
  subject: string;
  body_text: string;
  attempts: number;
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";
const EMAIL_FROM = Deno.env.get("EMAIL_FROM") ?? "";
const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? "";
const MAX_RETRIES = 5;
const BATCH_SIZE = 50;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Content-Type": "application/json",
  };
}

async function reserveJobs(limit: number): Promise<EmailJob[]> {
  const { data, error } = await supabase
    .from("email_jobs")
    .select("id")
    .eq("status", "pending")
    .order("created_at", { ascending: true })
    .limit(limit);
  if (error) throw error;
  if (!data || data.length === 0) return [];

  const ids = data.map((x) => x.id as string);
  const { error: markError } = await supabase
    .from("email_jobs")
    .update({ status: "processing" })
    .in("id", ids)
    .eq("status", "pending");
  if (markError) throw markError;

  const { data: jobs, error: jobError } = await supabase
    .from("email_jobs")
    .select("id,recipient_email,subject,body_text,attempts")
    .in("id", ids)
    .eq("status", "processing")
    .order("created_at", { ascending: true });
  if (jobError) throw jobError;

  return (jobs ?? []) as EmailJob[];
}

async function sendWithResend(job: EmailJob) {
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: EMAIL_FROM,
      to: [job.recipient_email],
      subject: job.subject,
      text: job.body_text,
    }),
  });

  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = typeof body?.message === "string" ? body.message : `HTTP ${response.status}`;
    throw new Error(message);
  }

  return body?.id as string | undefined;
}

async function handleJob(job: EmailJob) {
  try {
    const providerMessageId = await sendWithResend(job);
    const { error } = await supabase
      .from("email_jobs")
      .update({
        status: "sent",
        provider_message_id: providerMessageId ?? null,
        error_message: null,
        sent_at: new Date().toISOString(),
      })
      .eq("id", job.id);
    if (error) throw error;
    return { sent: 1, failed: 0 };
  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : "Unknown error";
    const newAttempts = (job.attempts ?? 0) + 1;
    const nextStatus = newAttempts >= MAX_RETRIES ? "failed" : "pending";

    await supabase
      .from("email_jobs")
      .update({
        status: nextStatus,
        attempts: newAttempts,
        error_message: errorMessage,
      })
      .eq("id", job.id);

    return { sent: 0, failed: 1 };
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(JSON.stringify({ ok: true }), { headers: corsHeaders() });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: corsHeaders(),
    });
  }

  if (CRON_SECRET) {
    const incoming = req.headers.get("x-cron-secret");
    if (incoming !== CRON_SECRET) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: corsHeaders(),
      });
    }
  }

  if (!RESEND_API_KEY || !EMAIL_FROM) {
    return new Response(
      JSON.stringify({ error: "Missing RESEND_API_KEY or EMAIL_FROM in function env" }),
      { status: 500, headers: corsHeaders() },
    );
  }

  try {
    const jobs = await reserveJobs(BATCH_SIZE);
    let sent = 0;
    let failed = 0;
    for (const job of jobs) {
      const result = await handleJob(job);
      sent += result.sent;
      failed += result.failed;
    }

    return new Response(
      JSON.stringify({
        ok: true,
        processed: jobs.length,
        sent,
        failed,
      }),
      { headers: corsHeaders() },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({
        ok: false,
        error: err instanceof Error ? err.message : "Unknown error",
      }),
      { status: 500, headers: corsHeaders() },
    );
  }
});
