-- رابط تقييم موقّع بالإعلان — نفس نمط confirm_token على listings.
-- بيشتغل حتى للمستأجر اللي ما قدّم طلبه عبر المنصة، لأنه مش مربوط بـseeker_id.

alter table public.listings
  add column if not exists review_token uuid not null default gen_random_uuid();

create unique index if not exists listings_review_token_key
  on public.listings using btree (review_token);

comment on column public.listings.review_token is
  'رمز سري برابط التقييم اللي المندوب بيشاركه مع المستأجر (واتساب) — بيشتغل حتى لو المستأجر مو مسجّل بالمنصة.';

-- الأعمدة الجديدة بذيل القائمة فقط — create or replace view شرط.
create or replace view v_admin_listings as
select l.id, l.ref, l.title, l.description, l.kind, l.status, l.verification,
       l.price, l.deposit, l.bills_included, l.gender_pol, l.furnished,
       l.rooms_total, l.occupants_now, l.occupants_note, l.available_from,
       l.min_stay_months, l.landmark, l.exact_address, l.images, l.reject_reason,
       l.published_at, l.expires_at, l.last_confirmed_at, l.rented_at,
       l.created_at, l.updated_at, l.view_count, l.confirm_token,
       l.city_id, c.name_ar as city, l.area_id, a.name_ar as area,
       p.id as owner_id, p.first_name as owner_name, p.phone as owner_phone,
       p.verification_level as owner_level, p.is_blocked as owner_blocked,
       s.visit_date, s.room_exists, s.photos_match, s.door_lock,
       s.no_indoor_cameras, s.occupants_verified, s.exterior_lighting,
       s.gas_detector, s.notes as safety_notes,
       (select count(*) from contact_requests cr where cr.listing_id = l.id) as contacts,
       (select count(*) from contact_requests cr
         where cr.listing_id = l.id and cr.status = 'rented'::contact_status) as rentals,
       (select count(*) from reports r
         where r.listing_id = l.id and r.status = 'open'::report_status) as open_reports,
       (select count(*) from reviews rv where rv.listing_id = l.id) as reviews_count,
       case when l.expires_at is null then null::integer
            else l.expires_at::date - current_date end as days_left,
       s.private_bathroom, s.kitchen_access, s.hot_water, s.heating,
       s.internet, s.emergency_exit, s.street_access, s.owner_met,
       l.features,
       -- ▼ جديد
       l.review_token
from listings l
join cities c on c.id = l.city_id
join areas  a on a.id = l.area_id
left join profiles p on p.id = l.owner_id
left join listing_safety s on s.listing_id = l.id;

alter view v_admin_listings set (security_invoker = on);
revoke all on v_admin_listings from anon;
grant select on v_admin_listings to authenticated, service_role;

-- ═══ سياق العرض قبل التعبئة: يتحقق من التوكن ويرجّع بيانات غير حسّاسة فقط ═══
create or replace function public.review_link_info(p_ref text, p_token uuid)
returns table(title text, city text, area text)
language sql
security definer
set search_path to 'public', 'pg_temp'
as $$
  select l.title, c.name_ar, a.name_ar
  from listings l
  join cities c on c.id = l.city_id
  join areas  a on a.id = l.area_id
  where l.ref = p_ref and l.review_token = p_token;
$$;

revoke execute on function public.review_link_info(text, uuid) from public;
grant  execute on function public.review_link_info(text, uuid) to anon, authenticated, service_role;

-- ═══ تسجيل التقييم عبر الرابط الموقّع — بدون تسجيل دخول ═══
create or replace function public.submit_review(
  p_ref text,
  p_token uuid,
  p_stage text,
  p_r_maintenance smallint,
  p_r_quiet smallint,
  p_r_accuracy smallint,
  p_r_safety_night smallint,
  p_entered_without_permission boolean default null,
  p_deposit_returned boolean default null
) returns boolean
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare v_id uuid;
begin
  select id into v_id from listings
   where ref = p_ref and review_token = p_token;

  if v_id is null then
    raise exception 'رابط غير صالح';
  end if;

  if p_r_maintenance   not between 1 and 5
  or p_r_quiet         not between 1 and 5
  or p_r_accuracy      not between 1 and 5
  or p_r_safety_night  not between 1 and 5 then
    raise exception 'التقييم لازم يكون من ١ لـ٥';
  end if;

  insert into reviews (listing_id, stage, r_maintenance, r_quiet, r_accuracy,
                        r_safety_night, entered_without_permission, deposit_returned)
  values (v_id, p_stage::review_stage, p_r_maintenance, p_r_quiet, p_r_accuracy,
          p_r_safety_night, p_entered_without_permission, p_deposit_returned);

  insert into events (event_type, source, listing_id, meta)
  values ('review_submitted', 'user', v_id, jsonb_build_object('stage', p_stage));

  return true;
end $$;

revoke execute on function public.submit_review(text, uuid, text, smallint, smallint, smallint, smallint, boolean, boolean) from public;
grant  execute on function public.submit_review(text, uuid, text, smallint, smallint, smallint, smallint, boolean, boolean) to anon, authenticated, service_role;

notify pgrst, 'reload schema';
