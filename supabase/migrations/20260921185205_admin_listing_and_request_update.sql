create function public.admin_listing_update(
  p_id uuid, p_title text, p_description text, p_price numeric, p_currency text, p_deposit numeric,
  p_kind text, p_pol text, p_furnished boolean, p_bills_water boolean, p_bills_electricity boolean,
  p_bills_internet boolean, p_rooms smallint, p_min_stay smallint, p_from date, p_landmark text,
  p_occ text, p_features text[], p_area integer
)
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
    updated_at = now()
  where id = p_id
  returning ref into v_ref;

  if v_ref is null then raise exception 'إعلان غير موجود'; end if;

  insert into admin_actions(actor, action, subject_type, subject_id, subject_ref, to_state)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'listing_data_update', 'listing', p_id, v_ref, 'edited');
end $function$;

revoke all on function public.admin_listing_update(uuid,text,text,numeric,text,numeric,text,text,boolean,boolean,boolean,boolean,smallint,smallint,date,text,text,text[],integer) from public;
grant execute on function public.admin_listing_update(uuid,text,text,numeric,text,numeric,text,text,boolean,boolean,boolean,boolean,smallint,smallint,date,text,text,text[],integer) to authenticated, service_role;

create function public.admin_request_update(
  p_id uuid, p_budget numeric, p_gender text, p_kind text, p_furnished boolean, p_move_in date,
  p_min_stay smallint, p_smoker boolean, p_tags text[], p_note text, p_city integer, p_areas integer[]
)
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
    area_ids = coalesce(p_areas,'{}')
  where id = p_id;

  if not found then raise exception 'طلب غير موجود'; end if;

  insert into admin_actions(actor, action, subject_type, subject_id, to_state)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'request_data_update', 'request', p_id, 'edited');
end $function$;

revoke all on function public.admin_request_update(uuid,numeric,text,text,boolean,date,smallint,boolean,text[],text,integer,integer[]) from public;
grant execute on function public.admin_request_update(uuid,numeric,text,text,boolean,date,smallint,boolean,text[],text,integer,integer[]) to authenticated, service_role;
