// Receives an in-app inquiry and forwards it by email.
//
// The recipient address lives ONLY in this function's `FEEDBACK_TO` secret. It
// is deliberately absent from the app and from this repository: the app ships to
// users (a `mailto:` link or a bundled constant would be readable by anyone) and
// the repository is public.
//
// Every message is also stored in `public.feedback` so nothing is lost when the
// mail provider is down — the insert uses the service-role key, so the table
// needs no client-facing RLS policy.
//
// Deploy:
//   supabase functions deploy send-feedback
//   supabase secrets set FEEDBACK_TO='...' RESEND_API_KEY='...' \
//                        FEEDBACK_FROM='Kerminal <noreply@your-domain>'
//
// `verify_jwt` is disabled (see config.toml) so users who never signed in can
// still write in; the anon key is still required to reach the function.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const MAX_MESSAGE = 5000;
const MAX_CONTACT = 200;
const MAX_META = 200;

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

/** Trims and length-caps a client-supplied string. */
function clean(value: unknown, max: number): string {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}

/// The key that bypasses RLS, under either naming scheme.
///
/// Projects on the legacy JWT keys get `SUPABASE_SERVICE_ROLE_KEY` as a plain
/// string. Projects migrated to publishable/secret keys instead get
/// `SUPABASE_SECRET_KEYS`, a JSON value keyed by key name (`default` for the
/// one created automatically). Reading only the legacy name meant the client was
/// built with `undefined`, so every insert ran unauthenticated and RLS — which
/// has no policies on `feedback` by design — refused it.
function resolveServiceKey(): string | null {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (legacy) return legacy;

  const raw = Deno.env.get('SUPABASE_SECRET_KEYS');
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    // Shape is not contractual, so accept the plausible ones rather than
    // failing on a schema change.
    const candidates: unknown[] = Array.isArray(parsed)
      ? parsed
      : typeof parsed === 'object' && parsed !== null
      ? [(parsed as Record<string, unknown>).default, ...Object.values(parsed)]
      : [parsed];
    for (const c of candidates) {
      if (typeof c === 'string' && c.length > 0) return c;
      if (typeof c === 'object' && c !== null) {
        for (const field of ['api_key', 'key', 'secret', 'value']) {
          const v = (c as Record<string, unknown>)[field];
          if (typeof v === 'string' && v.length > 0) return v;
        }
      }
    }
  } catch (e) {
    console.error('could not parse SUPABASE_SECRET_KEYS', e);
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid json' }, 400);
  }

  const message = clean(body.message, MAX_MESSAGE);
  if (message.length < 5) {
    return json({ error: 'message too short' }, 400);
  }
  // Optional: how the sender wants to be reached back. Never required, so an
  // anonymous report still goes through.
  const contact = clean(body.contact, MAX_CONTACT);
  const platform = clean(body.platform, MAX_META);
  const appVersion = clean(body.appVersion, MAX_META);

  const to = Deno.env.get('FEEDBACK_TO');
  const resendKey = Deno.env.get('RESEND_API_KEY');
  const from = Deno.env.get('FEEDBACK_FROM') ?? 'Kerminal <onboarding@resend.dev>';

  // Store first: a durable record even if the mail provider rejects the send.
  const serviceKey = resolveServiceKey();
  if (!serviceKey) {
    console.error(
      'No service key in the environment: neither SUPABASE_SERVICE_ROLE_KEY ' +
        'nor SUPABASE_SECRET_KEYS is set. Without it the insert runs ' +
        'unauthenticated and RLS (no policies on feedback) rejects it.',
    );
    return json({ error: 'server is misconfigured' }, 500);
  }
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, serviceKey);
  const { error: insertError } = await supabase.from('feedback').insert({
    message,
    contact: contact || null,
    platform: platform || null,
    app_version: appVersion || null,
  });
  if (insertError) {
    // Logged in full: the message alone ("could not store") does not say
    // whether the table is missing, a column is wrong, or RLS refused it.
    console.error('feedback insert failed', JSON.stringify(insertError));
  }

  // Nothing was kept anywhere — the only case worth asking the user to retry.
  if (insertError) return json({ error: 'could not store your message' }, 500);

  if (!to || !resendKey) {
    console.error(
      'FEEDBACK_TO or RESEND_API_KEY is not set — the message was stored but ' +
        'nobody will be emailed about it.',
    );
    return json({ ok: true, delivered: false });
  }

  const lines = [
    message,
    '',
    '---',
    `Reply to : ${contact || '(not provided)'}`,
    `Platform : ${platform || '(unknown)'}`,
    `Version  : ${appVersion || '(unknown)'}`,
  ];

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${resendKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from,
        to: [to],
        // Replying in a mail client should reach the user directly when they
        // left an address.
        ...(contact.includes('@') ? { reply_to: contact } : {}),
        subject: `[Kerminal] Inquiry from ${platform || 'app'}`,
        text: lines.join('\n'),
      }),
    });
    if (!res.ok) {
      const body = await res.text();
      console.error('resend failed', res.status, body);
      // 403 with the shared onboarding@resend.dev sender means Resend only
      // allows delivery to the address that owns the Resend account — verify a
      // domain and set FEEDBACK_FROM to it.
      return json({ ok: true, delivered: false });
    }
  } catch (e) {
    console.error('resend threw', e);
    return json({ ok: true, delivered: false });
  }

  return json({ ok: true, delivered: true });
});
