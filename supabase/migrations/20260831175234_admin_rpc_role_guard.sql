-- ═══════════════════════════════════════════════════════════
-- حارس الدور بالـ١٦ دالة الإدارية + شيل الاعتماد على p_actor النصي
--    السبب: كل الدوال كانت service_role فقط. هلأ صارت متاحة
--    لـauthenticated (بعد staff_auth_foundation)، فلازم كل وحدة
--    تتحقق من is_staff()/is_admin() بنفسها، ولازم اسم الفاعل
--    بالسجل ييجي من auth.uid() → staff، مش من نص المندوب بيكتبه.
--    auth.uid() is null معناها الاستدعاء جاي من service_role أو
--    SQL مباشر — مسموح، عشان الانتقال وعشان طوارئ القاعدة.
-- ═══════════════════════════════════════════════════════════

create or replace function public.admin_listing_status(
  p_id uuid, p_status text, p_reason text default null, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  update listings
     set status = p_status::listing_status,
         reject_reason = case when p_status in ('rejected','expired') then p_reason else null end
   where id = p_id;
end $$;

create or replace function public.admin_listing_verification(
  p_id uuid, p_level text, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
declare v_old text;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  select verification::text into v_old from listings where id = p_id;
  update listings set verification = p_level::listing_verification, updated_at = now() where id = p_id;
  insert into verification_log (subject_type, subject_id, action, from_level, to_level, result)
  values ('listing', p_id, 'listing_verification', v_old, p_level, 'passed');
end $$;

create or replace function public.admin_listing_extend(
  p_id uuid, p_days integer default null, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
declare d integer := coalesce(p_days, setting_num('listing_expiry_days', 21)::integer);
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  update listings
     set expires_at = greatest(coalesce(expires_at, now()), now()) + (d || ' days')::interval,
         last_confirmed_at = now(), updated_at = now()
   where id = p_id;
end $$;

create or replace function public.admin_request_status(
  p_id uuid, p_status text, p_reason text default null, p_actor text default null
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);

  update seeker_requests
     set status = p_status::request_status,
         expires_at = case
           when p_status = 'published'
           then now() + (setting_num('listing_expiry_days', 21) || ' days')::interval
           else expires_at end
   where id = p_id;

  insert into admin_actions(actor, action, subject_type, subject_id, to_state, reason)
  values (coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), 'request_status', 'request', p_id, p_status, p_reason);
end $$;

create or replace function public.admin_profile_level(
  p_id uuid, p_level smallint, p_note text default null, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
declare v_old smallint;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  select verification_level into v_old from profiles where id = p_id;
  update profiles
     set verification_level = p_level,
         verified_at = case when p_level > 0 then now() else null end
   where id = p_id;
  insert into verification_log (subject_type, subject_id, action, from_level, to_level, result, reject_reason)
  values ('user', p_id, 'level_change', v_old::text, p_level::text,
          case when p_level >= coalesce(v_old,0) then 'passed' else 'failed' end, p_note);
end $$;

create or replace function public.admin_profile_block(
  p_id uuid, p_blocked boolean, p_reason text default null, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_admin() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  update profiles set is_blocked = p_blocked where id = p_id;
  if p_blocked then
    update listings set status = 'rejected', reject_reason = coalesce(p_reason, 'الحساب موقوف')
     where owner_id = p_id and status in ('published','pending','reserved');
  end if;
end $$;

create or replace function public.admin_report_status(
  p_id uuid, p_status text, p_note text default null, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_admin() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  update reports set status = p_status::report_status, action_note = p_note where id = p_id;
end $$;

create or replace function public.admin_fee_status(
  p_id uuid, p_status text, p_note text default null, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  update owner_fees
     set status = p_status::fee_status,
         note = p_note,
         collected_at = case when p_status = 'collected' then now() else null end
   where id = p_id
   returning promo_code into v_code;
  if p_status = 'collected' and v_code is not null then
    update promo_codes set used_count = used_count + 1 where code = v_code;
  end if;
end $$;

create or replace function public.admin_fee_promo(
  p_id uuid, p_code text, p_actor text default 'admin')
returns numeric language plpgsql security definer set search_path = public as $$
declare v numeric;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  update owner_fees set promo_code = nullif(trim(p_code),'') where id = p_id
  returning amount_due into v;
  return v;
end $$;

create or replace function public.admin_contact_status(
  p_id uuid, p_status text, p_notes text default null, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  update contact_requests
     set status = p_status::contact_status,
         agent_notes = coalesce(p_notes, agent_notes),
         outcome_source = 'agent'
   where id = p_id;
end $$;

create or replace function public.admin_save_safety(
  p_listing uuid,
  p_visit   date,
  p_room    boolean,
  p_photos  boolean,
  p_lock    boolean,
  p_nocam   boolean default null,
  p_occ     boolean default null,
  p_light   boolean default null,
  p_gas     boolean default null,
  p_notes   text    default null,
  p_actor   text    default null,
  p_extras  jsonb   default '{}'::jsonb
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);

  insert into listing_safety (
    listing_id, visit_date, room_exists, photos_match, door_lock,
    no_indoor_cameras, occupants_verified, exterior_lighting, gas_detector, notes,
    private_bathroom, kitchen_access, hot_water, heating,
    internet, emergency_exit, street_access, owner_met
  ) values (
    p_listing, p_visit, p_room, p_photos, p_lock,
    p_nocam, p_occ, p_light, p_gas, p_notes,
    (p_extras->>'private_bathroom')::boolean,
    (p_extras->>'kitchen_access')::boolean,
    (p_extras->>'hot_water')::boolean,
    (p_extras->>'heating')::boolean,
    (p_extras->>'internet')::boolean,
    (p_extras->>'emergency_exit')::boolean,
    (p_extras->>'street_access')::boolean,
    (p_extras->>'owner_met')::boolean
  )
  on conflict (listing_id) do update set
    visit_date         = excluded.visit_date,
    room_exists        = excluded.room_exists,
    photos_match       = excluded.photos_match,
    door_lock          = excluded.door_lock,
    no_indoor_cameras  = excluded.no_indoor_cameras,
    occupants_verified = excluded.occupants_verified,
    exterior_lighting  = excluded.exterior_lighting,
    gas_detector       = excluded.gas_detector,
    notes              = excluded.notes,
    private_bathroom   = excluded.private_bathroom,
    kitchen_access     = excluded.kitchen_access,
    hot_water          = excluded.hot_water,
    heating            = excluded.heating,
    internet           = excluded.internet,
    emergency_exit     = excluded.emergency_exit,
    street_access      = excluded.street_access,
    owner_met          = excluded.owner_met;

  if coalesce(p_room,false) and coalesce(p_photos,false)
     and coalesce(p_lock,false) and coalesce(p_occ,false) then
    update listings set verification = 'field', updated_at = now() where id = p_listing;
  end if;
end $$;

create or replace function public.admin_city_save(
  p_id int, p_name text, p_slug text, p_active boolean default true, p_actor text default null
) returns int language plpgsql security definer set search_path = public as $$
declare v_id int;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  if p_id is null then
    insert into cities(name_ar, slug, is_active) values (p_name, p_slug, p_active)
    returning id into v_id;
  else
    update cities set name_ar = p_name, slug = p_slug, is_active = p_active
     where id = p_id returning id into v_id;
  end if;
  insert into admin_actions(actor, action, subject_type, subject_ref, to_state)
  values (coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), 'city_save', 'city', p_name, p_active::text);
  return v_id;
end $$;

create or replace function public.admin_area_save(
  p_id int, p_city int, p_name text, p_slug text,
  p_sort int default 100, p_active boolean default true, p_actor text default null
) returns int language plpgsql security definer set search_path = public as $$
declare v_id int;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  if p_id is null then
    insert into areas(city_id, name_ar, slug, sort_order, is_active)
    values (p_city, p_name, p_slug, coalesce(p_sort,100), p_active)
    returning id into v_id;
  else
    update areas set city_id = p_city, name_ar = p_name, slug = p_slug,
                     sort_order = coalesce(p_sort,100), is_active = p_active
     where id = p_id returning id into v_id;
  end if;
  insert into admin_actions(actor, action, subject_type, subject_ref, to_state)
  values (coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), 'area_save', 'area', p_name, p_active::text);
  return v_id;
end $$;

create or replace function public.admin_page_save(
  p_key text, p_title text, p_body text,
  p_published boolean default true, p_actor text default null
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_admin() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  if coalesce(btrim(p_body),'') = '' then raise exception 'النص فاضي'; end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);

  insert into pages(key, title_ar, body_md, is_published, updated_at, updated_by)
  values (p_key, p_title, p_body, coalesce(p_published,true), now(), coalesce(nullif(actor_name(),'service'), p_actor, 'admin'))
  on conflict (key) do update set
    title_ar = excluded.title_ar,
    body_md  = excluded.body_md,
    is_published = excluded.is_published,
    updated_at = now(),
    updated_by = excluded.updated_by;

  insert into admin_actions(actor, action, subject_type, subject_ref, reason)
  values (coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), 'page_save', 'page', p_key, null);
end $$;

create or replace function public.admin_set_setting(
  p_key text, p_value jsonb, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_admin() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  update settings set value = p_value, updated_at = now() where key = p_key;
end $$;

create or replace function public.admin_log(
  p_action text, p_subject_type text, p_subject_ref text default null,
  p_reason text default null, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  insert into admin_actions (actor, action, subject_type, subject_ref, reason)
  values (coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), p_action, p_subject_type, p_subject_ref, p_reason);
end $$;

-- القاعدة ١١: سحب من PUBLIC/anon ثم منح صريح لـauthenticated وservice_role
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'admin\_%'
  loop
    execute format('revoke execute on function %s from public, anon', f.sig);
    execute format('grant execute on function %s to authenticated, service_role', f.sig);
  end loop;
end $$;

notify pgrst, 'reload schema';
