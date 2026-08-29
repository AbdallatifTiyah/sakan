-- ═══ دوال إجراءات الإدارة ═══
-- كل دالة بتثبّت الفاعل بـapp.actor (محلي للمعاملة) عشان مسجّل التدقيق يلتقطه،
-- وبعدين بتنفّذ التعديل. كلها service_role فقط — القاعدة رقم ١١ مطبّقة على كل وحدة.

create or replace function public.admin_listing_status(
  p_id uuid, p_status text, p_reason text default null, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
begin
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);
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
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);
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
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);
  update listings
     set expires_at = greatest(coalesce(expires_at, now()), now()) + (d || ' days')::interval,
         last_confirmed_at = now(), updated_at = now()
   where id = p_id;
end $$;

create or replace function public.admin_profile_level(
  p_id uuid, p_level smallint, p_note text default null, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
declare v_old smallint;
begin
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);
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
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);
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
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);
  update reports set status = p_status::report_status, action_note = p_note where id = p_id;
end $$;

create or replace function public.admin_fee_status(
  p_id uuid, p_status text, p_note text default null, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);
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
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);
  update owner_fees set promo_code = nullif(trim(p_code),'') where id = p_id
  returning amount_due into v;
  return v;
end $$;

create or replace function public.admin_contact_status(
  p_id uuid, p_status text, p_notes text default null, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
begin
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);
  update contact_requests
     set status = p_status::contact_status,
         agent_notes = coalesce(p_notes, agent_notes),
         outcome_source = 'agent'
   where id = p_id;
end $$;

create or replace function public.admin_save_safety(
  p_listing uuid, p_visit date,
  p_room boolean, p_photos boolean, p_lock boolean, p_nocam boolean, p_occ boolean,
  p_light boolean default null, p_gas boolean default null,
  p_notes text default null, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
begin
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);
  insert into listing_safety (listing_id, visit_date, room_exists, photos_match, door_lock,
                              no_indoor_cameras, occupants_verified, exterior_lighting, gas_detector, notes)
  values (p_listing, p_visit, p_room, p_photos, p_lock, p_nocam, p_occ, p_light, p_gas, p_notes)
  on conflict (listing_id) do update set
    visit_date = excluded.visit_date, room_exists = excluded.room_exists,
    photos_match = excluded.photos_match, door_lock = excluded.door_lock,
    no_indoor_cameras = excluded.no_indoor_cameras, occupants_verified = excluded.occupants_verified,
    exterior_lighting = excluded.exterior_lighting, gas_detector = excluded.gas_detector,
    notes = excluded.notes;

  -- الترقية لتوثيق ميداني بتصير فقط لو كل بنود السلامة الإلزامية مرّت
  if p_room and p_photos and p_lock and p_nocam and p_occ then
    update listings set verification = 'field', updated_at = now() where id = p_listing;
  end if;
end $$;

create or replace function public.admin_set_setting(
  p_key text, p_value jsonb, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
begin
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);
  update settings set value = p_value, updated_at = now() where key = p_key;
end $$;

create or replace function public.admin_log(
  p_action text, p_subject_type text, p_subject_ref text default null,
  p_reason text default null, p_actor text default 'admin')
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into admin_actions (actor, action, subject_type, subject_ref, reason)
  values (coalesce(p_actor,'admin'), p_action, p_subject_type, p_subject_ref, p_reason);
end $$;

-- القاعدة ١١: سحب من PUBLIC ثم منح صريح لـservice_role
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'admin\_%'
  loop
    execute format('revoke execute on function %s from public, anon, authenticated', f.sig);
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;
end $$;

notify pgrst, 'reload schema';
