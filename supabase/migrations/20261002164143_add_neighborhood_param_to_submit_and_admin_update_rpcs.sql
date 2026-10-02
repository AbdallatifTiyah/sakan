-- submit_listing: إضافة p_neighborhood اختياري
drop function public.submit_listing(text,text,text,integer,numeric,text,text,boolean,date,text,text,text,text[],numeric,smallint,smallint,jsonb,text,boolean,boolean,boolean,text,text,text);

create function public.submit_listing(p_name text, p_phone text, p_title text, p_area integer, p_price numeric, p_kind text, p_pol text, p_furnished boolean, p_from date, p_occ text DEFAULT NULL::text, p_landmark text DEFAULT NULL::text, p_desc text DEFAULT NULL::text, p_features text[] DEFAULT '{}'::text[], p_deposit numeric DEFAULT NULL::numeric, p_rooms smallint DEFAULT NULL::smallint, p_min_stay smallint DEFAULT NULL::smallint, p_images jsonb DEFAULT '[]'::jsonb, p_currency text DEFAULT 'ILS'::text, p_bills_water boolean DEFAULT false, p_bills_electricity boolean DEFAULT false, p_bills_internet boolean DEFAULT false, p_promo_code text DEFAULT NULL::text, p_rental_period text DEFAULT 'monthly'::text, p_video_url text DEFAULT NULL::text, p_neighborhood integer DEFAULT NULL::integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_owner uuid; v_ref text; v_city int; v_images jsonb; v_bills_included boolean;
  v_promo text; pc record; v_listing_id uuid;
begin
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' then
    raise exception 'الاسم والرقم مطلوبان';
  end if;

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

  -- ref يتسجّل بقيمة مؤقتة فريدة هون عمداً (تتجاوز trg_listing_ref لأنها مش null)،
  -- وتتحول لرقم SK- الفعلي بآخر سطر بالدالة — بعد ما نضمن نجاح كل شي غيره.
  insert into listings (owner_id, city_id, area_id, neighborhood_id, title, description, price, currency,
                        kind, gender_pol, furnished, available_from,
                        occupants_note, landmark, features, deposit,
                        bills_included, bills_water, bills_electricity, bills_internet,
                        rooms_total, min_stay_months, images, promo_code, rental_period, video_url,
                        ref)
  values (v_owner, v_city, p_area, p_neighborhood, trim(p_title), nullif(trim(coalesce(p_desc,'')),''),
          p_price, coalesce(nullif(p_currency,''),'ILS')::currency_code,
          p_kind::listing_kind, p_pol::gender_policy, coalesce(p_furnished,true),
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
$function$;

revoke all on function public.submit_listing(text,text,text,integer,numeric,text,text,boolean,date,text,text,text,text[],numeric,smallint,smallint,jsonb,text,boolean,boolean,boolean,text,text,text,integer) from public;
grant execute on function public.submit_listing(text,text,text,integer,numeric,text,text,boolean,date,text,text,text,text[],numeric,smallint,smallint,jsonb,text,boolean,boolean,boolean,text,text,text,integer) to anon, authenticated, service_role;

-- submit_request: إضافة p_neighborhoods integer[] اختياري
drop function public.submit_request(text,text,text,text,numeric,integer[],date,text[],text,integer,text,boolean,smallint,boolean,text,smallint);

create function public.submit_request(p_name text, p_phone text, p_gender text, p_occupation text, p_budget numeric, p_areas integer[], p_move_in date, p_tags text[] DEFAULT '{}'::text[], p_note text DEFAULT NULL::text, p_city integer DEFAULT NULL::integer, p_kind text DEFAULT NULL::text, p_furnished boolean DEFAULT NULL::boolean, p_min_stay smallint DEFAULT NULL::smallint, p_smoker boolean DEFAULT NULL::boolean, p_rental_period_pref text DEFAULT NULL::text, p_rooms_pref smallint DEFAULT NULL::smallint, p_neighborhoods integer[] DEFAULT '{}'::integer[])
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  insert into seeker_requests (seeker_id, city_id, area_ids, neighborhood_ids, budget_max, gender,
                               move_in_date, lifestyle_tags, note,
                               kind_pref, furnished_pref, min_stay_months, smoker, rental_period_pref, rooms_pref)
  values (v_seeker, v_city, coalesce(p_areas,'{}'), coalesce(p_neighborhoods,'{}'), p_budget,
          nullif(p_gender,'')::gender_type, p_move_in,
          coalesce(p_tags,'{}'), nullif(trim(coalesce(p_note,'')),''),
          nullif(p_kind,'')::listing_kind, p_furnished, p_min_stay, p_smoker,
          nullif(p_rental_period_pref,'')::rental_period, p_rooms_pref)
  returning ref into v_ref;

  insert into events (event_type, source, actor_role, meta)
  values ('request_created','user','seeker', jsonb_build_object('ref', v_ref));

  return v_ref;
end $function$;

revoke all on function public.submit_request(text,text,text,text,numeric,integer[],date,text[],text,integer,text,boolean,smallint,boolean,text,smallint,integer[]) from public;
grant execute on function public.submit_request(text,text,text,text,numeric,integer[],date,text[],text,integer,text,boolean,smallint,boolean,text,smallint,integer[]) to anon, authenticated, service_role;

-- admin_listing_update: إضافة p_neighborhood اختياري
drop function public.admin_listing_update(uuid,text,text,numeric,text,numeric,text,text,boolean,boolean,boolean,boolean,smallint,smallint,date,text,text,text[],integer,text);

create function public.admin_listing_update(p_id uuid, p_title text, p_description text, p_price numeric, p_currency text, p_deposit numeric, p_kind text, p_pol text, p_furnished boolean, p_bills_water boolean, p_bills_electricity boolean, p_bills_internet boolean, p_rooms smallint, p_min_stay smallint, p_from date, p_landmark text, p_occ text, p_features text[], p_area integer, p_rental_period text DEFAULT 'monthly'::text, p_neighborhood integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_city int; v_ref text;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), 'admin'), true);

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
    neighborhood_id = p_neighborhood,
    city_id = v_city,
    rental_period = coalesce(nullif(p_rental_period,''),'monthly')::rental_period,
    updated_at = now()
  where id = p_id
  returning ref into v_ref;

  if v_ref is null then raise exception 'إعلان غير موجود'; end if;

  insert into admin_actions(actor, action, subject_type, subject_id, subject_ref, to_state)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'listing_data_update', 'listing', p_id, v_ref, 'edited');
end $function$;

revoke all on function public.admin_listing_update(uuid,text,text,numeric,text,numeric,text,text,boolean,boolean,boolean,boolean,smallint,smallint,date,text,text,text[],integer,text,integer) from public;
grant execute on function public.admin_listing_update(uuid,text,text,numeric,text,numeric,text,text,boolean,boolean,boolean,boolean,smallint,smallint,date,text,text,text[],integer,text,integer) to authenticated, service_role;

-- admin_request_update: إضافة p_neighborhoods integer[] اختياري
drop function public.admin_request_update(uuid,numeric,text,text,boolean,date,smallint,boolean,text[],text,integer,integer[],text,smallint);

create function public.admin_request_update(p_id uuid, p_budget numeric, p_gender text, p_kind text, p_furnished boolean, p_move_in date, p_min_stay smallint, p_smoker boolean, p_tags text[], p_note text, p_city integer, p_areas integer[], p_rental_period_pref text DEFAULT NULL::text, p_rooms_pref smallint DEFAULT NULL::smallint, p_neighborhoods integer[] DEFAULT '{}'::integer[])
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    neighborhood_ids = coalesce(p_neighborhoods,'{}'),
    rental_period_pref = nullif(p_rental_period_pref,'')::rental_period,
    rooms_pref = p_rooms_pref
  where id = p_id;

  if not found then raise exception 'طلب غير موجود'; end if;

  insert into admin_actions(actor, action, subject_type, subject_id, to_state)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'request_data_update', 'request', p_id, 'edited');
end $function$;

revoke all on function public.admin_request_update(uuid,numeric,text,text,boolean,date,smallint,boolean,text[],text,integer,integer[],text,smallint,integer[]) from public;
grant execute on function public.admin_request_update(uuid,numeric,text,text,boolean,date,smallint,boolean,text[],text,integer,integer[],text,smallint,integer[]) to authenticated, service_role;

-- دالة جديدة: إدارة الأحياء (مرايا admin_area_save، بدون p_actor عمداً — قاعدة ١٦)
create function public.admin_neighborhood_save(p_id integer, p_area integer, p_name text, p_slug text, p_sort integer DEFAULT 100, p_active boolean DEFAULT true, p_name_en text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id int;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  if p_id is null then
    insert into neighborhoods(area_id, name_ar, slug, sort_order, is_active, name_en)
    values (p_area, p_name, p_slug, coalesce(p_sort,100), p_active, nullif(btrim(p_name_en),''))
    returning id into v_id;
  else
    update neighborhoods set area_id = p_area, name_ar = p_name, slug = p_slug,
                     sort_order = coalesce(p_sort,100), is_active = p_active,
                     name_en = nullif(btrim(p_name_en),'')
     where id = p_id returning id into v_id;
  end if;
  insert into admin_actions(actor, action, subject_type, subject_ref, to_state)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'neighborhood_save', 'neighborhood', p_name, p_active::text);
  return v_id;
end $function$;

revoke all on function public.admin_neighborhood_save(integer,integer,text,text,integer,boolean,text) from public;
grant execute on function public.admin_neighborhood_save(integer,integer,text,text,integer,boolean,text) to authenticated, service_role;
