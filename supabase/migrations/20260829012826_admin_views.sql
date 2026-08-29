-- ═══ واجهات داخلية للوحة الإدارة — service_role فقط ═══
-- بتحتوي أرقام هواتف وعناوين. ممنوع منح anon أو authenticated أي صلاحية عليها.

create or replace view public.v_admin_listings as
select
  l.id, l.ref, l.title, l.description, l.kind, l.status, l.verification,
  l.price, l.deposit, l.bills_included, l.gender_pol, l.furnished,
  l.rooms_total, l.occupants_now, l.occupants_note, l.available_from, l.min_stay_months,
  l.landmark, l.exact_address, l.images, l.reject_reason,
  l.published_at, l.expires_at, l.last_confirmed_at, l.rented_at,
  l.created_at, l.updated_at, l.view_count, l.confirm_token,
  l.city_id, c.name_ar as city, l.area_id, a.name_ar as area,
  p.id as owner_id, p.first_name as owner_name, p.phone as owner_phone,
  p.verification_level as owner_level, p.is_blocked as owner_blocked,
  s.visit_date, s.room_exists, s.photos_match, s.door_lock, s.no_indoor_cameras,
  s.occupants_verified, s.exterior_lighting, s.gas_detector, s.notes as safety_notes,
  (select count(*) from contact_requests cr where cr.listing_id = l.id) as contacts,
  (select count(*) from contact_requests cr where cr.listing_id = l.id and cr.status = 'rented') as rentals,
  (select count(*) from reports r where r.listing_id = l.id and r.status = 'open') as open_reports,
  (select count(*) from reviews rv where rv.listing_id = l.id) as reviews_count,
  case when l.expires_at is null then null else (l.expires_at::date - current_date) end as days_left
from listings l
join cities c on c.id = l.city_id
join areas  a on a.id = l.area_id
left join profiles p on p.id = l.owner_id
left join listing_safety s on s.listing_id = l.id;

create or replace view public.v_admin_owners as
select
  p.id, p.first_name, p.full_name, p.phone, p.verification_level, p.is_blocked,
  p.created_at, p.city_id, c.name_ar as city,
  (select count(*) from listings l where l.owner_id = p.id) as listings_total,
  (select count(*) from listings l where l.owner_id = p.id and l.status = 'published') as listings_published,
  (select count(*) from listings l where l.owner_id = p.id and l.status = 'pending')   as listings_pending,
  (select count(*) from listings l where l.owner_id = p.id and l.status = 'rented')    as listings_rented,
  (select max(l.created_at) from listings l where l.owner_id = p.id) as last_listing_at,
  (select coalesce(sum(f.amount_due),0) from owner_fees f join listings l on l.id = f.listing_id
     where l.owner_id = p.id and f.status = 'due') as fees_due,
  (select coalesce(sum(f.amount_due),0) from owner_fees f join listings l on l.id = f.listing_id
     where l.owner_id = p.id and f.status = 'collected') as fees_collected,
  (select count(*) from reports r join listings l on l.id = r.listing_id where l.owner_id = p.id) as reports_total
from profiles p
left join cities c on c.id = p.city_id
where p.role = 'owner';

create or replace view public.v_admin_seekers as
select
  p.id, p.first_name, p.full_name, p.phone, p.gender, p.occupation, p.org_name,
  p.verification_level, p.verified_at, p.is_blocked, p.created_at, c.name_ar as city,
  (select count(*) from seeker_requests r where r.seeker_id = p.id) as requests_total,
  (select count(*) from seeker_requests r where r.seeker_id = p.id and r.status = 'published') as requests_active,
  (select count(*) from contact_requests cr where cr.seeker_id = p.id) as contacts_total,
  (select count(*) from contact_requests cr where cr.seeker_id = p.id and cr.status = 'rented') as rentals
from profiles p
left join cities c on c.id = p.city_id
where p.role = 'seeker';

create or replace view public.v_admin_reports as
select
  r.id, r.category, r.status, r.details, r.action_note, r.created_at,
  r.reporter_phone, r.reporter_id,
  l.id as listing_id, l.ref as listing_ref, l.title as listing_title, l.status as listing_status,
  p.id as owner_id, p.first_name as owner_name, p.phone as owner_phone,
  (r.category in ('harassment','entered_room','camera','fake_listing')) as is_serious
from reports r
left join listings l on l.id = r.listing_id
left join profiles p on p.id = l.owner_id;

create or replace view public.v_admin_pipeline as
select
  cr.id, cr.status, cr.created_at, cr.outcome_at, cr.agent_notes, cr.outcome_source,
  cr.seeker_name, cr.seeker_phone, cr.seeker_id,
  sp.first_name as seeker_profile_name, sp.phone as seeker_profile_phone,
  sp.verification_level as seeker_level,
  l.id as listing_id, l.ref as listing_ref, l.title as listing_title,
  l.price, l.status as listing_status,
  c.name_ar as city, a.name_ar as area,
  op.first_name as owner_name, op.phone as owner_phone,
  f.id as fee_id, f.status as fee_status, f.amount_due
from contact_requests cr
left join listings l on l.id = cr.listing_id
left join cities c on c.id = l.city_id
left join areas  a on a.id = l.area_id
left join profiles op on op.id = l.owner_id
left join profiles sp on sp.id = cr.seeker_id
left join owner_fees f on f.contact_request_id = cr.id;

create or replace view public.v_admin_fees as
select
  f.id, f.status, f.amount_base, f.amount_due, f.promo_code, f.note,
  f.collected_at, f.created_at, f.contact_request_id,
  l.id as listing_id, l.ref as listing_ref, l.title as listing_title,
  p.id as owner_id, p.first_name as owner_name, p.phone as owner_phone,
  c.name_ar as city
from owner_fees f
join listings l on l.id = f.listing_id
left join profiles p on p.id = l.owner_id
left join cities c on c.id = l.city_id;

create or replace view public.v_kpi_daily as
select
  d::date as day,
  (select count(*) from listings         where created_at::date  = d::date) as new_listings,
  (select count(*) from listings         where published_at::date = d::date) as published,
  (select count(*) from seeker_requests  where created_at::date  = d::date) as new_requests,
  (select count(*) from contact_requests where created_at::date  = d::date) as contacts,
  (select count(*) from contact_requests where status = 'rented' and outcome_at::date = d::date) as rentals,
  (select count(*) from reports          where created_at::date  = d::date) as reports
from generate_series(current_date - 29, current_date, interval '1 day') d;

create or replace view public.v_admin_activity as
select 'admin'::text as stream, a.created_at, a.actor, a.action,
       a.subject_type, a.subject_id, a.subject_ref,
       a.from_state, a.to_state, a.reason, a.meta
from admin_actions a
union all
select 'event', e.created_at, coalesce(e.actor_role::text, e.source::text), e.event_type,
       case when e.listing_id is not null then 'listing'
            when e.request_id is not null then 'request'
            else 'system' end,
       coalesce(e.listing_id, e.request_id, e.seeker_id), null, null, null, null, e.meta
from events e
union all
select 'verification', v.created_at, coalesce(v.verifier_id::text,'system'), v.action,
       v.subject_type, v.subject_id, null, v.from_level, v.to_level, v.reject_reason, '{}'::jsonb
from verification_log v;

-- الصلاحيات: service_role فقط
do $$
declare vw text;
begin
  foreach vw in array array['v_admin_listings','v_admin_owners','v_admin_seekers','v_admin_reports',
                            'v_admin_pipeline','v_admin_fees','v_kpi_daily','v_admin_activity']
  loop
    execute format('revoke all on public.%I from anon, authenticated, public', vw);
    execute format('grant select on public.%I to service_role', vw);
  end loop;
end $$;
