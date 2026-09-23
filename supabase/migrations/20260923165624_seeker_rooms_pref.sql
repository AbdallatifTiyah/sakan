-- سكنّا: عدد الغرف المفضّل عند الباحث (يظهر بالفورم فقط لو اختار "شقة")

alter table seeker_requests add column rooms_pref smallint null;

-- ═══ submit_request: إضافة p_rooms_pref ═══
drop function if exists public.submit_request(text, text, text, text, numeric, integer[], date, text[], text, integer, text, boolean, smallint, boolean, text);

create or replace function public.submit_request(p_name text, p_phone text, p_gender text, p_occupation text, p_budget numeric, p_areas integer[], p_move_in date, p_tags text[] default '{}'::text[], p_note text default NULL::text, p_city integer default NULL::integer, p_kind text default NULL::text, p_furnished boolean default NULL::boolean, p_min_stay smallint default NULL::smallint, p_smoker boolean default NULL::boolean, p_rental_period_pref text default NULL::text, p_rooms_pref smallint default NULL::smallint)
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
                               kind_pref, furnished_pref, min_stay_months, smoker, rental_period_pref, rooms_pref)
  values (v_seeker, v_city, coalesce(p_areas,'{}'), p_budget,
          nullif(p_gender,'')::gender_type, p_move_in,
          coalesce(p_tags,'{}'), nullif(trim(coalesce(p_note,'')),''),
          nullif(p_kind,'')::listing_kind, p_furnished, p_min_stay, p_smoker,
          nullif(p_rental_period_pref,'')::rental_period, p_rooms_pref)
  returning ref into v_ref;

  insert into events (event_type, source, actor_role, meta)
  values ('request_created','user','seeker', jsonb_build_object('ref', v_ref));

  return v_ref;
end $function$;

revoke all on function public.submit_request(text, text, text, text, numeric, integer[], date, text[], text, integer, text, boolean, smallint, boolean, text, smallint) from public;
grant execute on function public.submit_request(text, text, text, text, numeric, integer[], date, text[], text, integer, text, boolean, smallint, boolean, text, smallint) to anon, authenticated, service_role;

-- ═══ admin_request_update: إضافة p_rooms_pref ═══
drop function if exists public.admin_request_update(uuid, numeric, text, text, boolean, date, smallint, boolean, text[], text, integer, integer[], text);

create or replace function public.admin_request_update(p_id uuid, p_budget numeric, p_gender text, p_kind text, p_furnished boolean, p_move_in date, p_min_stay smallint, p_smoker boolean, p_tags text[], p_note text, p_city integer, p_areas integer[], p_rental_period_pref text default NULL::text, p_rooms_pref smallint default NULL::smallint)
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
    rental_period_pref = nullif(p_rental_period_pref,'')::rental_period,
    rooms_pref = p_rooms_pref
  where id = p_id;

  if not found then raise exception 'طلب غير موجود'; end if;

  insert into admin_actions(actor, action, subject_type, subject_id, to_state)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'request_data_update', 'request', p_id, 'edited');
end $function$;

revoke all on function public.admin_request_update(uuid, numeric, text, text, boolean, date, smallint, boolean, text[], text, integer, integer[], text, smallint) from public;
grant execute on function public.admin_request_update(uuid, numeric, text, text, boolean, date, smallint, boolean, text[], text, integer, integer[], text, smallint) to authenticated, service_role;

-- ═══ الواجهتان: إضافة rooms_pref بذيل القائمة ═══
create or replace view public.v_requests_public as
 select r.id,
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
    c.name_ar as city,
    r.created_at,
    p.occupation,
    coalesce((p.verification_level)::integer, 0) as seeker_level,
    c.id as city_id,
    r.rental_period_pref,
    r.rooms_pref
   from ((seeker_requests r
     join cities c on ((c.id = r.city_id)))
     left join profiles p on ((p.id = r.seeker_id)))
  where (r.status = 'published'::request_status);

create or replace view public.v_admin_requests as
 select r.id,
    r.ref,
    r.status,
    r.created_at,
    r.expires_at,
    c.id as city_id,
    c.name_ar as city,
    r.area_ids,
    ( select coalesce(string_agg(a.name_ar, '، '::text order by a.sort_order), '—'::text) as "coalesce"
           from areas a
          where (a.id = any (r.area_ids))) as areas_ar,
    r.budget_max,
    r.gender,
    r.kind_pref,
    r.furnished_pref,
    r.move_in_date,
    r.min_stay_months,
    r.smoker,
    r.lifestyle_tags,
    r.note,
    p.id as seeker_id,
    p.first_name,
    p.full_name,
    p.phone,
    p.occupation,
    p.org_name,
    coalesce((p.verification_level)::integer, 0) as seeker_level,
    p.is_blocked,
    r.rental_period_pref,
    r.rooms_pref
   from ((seeker_requests r
     join cities c on ((c.id = r.city_id)))
     left join profiles p on ((p.id = r.seeker_id)));
alter view public.v_admin_requests set (security_invoker = on);
