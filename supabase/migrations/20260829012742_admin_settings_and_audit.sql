-- ═══ إعدادات المنصة ═══
create table if not exists public.settings (
  key        text primary key,
  value      jsonb not null,
  label_ar   text  not null,
  kind       text  not null default 'number',
  updated_at timestamptz not null default now()
);
alter table public.settings enable row level security;
revoke all on public.settings from anon, authenticated, public;
grant all on public.settings to service_role;

insert into public.settings (key, value, label_ar, kind) values
  ('fee_base',                 '200',          'رسم النجاح الأساسي من المالك (شيكل)', 'number'),
  ('listing_expiry_days',      '21',           'صلاحية الإعلان بعد النشر (يوم)',       'number'),
  ('review_publish_threshold', '3',            'أقل عدد تقييمات قبل النشر',            'number'),
  ('seeker_badge_fee',         '30',           'رسم شارة توثيق الباحث (شيكل)',         'number'),
  ('seekers_free_launch',      'true',         'الباحث مجاني بفترة الإطلاق',           'bool'),
  ('gate_rooms',               '100',          'بوابة القرار — غرف موثّقة ميدانياً',   'number'),
  ('gate_rentals',             '25',           'بوابة القرار — تأجيرات مؤكدة',         'number'),
  ('gate_date',                '"2026-11-30"', 'بوابة القرار — التاريخ',               'date'),
  ('expiring_soon_days',       '3',            'تنبيه قرب انتهاء الإعلان (يوم)',       'number')
on conflict (key) do nothing;

create or replace function public.setting_num(p_key text, p_default numeric)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce((select (value #>> '{}')::numeric from settings where key = p_key), p_default);
$$;
revoke execute on function public.setting_num(text, numeric) from public;
grant execute on function public.setting_num(text, numeric) to service_role;

-- ═══ سجل إجراءات الإدارة ═══
create table if not exists public.admin_actions (
  id          bigserial primary key,
  actor       text not null default 'direct',
  action      text not null,
  subject_type text not null,
  subject_id  uuid,
  subject_ref text,
  from_state  text,
  to_state    text,
  reason      text,
  meta        jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
alter table public.admin_actions enable row level security;
revoke all on public.admin_actions from anon, authenticated, public;
grant all on public.admin_actions to service_role;
grant usage, select on sequence public.admin_actions_id_seq to service_role;

create index if not exists idx_admin_actions_created on public.admin_actions (created_at desc);
create index if not exists idx_admin_actions_subject on public.admin_actions (subject_type, subject_id);

-- المسجّل: بيقرأ الفاعل من app.actor (بينحط داخل RPC)، وإلا بيسجّل 'direct'
create or replace function public.audit_admin_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare v text := coalesce(nullif(current_setting('app.actor', true), ''), 'direct');
begin
  if tg_table_name = 'listings' then
    if new.status is distinct from old.status then
      insert into admin_actions(actor,action,subject_type,subject_id,subject_ref,from_state,to_state,reason)
      values (v,'listing_status','listing',new.id,new.ref,old.status::text,new.status::text,new.reject_reason);
    end if;
    if new.verification is distinct from old.verification then
      insert into admin_actions(actor,action,subject_type,subject_id,subject_ref,from_state,to_state)
      values (v,'listing_verification','listing',new.id,new.ref,old.verification::text,new.verification::text);
    end if;
    if new.expires_at is distinct from old.expires_at and new.status is not distinct from old.status then
      insert into admin_actions(actor,action,subject_type,subject_id,subject_ref,from_state,to_state)
      values (v,'listing_expiry','listing',new.id,new.ref,old.expires_at::text,new.expires_at::text);
    end if;

  elsif tg_table_name = 'profiles' then
    if new.verification_level is distinct from old.verification_level then
      insert into admin_actions(actor,action,subject_type,subject_id,subject_ref,from_state,to_state)
      values (v,'profile_level','profile',new.id,new.first_name,old.verification_level::text,new.verification_level::text);
    end if;
    if new.is_blocked is distinct from old.is_blocked then
      insert into admin_actions(actor,action,subject_type,subject_id,subject_ref,from_state,to_state)
      values (v, case when new.is_blocked then 'profile_block' else 'profile_unblock' end,
              'profile',new.id,new.first_name,old.is_blocked::text,new.is_blocked::text);
    end if;

  elsif tg_table_name = 'reports' then
    if new.status is distinct from old.status then
      insert into admin_actions(actor,action,subject_type,subject_id,from_state,to_state,reason,meta)
      values (v,'report_status','report',new.id,old.status::text,new.status::text,new.action_note,
              jsonb_build_object('category', new.category, 'listing_id', new.listing_id));
    end if;

  elsif tg_table_name = 'owner_fees' then
    if new.status is distinct from old.status then
      insert into admin_actions(actor,action,subject_type,subject_id,from_state,to_state,reason,meta)
      values (v,'fee_status','fee',new.id,old.status::text,new.status::text,new.note,
              jsonb_build_object('amount_due', new.amount_due, 'listing_id', new.listing_id));
    end if;

  elsif tg_table_name = 'contact_requests' then
    if new.status is distinct from old.status then
      insert into admin_actions(actor,action,subject_type,subject_id,from_state,to_state,reason,meta)
      values (v,'contact_status','contact',new.id,old.status::text,new.status::text,new.agent_notes,
              jsonb_build_object('listing_id', new.listing_id));
    end if;

  elsif tg_table_name = 'settings' then
    if new.value is distinct from old.value then
      insert into admin_actions(actor,action,subject_type,subject_ref,from_state,to_state)
      values (v,'setting_change','setting',new.key,old.value #>> '{}',new.value #>> '{}');
    end if;

  elsif tg_table_name = 'listing_safety' then
    insert into admin_actions(actor,action,subject_type,subject_id,to_state,meta)
    values (v,'field_visit','listing',new.listing_id,new.visit_date::text,
            jsonb_build_object('no_indoor_cameras', new.no_indoor_cameras,
                               'door_lock', new.door_lock,
                               'room_exists', new.room_exists,
                               'photos_match', new.photos_match));
  end if;
  return null;
end $$;

drop trigger if exists trg_audit_listings on public.listings;
drop trigger if exists trg_audit_profiles on public.profiles;
drop trigger if exists trg_audit_reports  on public.reports;
drop trigger if exists trg_audit_fees     on public.owner_fees;
drop trigger if exists trg_audit_contacts on public.contact_requests;
drop trigger if exists trg_audit_settings on public.settings;
drop trigger if exists trg_audit_safety   on public.listing_safety;

create trigger trg_audit_listings after update on public.listings          for each row execute function audit_admin_change();
create trigger trg_audit_profiles after update on public.profiles          for each row execute function audit_admin_change();
create trigger trg_audit_reports  after update on public.reports           for each row execute function audit_admin_change();
create trigger trg_audit_fees     after update on public.owner_fees        for each row execute function audit_admin_change();
create trigger trg_audit_contacts after update on public.contact_requests  for each row execute function audit_admin_change();
create trigger trg_audit_settings after update on public.settings          for each row execute function audit_admin_change();
create trigger trg_audit_safety   after insert or update on public.listing_safety for each row execute function audit_admin_change();
