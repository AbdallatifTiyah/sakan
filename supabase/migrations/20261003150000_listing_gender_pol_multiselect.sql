-- بند ٤ من طلب تعديلات التطبيق (مرحلة ٢): السماح لإعلان واحد يستهدف أكثر
-- من فئة بنفس الوقت ("عائلات" + "ذكور فقط" مثلاً) — قرار مؤكَّد مع أبواللطيف
-- (كان مؤجّلاً من مرحلة ١). `listings.gender_pol` يتحوّل من enum مفرد
-- لمصفوفة enum. ثلاث views تعتمد على العمود مباشرة (تحقّق حي
-- information_schema.view_column_usage قبل الكتابة): v_listings_public،
-- v_admin_listings، v_reverse_matches (الأخيرة عبر sakan_match_score، مش
-- عمود مُسنَد مباشرة). الثلاثة لازم تُحذف قبل تغيير نوع العمود وتُعاد صياغتها
-- بعده بنفس التعريف الحرفي (pg_get_viewdef حي، صفر تخمين).

-- ═══ ١) حذف الواجهات الثلاث المعتمدة على العمود (ترتيب لا يهم بينها) ═══
drop view if exists public.v_listings_public;
drop view if exists public.v_admin_listings;
drop view if exists public.v_reverse_matches;

-- ═══ ٢) sakan_match_score: الوسيط l_gender_pol يتحوّل لمصفوفة ═══
drop function if exists public.sakan_match_score(
  integer[], numeric, gender_type, listing_kind, date,
  integer, numeric, gender_policy, listing_kind, date
);

create function public.sakan_match_score(
  p_area_ids integer[], p_budget numeric, p_gender gender_type, p_kind listing_kind, p_move_in date,
  l_area integer, l_price numeric, l_gender_pol gender_policy[], l_kind listing_kind, l_available date
)
returns integer
language plpgsql
immutable
as $$
declare s int := 0;
begin
  -- المنطقة · 30
  if p_area_ids is null or array_length(p_area_ids,1) is null then s := s + 15;
  elsif l_area = any(p_area_ids) then s := s + 30;
  end if;

  -- الميزانية · 30  (تحت الميزانية = كامل، فوقها بـ15% = نصف)
  if l_price <= p_budget then s := s + 30;
  elsif l_price <= p_budget * 1.15 then s := s + 15;
  end if;

  -- نظام السكن · 25  (شرط إقصائي فعلياً) — 'mixed' بالمصفوفة كافٍ لقبول الكل
  if 'mixed' = any(l_gender_pol) then s := s + 15;
  elsif p_gender is null then s := s + 5;
  elsif (p_gender = 'female' and 'female' = any(l_gender_pol))
     or (p_gender = 'male'   and 'male'   = any(l_gender_pol)) then s := s + 25;
  else return 0;   -- تعارض كامل
  end if;

  -- النوع · 10
  if p_kind is null or p_kind = l_kind then s := s + 10; end if;

  -- تاريخ الدخول · 5
  if p_move_in is null or l_available is null or l_available <= p_move_in + 14 then
    s := s + 5;
  end if;

  return least(s, 100);
end $$;

revoke execute on function public.sakan_match_score(
  integer[], numeric, gender_type, listing_kind, date,
  integer, numeric, gender_policy[], listing_kind, date
) from public;
grant execute on function public.sakan_match_score(
  integer[], numeric, gender_type, listing_kind, date,
  integer, numeric, gender_policy[], listing_kind, date
) to authenticated, service_role;

-- ═══ ٣) تحويل العمود — drop default أولاً، تحويل، default جديد كمصفوفة،
-- قيد "لازم فئة واحدة على الأقل" (دفاعي، الفحص الودود الحقيقي بالدوال تحت) ═══
alter table listings alter column gender_pol drop default;
alter table listings alter column gender_pol type gender_policy[]
  using case when gender_pol is null then '{}'::gender_policy[] else array[gender_pol] end;
alter table listings alter column gender_pol set default array['mixed']::gender_policy[];
alter table listings add constraint listings_gender_pol_not_empty check (array_length(gender_pol,1) > 0);

-- ═══ ٤) إعادة صياغة الواجهات الثلاث — نفس pg_get_viewdef الحي بالحرف ═══
create view public.v_listings_public as
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
    COALESCE(p.verification_level::integer, 0) AS owner_level,
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
          WHERE r.listing_id = l.id AND r.is_published) AS review_count,
    ( SELECT round(avg((r.r_maintenance + r.r_quiet + r.r_accuracy + r.r_safety_night)::numeric / 4.0), 1) AS round
           FROM reviews r
          WHERE r.listing_id = l.id AND r.is_published) AS review_avg,
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
    l.rental_period,
    l.video_url,
    n.name_ar AS neighborhood,
    n.id AS neighborhood_id
   FROM listings l
     JOIN cities c ON c.id = l.city_id
     JOIN areas a ON a.id = l.area_id
     LEFT JOIN profiles p ON p.id = l.owner_id
     LEFT JOIN listing_safety s ON s.listing_id = l.id
     LEFT JOIN neighborhoods n ON n.id = l.neighborhood_id
  WHERE l.status = 'published'::listing_status;
alter view public.v_listings_public set (security_invoker = on);
grant select on public.v_listings_public to anon, authenticated, service_role;

create view public.v_admin_listings as
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
          WHERE cr.listing_id = l.id) AS contacts,
    ( SELECT count(*) AS count
           FROM contact_requests cr
          WHERE cr.listing_id = l.id AND cr.status = 'rented'::contact_status) AS rentals,
    ( SELECT count(*) AS count
           FROM reports r
          WHERE r.listing_id = l.id AND r.status = 'open'::report_status) AS open_reports,
    ( SELECT count(*) AS count
           FROM reviews rv
          WHERE rv.listing_id = l.id) AS reviews_count,
        CASE
            WHEN l.expires_at IS NULL THEN NULL::integer
            ELSE l.expires_at::date - CURRENT_DATE
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
    l.rental_period,
    l.video_url,
    l.rented_via_platform,
    l.outreach_status,
    l.neighborhood_id,
    n.name_ar AS neighborhood,
    l.deletion_requested_at
   FROM listings l
     JOIN cities c ON c.id = l.city_id
     JOIN areas a ON a.id = l.area_id
     LEFT JOIN profiles p ON p.id = l.owner_id
     LEFT JOIN listing_safety s ON s.listing_id = l.id
     LEFT JOIN neighborhoods n ON n.id = l.neighborhood_id;
alter view public.v_admin_listings set (security_invoker = on);
grant select on public.v_admin_listings to authenticated, service_role;

create view public.v_reverse_matches as
 SELECT l.id AS listing_id,
    l.ref AS listing_ref,
    r.id AS request_id,
    r.ref AS request_ref,
    p.first_name,
    p.occupation,
    p.verification_level,
    p.phone,
    r.budget_max,
    r.move_in_date,
    sakan_match_score(r.area_ids, r.budget_max, r.gender, r.kind_pref, r.move_in_date, l.area_id, l.price, l.gender_pol, l.kind, l.available_from) AS score
   FROM listings l
     JOIN seeker_requests r ON r.city_id = l.city_id AND r.status = 'published'::request_status
     LEFT JOIN profiles p ON p.id = r.seeker_id
  WHERE l.status = ANY (ARRAY['published'::listing_status, 'pending'::listing_status]);
alter view public.v_reverse_matches set (security_invoker = on);
grant select on public.v_reverse_matches to authenticated, service_role;

-- ═══ ٥) submit_listing: p_pol من text لـ text[] (فخّ التوقيعات — drop صريح) ═══
drop function if exists public.submit_listing(text,text,text,integer,numeric,text,text,boolean,date,text,text,text,text[],numeric,smallint,smallint,jsonb,text,boolean,boolean,boolean,text,text,text,integer);

create function public.submit_listing(p_name text, p_phone text, p_title text, p_area integer, p_price numeric, p_kind text, p_pol text[], p_furnished boolean, p_from date, p_occ text DEFAULT NULL::text, p_landmark text DEFAULT NULL::text, p_desc text DEFAULT NULL::text, p_features text[] DEFAULT '{}'::text[], p_deposit numeric DEFAULT NULL::numeric, p_rooms smallint DEFAULT NULL::smallint, p_min_stay smallint DEFAULT NULL::smallint, p_images jsonb DEFAULT '[]'::jsonb, p_currency text DEFAULT 'ILS'::text, p_bills_water boolean DEFAULT false, p_bills_electricity boolean DEFAULT false, p_bills_internet boolean DEFAULT false, p_promo_code text DEFAULT NULL::text, p_rental_period text DEFAULT 'monthly'::text, p_video_url text DEFAULT NULL::text, p_neighborhood integer DEFAULT NULL::integer)
returns text
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_owner uuid; v_ref text; v_city int; v_images jsonb; v_bills_included boolean;
  v_promo text; pc record; v_listing_id uuid; v_pol gender_policy[];
begin
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' then
    raise exception 'الاسم والرقم مطلوبان';
  end if;

  if p_pol is null or array_length(p_pol,1) is null then
    raise exception 'اختر فئة واحدة على الأقل لسياسة السكن';
  end if;
  v_pol := p_pol::gender_policy[];

  select city_id into v_city from areas where id = p_area and is_active;
  if v_city is null then raise exception 'منطقة غير صحيحة'; end if;

  if p_neighborhood is not null and not exists (
    select 1 from neighborhoods where id = p_neighborhood and area_id = p_area and is_active
  ) then
    raise exception 'حي غير صحيح';
  end if;

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
      select v from jsonb_array_elements_text(coalesce(p_images, '[]'::jsonb)) v limit 10
    ) t;

  insert into listings (owner_id, city_id, area_id, neighborhood_id, title, description, price, currency,
                        kind, gender_pol, furnished, available_from,
                        occupants_note, landmark, features, deposit,
                        bills_included, bills_water, bills_electricity, bills_internet,
                        rooms_total, min_stay_months, images, promo_code, rental_period, video_url,
                        ref)
  values (v_owner, v_city, p_area, p_neighborhood, trim(p_title), nullif(trim(coalesce(p_desc,'')),''),
          p_price, coalesce(nullif(p_currency,''),'ILS')::currency_code,
          p_kind::listing_kind, v_pol, coalesce(p_furnished,true),
          p_from, nullif(trim(coalesce(p_occ,'')),''), nullif(trim(coalesce(p_landmark,'')),''),
          coalesce(p_features,'{}'), p_deposit,
          v_bills_included, coalesce(p_bills_water,false), coalesce(p_bills_electricity,false), coalesce(p_bills_internet,false),
          p_rooms, p_min_stay, v_images, v_promo, coalesce(nullif(p_rental_period,''),'monthly')::rental_period,
          nullif(trim(coalesce(p_video_url,'')),''),
          'PENDING-' || gen_random_uuid()::text)
  returning id into v_listing_id;

  insert into events (event_type, source, actor_role, meta)
  values ('listing_created','user','owner', jsonb_build_object('listing_id', v_listing_id));

  update listings set ref = 'SK-' || nextval('listing_ref_seq')::text
  where id = v_listing_id
  returning ref into v_ref;

  return v_ref;
end
$$;

revoke all on function public.submit_listing(text,text,text,integer,numeric,text,text[],boolean,date,text,text,text,text[],numeric,smallint,smallint,jsonb,text,boolean,boolean,boolean,text,text,text,integer) from public;
grant execute on function public.submit_listing(text,text,text,integer,numeric,text,text[],boolean,date,text,text,text,text[],numeric,smallint,smallint,jsonb,text,boolean,boolean,boolean,text,text,text,integer) to anon, authenticated, service_role;

-- ═══ ٦) admin_listing_update: p_pol من text لـ text[] (نفس الفخّ) ═══
drop function if exists public.admin_listing_update(uuid,text,text,numeric,text,numeric,text,text,boolean,boolean,boolean,boolean,smallint,smallint,date,text,text,text[],integer,text,integer);

create function public.admin_listing_update(p_id uuid, p_title text, p_description text, p_price numeric, p_currency text, p_deposit numeric, p_kind text, p_pol text[], p_furnished boolean, p_bills_water boolean, p_bills_electricity boolean, p_bills_internet boolean, p_rooms smallint, p_min_stay smallint, p_from date, p_landmark text, p_occ text, p_features text[], p_area integer, p_rental_period text DEFAULT 'monthly'::text, p_neighborhood integer DEFAULT NULL::integer)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare v_city int; v_ref text;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), 'admin'), true);

  if p_pol is null or array_length(p_pol,1) is null then
    raise exception 'اختر فئة واحدة على الأقل لسياسة السكن';
  end if;

  select city_id into v_city from areas where id = p_area and is_active;
  if v_city is null then raise exception 'منطقة غير صحيحة'; end if;

  if p_neighborhood is not null and not exists (
    select 1 from neighborhoods where id = p_neighborhood and area_id = p_area
  ) then
    raise exception 'حي غير صحيح';
  end if;

  update listings set
    title = trim(p_title),
    description = nullif(trim(coalesce(p_description,'')),''),
    price = p_price,
    currency = coalesce(nullif(p_currency,''),'ILS')::currency_code,
    deposit = p_deposit,
    kind = p_kind::listing_kind,
    gender_pol = p_pol::gender_policy[],
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
    neighborhood_id = p_neighborhood,
    city_id = v_city,
    rental_period = coalesce(nullif(p_rental_period,''),'monthly')::rental_period,
    updated_at = now()
  where id = p_id
  returning ref into v_ref;

  if v_ref is null then raise exception 'إعلان غير موجود'; end if;

  insert into admin_actions(actor, action, subject_type, subject_id, subject_ref, to_state)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'listing_data_update', 'listing', p_id, v_ref, 'edited');
end $$;

revoke all on function public.admin_listing_update(uuid,text,text,numeric,text,numeric,text,text[],boolean,boolean,boolean,boolean,smallint,smallint,date,text,text,text[],integer,text,integer) from public;
grant execute on function public.admin_listing_update(uuid,text,text,numeric,text,numeric,text,text[],boolean,boolean,boolean,boolean,smallint,smallint,date,text,text,text[],integer,text,integer) to authenticated, service_role;

notify pgrst, 'reload schema';
