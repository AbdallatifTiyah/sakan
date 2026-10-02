-- device_tokens: توكنات FCM لإرسال push notifications من تطبيق الموبايل —
-- مرتبطة بـaccount_uid (نفس نمط notifications/saved_listings، self_all RLS).
-- بدون push إلا لمستخدم مسجّل دخول (نفس شرط notifications نفسها أصلاً).
create table device_tokens (
  id uuid primary key default gen_random_uuid(),
  account_uid uuid not null,
  fcm_token text not null unique,
  platform text not null check (platform in ('android','ios')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_device_tokens_account_uid on device_tokens(account_uid);

alter table device_tokens enable row level security;

create policy self_all on device_tokens
  for all
  using (account_uid = auth.uid())
  with check (account_uid = auth.uid());

revoke all on device_tokens from anon;
grant select, insert, update, delete on device_tokens to authenticated;
grant all on device_tokens to service_role;

-- pg_net لاستدعاء Edge Function بشكل غير متزامن من داخل تريغر Postgres.
create extension if not exists pg_net;

-- عند أي إشعار جديد بجدول notifications الموجود أصلاً، استدعِ Edge Function
-- send-push فوراً لإرسال push حقيقي لأجهزة صاحب الحساب. المصادقة بسرّ مشترك
-- (PUSH_TRIGGER_SECRET كمتغيّر بيئة الدالة، push_trigger_secret بـVault هون)
-- — صفر service_role أو أي مفتاح حسّاس داخل الدالة/التريغر نفسه (قاعدة ٥).
create or replace function trigger_send_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_secret text;
begin
  select decrypted_secret into v_secret
  from vault.decrypted_secrets
  where name = 'push_trigger_secret';

  if v_secret is null then
    return new;
  end if;

  perform net.http_post(
    url := 'https://yckteijitcqjtedoyoyv.supabase.co/functions/v1/send-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-trigger-secret', v_secret
    ),
    body := jsonb_build_object(
      'notification_id', new.id,
      'account_uid', new.account_uid,
      'title', new.title,
      'body', new.body,
      'event_type', new.event_type
    )
  );
  return new;
end;
$$;

revoke execute on function trigger_send_push() from public;

create trigger trg_notifications_send_push
  after insert on notifications
  for each row
  execute function trigger_send_push();
