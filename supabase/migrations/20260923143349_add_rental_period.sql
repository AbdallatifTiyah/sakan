-- نوع مدة الإيجار: شهري (الافتراضي التاريخي) / أسبوعي / يومي
create type rental_period as enum ('monthly','weekly','daily');

alter table listings add column rental_period rental_period not null default 'monthly';
alter table seeker_requests add column rental_period_pref rental_period null;

-- ═══ submit_listing: إضافة p_rental_period (تغيير التوقيع = دالة جديدة، لازم drop صريح) ═══
drop function if exists public.submit_listing(text, text, text, integer, numeric, text, text, boolean, date, text, text, text, text[], numeric, smallint, smallint, jsonb, text, boolean, boolean, boolean, text);

create or replace function public.submit_listing(p_name text, p_phone text, p_title text, p_area integer, p_price numeric, p_kind text, p_pol text, p_furnished boolean, p_from date, p_occ text default NULL::text, p_landmark text default NULL::text, p_desc text default NULL::text, p_features text[] default '{}'::text[], p_deposit numeric default NULL::numeric, p_rooms smallint default NULL::smallint, p_min_stay smallint default NULL::smallint, p_images jsonb default '[]'::jsonb, p_currency text default 'ILS'::text, p_bills_water boolean default false, p_bills_electricity boolean default false, p_bills_internet boolean default false, p_promo_code text default NULL::text, p_rental_period text default 'monthly'::text)
 returns text
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_owner uuid; v_ref text; v_city int; v_images jsonb; v_bills_included boolean;
  v_promo text; pc record;
begin
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' then
    raise exception 'الاسم والرقم مطلوبان';
  end if;

  select city_id into v_city from areas where id = p_area and is_active;
  if v_city is null then raise exception 'منطقة غير صحيحة'; end if;

  v_bills_included := coalesce(p_bills_water,false) and coalesce(p_bills_electricity,false) and coalesce(p_bills_internet,false);

  v_promo := nullif(upper(trim(p_promo_code)), '');
  if v_promo is not null then
    select * into pc from promo_codes where code = v_promo;
    if not found then
      raise exception 'كود الخصم غير موجود';
    end if;
    if not pc.is_active then
      raise exception 'كود الخصم غير مفعّل';
    end if;
    if pc.valid_until is not null and pc.valid_until < current_date then
      raise exception 'كود الخصم منتهي الصلاحية';
    end if;
    if pc.max_uses is not null and pc.used_count >= pc.max_uses then
      raise exception 'كود الخصم وصل الحد الأقصى للاستخدام';
    end if;
  end if;

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
                        rooms_total, min_stay_months, images, promo_code, rental_period)
  values (v_owner, v_city, p_area, trim(p_title), nullif(trim(coalesce(p_desc,'')),''),
          p_price, coalesce(nullif(p_currency,''),'ILS')::currency_code,
          p_kind::listing_kind, p_pol::gender_policy, coalesce(p_furnished,true),
          p_from, nullif(trim(coalesce(p_occ,'')),''), nullif(trim(coalesce(p_landmark,'')),''),
          coalesce(p_features,'{}'), p_deposit,
          v_bills_included, coalesce(p_bills_water,false), coalesce(p_bills_electricity,false), coalesce(p_bills_internet,false),
          p_rooms, p_min_stay, v_images, v_promo, coalesce(nullif(p_rental_period,''),'monthly')::rental_period)
  returning ref into v_ref;

  insert into events (event_type, source, actor_role, meta)
  values ('listing_created','user','owner', jsonb_build_object('ref', v_ref));

  return v_ref;
end
$function$;

revoke all on function public.submit_listing(text, text, text, integer, numeric, text, text, boolean, date, text, text, text, text[], numeric, smallint, smallint, jsonb, text, boolean, boolean, boolean, text, text) from public;
grant execute on function public.submit_listing(text, text, text, integer, numeric, text, text, boolean, date, text, text, text, text[], numeric, smallint, smallint, jsonb, text, boolean, boolean, boolean, text, text) to anon, authenticated, service_role;

-- ═══ submit_request: إضافة p_rental_period_pref ═══
drop function if exists public.submit_request(text, text, text, text, numeric, integer[], date, text[], text, integer, text, boolean, smallint, boolean);

create or replace function public.submit_request(p_name text, p_phone text, p_gender text, p_occupation text, p_budget numeric, p_areas integer[], p_move_in date, p_tags text[] default '{}'::text[], p_note text default NULL::text, p_city integer default NULL::integer, p_kind text default NULL::text, p_furnished boolean default NULL::boolean, p_min_stay smallint default NULL::smallint, p_smoker boolean default NULL::boolean, p_rental_period_pref text default NULL::text)
 returns text
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare v_seeker uuid; v_ref text; v_city int;
begin
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' then
    raise exception 'الاسم والرقم مطلوبان';
  end if;

  v_city := p_city;
  if v_city is null then
    select min(city_id) into v_city from areas where id = any(coalesce(p_areas,'{}'));
  end if;
  if v_city is null then raise exception 'اختر المدينة'; end if;
  if not exists (select 1 from cities where id = v_city and is_active) then
    raise exception 'مدينة غير صحيحة';
  end if;

  select id into v_seeker from profiles
   where phone = trim(p_phone) and role = 'seeker' limit 1;

  if v_seeker is null then
    insert into profiles (role, first_name, phone, gender, occupation, city_id)
    values ('seeker', trim(p_name), trim(p_phone),
            nullif(p_gender,'')::gender_type,
            coalesce(nullif(p_occupation,''),'other')::occupation_type, v_city)
    returning id into v_seeker;
  end if;

  insert into seeker_requests (seeker_id, city_id, area_ids, budget_max, gender,
                               move_in_date, lifestyle_tags, note,
                               kind_pref, furnished_pref, min_stay_months, smoker, rental_period_pref)
  values (v_seeker, v_city, coalesce(p_areas,'{}'), p_budget,
          nullif(p_gender,'')::gender_type, p_move_in,
          coalesce(p_tags,'{}'), nullif(trim(coalesce(p_note,'')),''),
          nullif(p_kind,'')::listing_kind, p_furnished, p_min_stay, p_smoker,
          nullif(p_rental_period_pref,'')::rental_period)
  returning ref into v_ref;

  insert into events (event_type, source, actor_role, meta)
  values ('request_created','user','seeker', jsonb_build_object('ref', v_ref));

  return v_ref;
end $function$;

revoke all on function public.submit_request(text, text, text, text, numeric, integer[], date, text[], text, integer, text, boolean, smallint, boolean, text) from public;
grant execute on function public.submit_request(text, text, text, text, numeric, integer[], date, text[], text, integer, text, boolean, smallint, boolean, text) to anon, authenticated, service_role;

-- ═══ admin_listing_update: إضافة p_rental_period ═══
drop function if exists public.admin_listing_update(uuid, text, text, numeric, text, numeric, text, text, boolean, boolean, boolean, boolean, smallint, smallint, date, text, text, text[], integer);

create or replace function public.admin_listing_update(p_id uuid, p_title text, p_description text, p_price numeric, p_currency text, p_deposit numeric, p_kind text, p_pol text, p_furnished boolean, p_bills_water boolean, p_bills_electricity boolean, p_bills_internet boolean, p_rooms smallint, p_min_stay smallint, p_from date, p_landmark text, p_occ text, p_features text[], p_area integer, p_rental_period text default 'monthly'::text)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare v_city int; v_ref text;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), 'admin'), true);

  select city_id into v_city from areas where id = p_area and is_active;
  if v_city is null then raise exception 'منطقة غير صحيحة'; end if;

  update listings set
    title = trim(p_title),
    description = nullif(trim(coalesce(p_description,'')),''),
    price = p_price,
    currency = coalesce(nullif(p_currency,''),'ILS')::currency_code,
    deposit = p_deposit,
    kind = p_kind::listing_kind,
    gender_pol = p_pol::gender_policy,
    furnished = coalesce(p_furnished,true),
    bills_water = coalesce(p_bills_water,false),
    bills_electricity = coalesce(p_bills_electricity,false),
    bills_internet = coalesce(p_bills_internet,false),
    bills_included = coalesce(p_bills_water,false) and coalesce(p_bills_electricity,false) and coalesce(p_bills_internet,false),
    rooms_total = p_rooms,
    min_stay_months = p_min_stay,
    available_from = p_from,
    landmark = nullif(trim(coalesce(p_landmark,'')),''),
    occupants_note = nullif(trim(coalesce(p_occ,'')),''),
    features = coalesce(p_features,'{}'),
    area_id = p_area,
    city_id = v_city,
    rental_period = coalesce(nullif(p_rental_period,''),'monthly')::rental_period,
    updated_at = now()
  where id = p_id
  returning ref into v_ref;

  if v_ref is null then raise exception 'إعلان غير موجود'; end if;

  insert into admin_actions(actor, action, subject_type, subject_id, subject_ref, to_state)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'listing_data_update', 'listing', p_id, v_ref, 'edited');
end $function$;

revoke all on function public.admin_listing_update(uuid, text, text, numeric, text, numeric, text, text, boolean, boolean, boolean, boolean, smallint, smallint, date, text, text, text[], integer, text) from public;
grant execute on function public.admin_listing_update(uuid, text, text, numeric, text, numeric, text, text, boolean, boolean, boolean, boolean, smallint, smallint, date, text, text, text[], integer, text) to authenticated, service_role;

-- ═══ admin_request_update: إضافة p_rental_period_pref ═══
drop function if exists public.admin_request_update(uuid, numeric, text, text, boolean, date, smallint, boolean, text[], text, integer, integer[]);

create or replace function public.admin_request_update(p_id uuid, p_budget numeric, p_gender text, p_kind text, p_furnished boolean, p_move_in date, p_min_stay smallint, p_smoker boolean, p_tags text[], p_note text, p_city integer, p_areas integer[], p_rental_period_pref text default NULL::text)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), 'admin'), true);

  if not exists (select 1 from cities where id = p_city and is_active) then
    raise exception 'مدينة غير صحيحة';
  end if;

  update seeker_requests set
    budget_max = p_budget,
    gender = nullif(p_gender,'')::gender_type,
    kind_pref = nullif(p_kind,'')::listing_kind,
    furnished_pref = p_furnished,
    move_in_date = p_move_in,
    min_stay_months = p_min_stay,
    smoker = p_smoker,
    lifestyle_tags = coalesce(p_tags,'{}'),
    note = nullif(trim(coalesce(p_note,'')),''),
    city_id = p_city,
    area_ids = coalesce(p_areas,'{}'),
    rental_period_pref = nullif(p_rental_period_pref,'')::rental_period
  where id = p_id;

  if not found then raise exception 'طلب غير موجود'; end if;

  insert into admin_actions(actor, action, subject_type, subject_id, to_state)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'request_data_update', 'request', p_id, 'edited');
end $function$;

revoke all on function public.admin_request_update(uuid, numeric, text, text, boolean, date, smallint, boolean, text[], text, integer, integer[], text) from public;
grant execute on function public.admin_request_update(uuid, numeric, text, text, boolean, date, smallint, boolean, text[], text, integer, integer[], text) to authenticated, service_role;

-- ═══ الواجهات: إضافة العمود بذيل القائمة ═══
create or replace view public.v_listings_public as
 SELECT l.id,
    l.ref,
    l.title,
    l.description,
    c.name_ar AS city,
    c.slug AS city_slug,
    a.name_ar AS area,
    a.id AS area_id,
    l.landmark,
    l.kind,
    l.price,
    l.bills_included,
    l.deposit,
    l.gender_pol,
    l.furnished,
    l.rooms_total,
    l.occupants_now,
    l.occupants_note,
    l.available_from,
    l.min_stay_months,
    l.images,
    l.verification,
    l.published_at,
    l.expires_at,
    l.view_count,
    COALESCE((p.verification_level)::integer, 0) AS owner_level,
    s.visit_date,
    s.door_lock,
    s.no_indoor_cameras,
    s.room_exists,
    s.photos_match,
    s.occupants_verified,
    s.exterior_lighting,
    s.gas_detector,
    ( SELECT count(*) AS count
           FROM reviews r
          WHERE ((r.listing_id = l.id) AND r.is_published)) AS review_count,
    ( SELECT round(avg((((((r.r_maintenance + r.r_quiet) + r.r_accuracy) + r.r_safety_night))::numeric / 4.0)), 1) AS round
           FROM reviews r
          WHERE ((r.listing_id = l.id) AND r.is_published)) AS review_avg,
    c.id AS city_id,
    s.private_bathroom,
    s.kitchen_access,
    s.heating,
    s.internet,
    s.emergency_exit,
    s.street_access,
    l.features,
    l.video_verified_at,
    l.currency,
    l.bills_water,
    l.bills_electricity,
    l.bills_internet,
    l.rental_period
   FROM ((((listings l
     JOIN cities c ON ((c.id = l.city_id)))
     JOIN areas a ON ((a.id = l.area_id)))
     LEFT JOIN profiles p ON ((p.id = l.owner_id)))
     LEFT JOIN listing_safety s ON ((s.listing_id = l.id)))
  WHERE (l.status = 'published'::listing_status);

create or replace view public.v_requests_public as
 SELECT r.id,
    r.ref,
    r.budget_max,
    r.gender,
    r.kind_pref,
    r.furnished_pref,
    r.move_in_date,
    r.min_stay_months,
    r.smoker,
    r.lifestyle_tags,
    r.note,
    r.area_ids,
    c.name_ar AS city,
    r.created_at,
    p.occupation,
    COALESCE((p.verification_level)::integer, 0) AS seeker_level,
    c.id AS city_id,
    r.rental_period_pref
   FROM ((seeker_requests r
     JOIN cities c ON ((c.id = r.city_id)))
     LEFT JOIN profiles p ON ((p.id = r.seeker_id)))
  WHERE (r.status = 'published'::request_status);

create or replace view public.v_admin_listings as
 SELECT l.id,
    l.ref,
    l.title,
    l.description,
    l.kind,
    l.status,
    l.verification,
    l.price,
    l.deposit,
    l.bills_included,
    l.gender_pol,
    l.furnished,
    l.rooms_total,
    l.occupants_now,
    l.occupants_note,
    l.available_from,
    l.min_stay_months,
    l.landmark,
    l.exact_address,
    l.images,
    l.reject_reason,
    l.published_at,
    l.expires_at,
    l.last_confirmed_at,
    l.rented_at,
    l.created_at,
    l.updated_at,
    l.view_count,
    l.confirm_token,
    l.city_id,
    c.name_ar AS city,
    l.area_id,
    a.name_ar AS area,
    p.id AS owner_id,
    p.first_name AS owner_name,
    p.phone AS owner_phone,
    p.verification_level AS owner_level,
    p.is_blocked AS owner_blocked,
    s.visit_date,
    s.room_exists,
    s.photos_match,
    s.door_lock,
    s.no_indoor_cameras,
    s.occupants_verified,
    s.exterior_lighting,
    s.gas_detector,
    s.notes AS safety_notes,
    ( SELECT count(*) AS count
           FROM contact_requests cr
          WHERE (cr.listing_id = l.id)) AS contacts,
    ( SELECT count(*) AS count
           FROM contact_requests cr
          WHERE ((cr.listing_id = l.id) AND (cr.status = 'rented'::contact_status))) AS rentals,
    ( SELECT count(*) AS count
           FROM reports r
          WHERE ((r.listing_id = l.id) AND (r.status = 'open'::report_status))) AS open_reports,
    ( SELECT count(*) AS count
           FROM reviews rv
          WHERE (rv.listing_id = l.id)) AS reviews_count,
        CASE
            WHEN (l.expires_at IS NULL) THEN NULL::integer
            ELSE ((l.expires_at)::date - CURRENT_DATE)
        END AS days_left,
    s.private_bathroom,
    s.kitchen_access,
    s.heating,
    s.internet,
    s.emergency_exit,
    s.street_access,
    s.owner_met,
    l.features,
    l.review_token,
    l.video_verified_at,
    l.currency,
    l.bills_water,
    l.bills_electricity,
    l.bills_internet,
    l.rental_period
   FROM ((((listings l
     JOIN cities c ON ((c.id = l.city_id)))
     JOIN areas a ON ((a.id = l.area_id)))
     LEFT JOIN profiles p ON ((p.id = l.owner_id)))
     LEFT JOIN listing_safety s ON ((s.listing_id = l.id)));
alter view public.v_admin_listings set (security_invoker = on);

create or replace view public.v_admin_requests as
 SELECT r.id,
    r.ref,
    r.status,
    r.created_at,
    r.expires_at,
    c.id AS city_id,
    c.name_ar AS city,
    r.area_ids,
    ( SELECT COALESCE(string_agg(a.name_ar, '، '::text ORDER BY a.sort_order), '—'::text) AS "coalesce"
           FROM areas a
          WHERE (a.id = ANY (r.area_ids))) AS areas_ar,
    r.budget_max,
    r.gender,
    r.kind_pref,
    r.furnished_pref,
    r.move_in_date,
    r.min_stay_months,
    r.smoker,
    r.lifestyle_tags,
    r.note,
    p.id AS seeker_id,
    p.first_name,
    p.full_name,
    p.phone,
    p.occupation,
    p.org_name,
    COALESCE((p.verification_level)::integer, 0) AS seeker_level,
    p.is_blocked,
    r.rental_period_pref
   FROM ((seeker_requests r
     JOIN cities c ON ((c.id = r.city_id)))
     LEFT JOIN profiles p ON ((p.id = r.seeker_id)));
alter view public.v_admin_requests set (security_invoker = on);
