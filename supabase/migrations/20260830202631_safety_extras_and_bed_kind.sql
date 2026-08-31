-- ═══════════════════════════════════════════════════════════
-- ١) admin_save_safety: خانات إضافية + الكاميرا صارت ملاحظة
--    مش شرط للتوثيق الميداني
-- ═══════════════════════════════════════════════════════════

drop function if exists admin_save_safety(uuid,date,boolean,boolean,boolean,boolean,boolean,boolean,boolean,text,text);

create function admin_save_safety(
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
) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);

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

  -- التوثيق الميداني = الغرفة موجودة + الصور مطابقة + قفل الباب + السكان متحقّق منهم
  -- الكاميرا انشالت من الشروط: ما بنقدر نضمنها، وحمايتها صارت عبر البلاغات
  if coalesce(p_room,false) and coalesce(p_photos,false)
     and coalesce(p_lock,false) and coalesce(p_occ,false) then
    update listings set verification = 'field', updated_at = now() where id = p_listing;
  end if;
end $$;

revoke execute on function admin_save_safety(uuid,date,boolean,boolean,boolean,boolean,boolean,boolean,boolean,text,text,jsonb) from public;
revoke execute on function admin_save_safety(uuid,date,boolean,boolean,boolean,boolean,boolean,boolean,boolean,text,text,jsonb) from anon;
revoke execute on function admin_save_safety(uuid,date,boolean,boolean,boolean,boolean,boolean,boolean,boolean,text,text,jsonb) from authenticated;
grant  execute on function admin_save_safety(uuid,date,boolean,boolean,boolean,boolean,boolean,boolean,boolean,text,text,jsonb) to service_role;

-- ═══════════════════════════════════════════════════════════
-- ٢) نوع جديد: سرير في غرفة مشتركة
-- ═══════════════════════════════════════════════════════════
alter type listing_kind add value if not exists 'bed_shared' before 'studio';
