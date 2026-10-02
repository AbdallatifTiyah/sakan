import { createClient } from 'jsr:@supabase/supabase-js@2'
import { SignJWT, importPKCS8 } from 'npm:jose@5'

// استدعاها تريغر trg_notifications_send_push حصراً (مصادقة بسرّ مشترك
// بالهيدر x-push-trigger-secret، لا verify_jwt هون لأن المستدعي تريغر
// قاعدة بيانات لا مستخدم — الحارس الفعلي هو تطابق السرّ). service_role
// هون مستخدَم داخلياً بس (قراءة device_tokens)، ما بيوصل للتطبيق أبداً.
//
// FIREBASE_SERVICE_ACCOUNT: JSON كامل لحساب خدمة Firebase (client_email,
// private_key, project_id) — سرّ بأسرار Supabase فقط، يُستخدم لتوليد
// Google OAuth2 access token لإرسال FCM v1 API.

interface NotificationPayload {
  notification_id: string
  account_uid: string
  title: string
  body: string | null
  event_type: string
}

async function getGoogleAccessToken(serviceAccountJson: string): Promise<string> {
  const sa = JSON.parse(serviceAccountJson)
  const privateKey = await importPKCS8(sa.private_key, 'RS256')

  const jwt = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(sa.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(privateKey)

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  if (!res.ok) {
    throw new Error(`Google OAuth token exchange failed: ${await res.text()}`)
  }
  const data = await res.json()
  return data.access_token as string
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 })
  }

  const expectedSecret = Deno.env.get('PUSH_TRIGGER_SECRET')
  const givenSecret = req.headers.get('x-push-trigger-secret')
  if (!expectedSecret || givenSecret !== expectedSecret) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  }

  const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
  if (!serviceAccountJson) {
    return new Response(JSON.stringify({ error: 'FIREBASE_SERVICE_ACCOUNT not configured' }), { status: 500 })
  }

  const payload = (await req.json()) as NotificationPayload

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const adminClient = createClient(supabaseUrl, serviceKey)

  const { data: tokens, error } = await adminClient
    .from('device_tokens')
    .select('id, fcm_token')
    .eq('account_uid', payload.account_uid)

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
  if (!tokens || tokens.length === 0) {
    return new Response(JSON.stringify({ sent: 0, reason: 'no device tokens' }), { status: 200 })
  }

  const sa = JSON.parse(serviceAccountJson)
  const accessToken = await getGoogleAccessToken(serviceAccountJson)

  const staleTokenIds: string[] = []
  let sent = 0

  for (const row of tokens) {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: row.fcm_token,
            notification: {
              title: payload.title,
              body: payload.body ?? '',
            },
            data: {
              event_type: payload.event_type,
              notification_id: payload.notification_id,
            },
          },
        }),
      },
    )

    if (res.ok) {
      sent++
    } else {
      const errText = await res.text()
      // توكن منتهي/محذوف (تطبيق أُزيل أو أُعيد تثبيته) — نظّفه بدل محاولات متكررة فاشلة.
      if (errText.includes('UNREGISTERED') || errText.includes('NOT_FOUND')) {
        staleTokenIds.push(row.id)
      }
    }
  }

  if (staleTokenIds.length > 0) {
    await adminClient.from('device_tokens').delete().in('id', staleTokenIds)
  }

  return new Response(JSON.stringify({ sent, total: tokens.length, cleaned: staleTokenIds.length }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
