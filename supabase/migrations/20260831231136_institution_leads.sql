-- طلبات المؤسسات (NGOs/جامعات/شركات) — تسعير معكوس: المؤسسة بتدفع، المالك لأ.
-- يدوي بالكامل: الجدول بيلتقط الطلب بس، والمتابعة والتسعير الفعلي يدوياً عبر المندوب.

create type public.institution_org_type as enum ('ngo','university','company','government','other');
create type public.institution_lead_status as enum ('new','contacted','negotiating','won','lost');

create table public.institution_leads (
  id            uuid primary key default gen_random_uuid(),
  org_name      text not null,
  org_type      public.institution_org_type not null default 'other',
  contact_name  text not null,
  contact_phone text not null,
  contact_email text,
  city_id       int references public.cities(id),
  rooms_needed  smallint,
  message       text,
  status        public.institution_lead_status not null default 'new',
  staff_notes   text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

alter table public.institution_leads enable row level security;

create policy anon_insert_institution_lead on public.institution_leads
  for insert to anon, authenticated
  with check (status = 'new' and staff_notes is null);

create policy staff_read on public.institution_leads
  for select to authenticated using (is_staff());

grant insert on public.institution_leads to anon, authenticated;
grant select on public.institution_leads to authenticated;
grant all    on public.institution_leads to service_role;

create index idx_institution_leads_status on public.institution_leads (status, created_at desc);

-- ═══ تحديث حالة الطلب — نفس نمط باقي دوال الإدارة (بدون p_actor، الفاعل من auth.uid()) ═══
create or replace function public.admin_institution_lead_status(
  p_id uuid, p_status text, p_notes text default null
) returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare v_org text;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;

  update institution_leads
     set status = p_status::institution_lead_status,
         staff_notes = coalesce(p_notes, staff_notes),
         updated_at = now()
   where id = p_id
  returning org_name into v_org;

  insert into admin_actions (actor, action, subject_type, subject_id, subject_ref, to_state, reason)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'institution_lead_status',
          'institution_lead', p_id, v_org, p_status, p_notes);
end $$;

revoke execute on function public.admin_institution_lead_status(uuid, text, text) from public;
revoke execute on function public.admin_institution_lead_status(uuid, text, text) from anon;
grant  execute on function public.admin_institution_lead_status(uuid, text, text) to authenticated, service_role;

notify pgrst, 'reload schema';
