-- عملة الإعلان (شيكل/دينار/دولار) — عملة واحدة تنطبق على السعر والتأمين معاً
do $$ begin
  if not exists (select 1 from pg_type where typname = 'currency_code') then
    create type currency_code as enum ('ILS','JOD','USD');
  end if;
end $$;

alter table listings add column if not exists currency currency_code not null default 'ILS';

-- تفصيل الفواتير الثلاثة (مياه/كهرباء/انترنت) بدل خانة "شاملة/غير شاملة" الواحدة
alter table listings add column if not exists bills_water boolean not null default false;
alter table listings add column if not exists bills_electricity boolean not null default false;
alter table listings add column if not exists bills_internet boolean not null default false;

update listings set bills_water = bills_included, bills_electricity = bills_included, bills_internet = bills_included;

-- استبدال submit_listing: توقيع جديد (p_bills الفردي انشال، محله ٣ معطيات + p_currency) — استبدال كامل لتجنّب overload
drop function if exists public.submit_listing(text, text, text, integer, numeric, text, text, boolean, date, text, text, text, text[], numeric, boolean, smallint, smallint, jsonb);

create function public.submit_listing(
  p_name text, p_phone text, p_title text, p_area integer, p_price numeric, p_kind text, p_pol text,
  p_furnished boolean, p_from date, p_occ text default null, p_landmark text default null, p_desc text default null,
  p_features text[] default '{}', p_deposit numeric default null, p_rooms smallint default null,
  p_min_stay smallint default null, p_images jsonb default '[]', p_currency text default 'ILS',
  p_bills_water boolean default false, p_bills_electricity boolean default false, p_bills_internet boolean default false
)
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_owner uuid; v_ref text; v_city int; v_images jsonb; v_bills_included boolean;
begin
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' then
    raise exception 'الاسم والرقم مطلوبان';
  end if;

  select city_id into v_city from areas where id = p_area and is_active;
  if v_city is null then raise exception 'منطقة غير صحيحة'; end if;

  v_bills_included := coalesce(p_bills_water,false) and coalesce(p_bills_electricity,false) and coalesce(p_bills_internet,false);

  insert into profiles (role, first_name, phone, city_id)
  values ('owner', trim(p_name), trim(p_phone), v_city)
  returning id into v_owner;

  select coalesce(jsonb_agg(v), '[]'::jsonb) into v_images
    from (
      select v from jsonb_array_elements_text(coalesce(p_images, '[]'::jsonb)) v limit 6
    ) t;

  insert into listings (owner_id, city_id, area_id, title, description, price, currency,
                        kind, gender_pol, furnished, available_from,
                        occupants_note, landmark, features, deposit,
                        bills_included, bills_water, bills_electricity, bills_internet,
                        rooms_total, min_stay_months, images)
  values (v_owner, v_city, p_area, trim(p_title), nullif(trim(coalesce(p_desc,'')),''),
          p_price, coalesce(nullif(p_currency,''),'ILS')::currency_code,
          p_kind::listing_kind, p_pol::gender_policy, coalesce(p_furnished,true),
          p_from, nullif(trim(coalesce(p_occ,'')),''), nullif(trim(coalesce(p_landmark,'')),''),
          coalesce(p_features,'{}'), p_deposit,
          v_bills_included, coalesce(p_bills_water,false), coalesce(p_bills_electricity,false), coalesce(p_bills_internet,false),
          p_rooms, p_min_stay, v_images)
  returning ref into v_ref;

  insert into events (event_type, source, actor_role, meta)
  values ('listing_created','user','owner', jsonb_build_object('ref', v_ref));

  return v_ref;
end $function$;

revoke all on function public.submit_listing(text, text, text, integer, numeric, text, text, boolean, date, text, text, text, text[], numeric, smallint, smallint, jsonb, text, boolean, boolean, boolean) from public;
grant execute on function public.submit_listing(text, text, text, integer, numeric, text, text, boolean, date, text, text, text, text[], numeric, smallint, smallint, jsonb, text, boolean, boolean, boolean) to anon, authenticated, service_role;

-- الواجهات: إضافة الأعمدة الجديدة بذيل القائمة
create or replace view v_listings_public as
 SELECT l.id, l.ref, l.title, l.description, c.name_ar AS city, c.slug AS city_slug, a.name_ar AS area, a.id AS area_id,
    l.landmark, l.kind, l.price, l.bills_included, l.deposit, l.gender_pol, l.furnished, l.rooms_total,
    l.occupants_now, l.occupants_note, l.available_from, l.min_stay_months, l.images, l.verification,
    l.published_at, l.expires_at, l.view_count, COALESCE((p.verification_level)::integer, 0) AS owner_level,
    s.visit_date, s.door_lock, s.no_indoor_cameras, s.room_exists, s.photos_match, s.occupants_verified,
    s.exterior_lighting, s.gas_detector,
    ( SELECT count(*) AS count FROM reviews r WHERE ((r.listing_id = l.id) AND r.is_published)) AS review_count,
    ( SELECT round(avg((((((r.r_maintenance + r.r_quiet) + r.r_accuracy) + r.r_safety_night))::numeric / 4.0)), 1) AS round
           FROM reviews r WHERE ((r.listing_id = l.id) AND r.is_published)) AS review_avg,
    c.id AS city_id, s.private_bathroom, s.kitchen_access, s.hot_water, s.heating, s.internet,
    s.emergency_exit, s.street_access, l.features, l.video_verified_at,
    l.currency, l.bills_water, l.bills_electricity, l.bills_internet
   FROM ((((listings l JOIN cities c ON ((c.id = l.city_id))) JOIN areas a ON ((a.id = l.area_id)))
     LEFT JOIN profiles p ON ((p.id = l.owner_id))) LEFT JOIN listing_safety s ON ((s.listing_id = l.id)))
  WHERE (l.status = 'published'::listing_status);

create or replace view v_admin_listings as
 SELECT l.id, l.ref, l.title, l.description, l.kind, l.status, l.verification, l.price, l.deposit, l.bills_included,
    l.gender_pol, l.furnished, l.rooms_total, l.occupants_now, l.occupants_note, l.available_from, l.min_stay_months,
    l.landmark, l.exact_address, l.images, l.reject_reason, l.published_at, l.expires_at, l.last_confirmed_at,
    l.rented_at, l.created_at, l.updated_at, l.view_count, l.confirm_token, l.city_id, c.name_ar AS city, l.area_id,
    a.name_ar AS area, p.id AS owner_id, p.first_name AS owner_name, p.phone AS owner_phone,
    p.verification_level AS owner_level, p.is_blocked AS owner_blocked, s.visit_date, s.room_exists, s.photos_match,
    s.door_lock, s.no_indoor_cameras, s.occupants_verified, s.exterior_lighting, s.gas_detector, s.notes AS safety_notes,
    ( SELECT count(*) AS count FROM contact_requests cr WHERE (cr.listing_id = l.id)) AS contacts,
    ( SELECT count(*) AS count FROM contact_requests cr WHERE ((cr.listing_id = l.id) AND (cr.status = 'rented'::contact_status))) AS rentals,
    ( SELECT count(*) AS count FROM reports r WHERE ((r.listing_id = l.id) AND (r.status = 'open'::report_status))) AS open_reports,
    ( SELECT count(*) AS count FROM reviews rv WHERE (rv.listing_id = l.id)) AS reviews_count,
        CASE WHEN (l.expires_at IS NULL) THEN NULL::integer ELSE ((l.expires_at)::date - CURRENT_DATE) END AS days_left,
    s.private_bathroom, s.kitchen_access, s.hot_water, s.heating, s.internet, s.emergency_exit, s.street_access,
    s.owner_met, l.features, l.review_token, l.video_verified_at,
    l.currency, l.bills_water, l.bills_electricity, l.bills_internet
   FROM ((((listings l JOIN cities c ON ((c.id = l.city_id))) JOIN areas a ON ((a.id = l.area_id)))
     LEFT JOIN profiles p ON ((p.id = l.owner_id))) LEFT JOIN listing_safety s ON ((s.listing_id = l.id)));
alter view v_admin_listings set (security_invoker = on);

create or replace view v_admin_pipeline as
 SELECT cr.id, cr.status, cr.created_at, cr.outcome_at, cr.agent_notes, cr.outcome_source, cr.seeker_name,
    cr.seeker_phone, cr.seeker_id, sp.first_name AS seeker_profile_name, sp.phone AS seeker_profile_phone,
    sp.verification_level AS seeker_level, l.id AS listing_id, l.ref AS listing_ref, l.title AS listing_title,
    l.price, l.status AS listing_status, c.name_ar AS city, a.name_ar AS area, op.first_name AS owner_name,
    op.phone AS owner_phone, f.id AS fee_id, f.status AS fee_status, f.amount_due, l.currency
   FROM ((((((contact_requests cr LEFT JOIN listings l ON ((l.id = cr.listing_id)))
     LEFT JOIN cities c ON ((c.id = l.city_id))) LEFT JOIN areas a ON ((a.id = l.area_id)))
     LEFT JOIN profiles op ON ((op.id = l.owner_id))) LEFT JOIN profiles sp ON ((sp.id = cr.seeker_id)))
     LEFT JOIN owner_fees f ON ((f.contact_request_id = cr.id)));
alter view v_admin_pipeline set (security_invoker = on);

-- لوحات المالك/الباحث الذاتية — إضافة العملة لعرض السعر صح
create or replace function public.my_owner_dashboard()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare v_uid uuid := auth.uid(); v_owner uuid;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
  select id into v_owner from profiles where account_uid = v_uid and role = 'owner';
  if v_owner is null then
    return jsonb_build_object('listings','[]'::jsonb,'requests','[]'::jsonb);
  end if;

  return jsonb_build_object(
    'listings', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', l.id, 'ref', l.ref, 'title', l.title, 'status', l.status,
        'verification', l.verification, 'price', l.price, 'currency', l.currency,
        'city', c.name_ar, 'area', a.name_ar,
        'published_at', l.published_at, 'expires_at', l.expires_at,
        'days_left', case when l.expires_at is null then null
                          else l.expires_at::date - current_date end,
        'view_count', l.view_count, 'reject_reason', l.reject_reason,
        'confirm_token', l.confirm_token
      ) order by l.created_at desc), '[]'::jsonb)
      from listings l join cities c on c.id=l.city_id join areas a on a.id=l.area_id
      where l.owner_id = v_owner
    ),
    'requests', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'listing_ref', l.ref, 'listing_title', l.title,
        'seeker_name', cr.seeker_name,
        'seeker_phone', case when cr.status <> 'new' then cr.seeker_phone else null end,
        'status', cr.status, 'created_at', cr.created_at
      ) order by cr.created_at desc), '[]'::jsonb)
      from contact_requests cr join listings l on l.id = cr.listing_id
      where l.owner_id = v_owner
    )
  );
end $function$;

create or replace function public.owner_dashboard(p_owner_id uuid, p_token uuid)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public', 'pg_temp'
as $function$
declare v_name text;
begin
  select first_name into v_name from profiles
   where id = p_owner_id and owner_token = p_token and role = 'owner';

  if v_name is null then
    raise exception 'رابط غير صالح';
  end if;

  return jsonb_build_object(
    'owner_name', v_name,
    'listings', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', l.id, 'ref', l.ref, 'title', l.title, 'status', l.status,
        'verification', l.verification, 'price', l.price, 'currency', l.currency,
        'city', c.name_ar, 'area', a.name_ar,
        'published_at', l.published_at, 'expires_at', l.expires_at,
        'days_left', case when l.expires_at is null then null
                          else l.expires_at::date - current_date end,
        'view_count', l.view_count, 'reject_reason', l.reject_reason,
        'confirm_token', l.confirm_token
      ) order by l.created_at desc), '[]'::jsonb)
      from listings l
      join cities c on c.id = l.city_id
      join areas  a on a.id = l.area_id
      where l.owner_id = p_owner_id
    ),
    'requests', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'listing_ref', l.ref, 'listing_title', l.title,
        'seeker_name', cr.seeker_name,
        'seeker_phone', case when cr.status <> 'new' then cr.seeker_phone else null end,
        'status', cr.status, 'created_at', cr.created_at,
        'id', cr.id
      ) order by cr.created_at desc), '[]'::jsonb)
      from contact_requests cr
      join listings l on l.id = cr.listing_id
      where l.owner_id = p_owner_id
    ),
    'fees', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'amount_due', f.amount_due,
        'status', f.status,
        'listing_ref', l.ref,
        'collected_at', f.collected_at
      ) order by f.created_at desc), '[]'::jsonb)
      from owner_fees f
      join listings l on l.id = f.listing_id
      where l.owner_id = p_owner_id
        and f.status in ('due', 'collected')
    )
  );
end $function$;

create or replace function public.my_seeker_dashboard()
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare v_uid uuid := auth.uid(); v_seeker uuid;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
  select id into v_seeker from profiles where account_uid = v_uid and role = 'seeker';
  if v_seeker is null then
    return jsonb_build_object('requests','[]'::jsonb,'saved','[]'::jsonb);
  end if;

  return jsonb_build_object(
    'requests', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'ref', r.ref, 'status', r.status, 'city', c.name_ar,
        'budget_max', r.budget_max, 'created_at', r.created_at,
        'expires_at', r.expires_at
      ) order by r.created_at desc), '[]'::jsonb)
      from seeker_requests r join cities c on c.id=r.city_id
      where r.seeker_id = v_seeker
    ),
    'saved', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'ref', v.ref, 'title', v.title, 'city', v.city, 'area', v.area,
        'price', v.price, 'currency', v.currency, 'status', case when v.id is null then 'removed' else 'active' end
      ) order by s.created_at desc), '[]'::jsonb)
      from saved_listings s
      left join v_listings_public v on v.id = s.listing_id
      where s.account_uid = v_uid
    )
  );
end $function$;
