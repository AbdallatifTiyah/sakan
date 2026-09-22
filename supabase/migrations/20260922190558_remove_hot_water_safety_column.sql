-- إزالة بند "ماء ساخن" من فحص الزيارة الميدانية (listing_safety.hot_water) بالكامل —
-- استُبدل بمواصفتي "بويلر كهرباء"/"حمام شمسي" بمواصفات الإعلان (listings.features)
drop view if exists v_admin_listings;
drop view if exists v_listings_public;

alter table listing_safety drop column if exists hot_water;

create view v_listings_public as
 SELECT l.id, l.ref, l.title, l.description, c.name_ar AS city, c.slug AS city_slug, a.name_ar AS area, a.id AS area_id,
    l.landmark, l.kind, l.price, l.bills_included, l.deposit, l.gender_pol, l.furnished, l.rooms_total,
    l.occupants_now, l.occupants_note, l.available_from, l.min_stay_months, l.images, l.verification,
    l.published_at, l.expires_at, l.view_count, COALESCE((p.verification_level)::integer, 0) AS owner_level,
    s.visit_date, s.door_lock, s.no_indoor_cameras, s.room_exists, s.photos_match, s.occupants_verified,
    s.exterior_lighting, s.gas_detector,
    ( SELECT count(*) AS count FROM reviews r WHERE ((r.listing_id = l.id) AND r.is_published)) AS review_count,
    ( SELECT round(avg((((((r.r_maintenance + r.r_quiet) + r.r_accuracy) + r.r_safety_night))::numeric / 4.0)), 1) AS round
           FROM reviews r WHERE ((r.listing_id = l.id) AND r.is_published)) AS review_avg,
    c.id AS city_id, s.private_bathroom, s.kitchen_access, s.heating, s.internet,
    s.emergency_exit, s.street_access, l.features, l.video_verified_at,
    l.currency, l.bills_water, l.bills_electricity, l.bills_internet
   FROM ((((listings l JOIN cities c ON ((c.id = l.city_id))) JOIN areas a ON ((a.id = l.area_id)))
     LEFT JOIN profiles p ON ((p.id = l.owner_id))) LEFT JOIN listing_safety s ON ((s.listing_id = l.id)))
  WHERE (l.status = 'published'::listing_status);

grant select on v_listings_public to anon, authenticated;

create view v_admin_listings as
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
    s.private_bathroom, s.kitchen_access, s.heating, s.internet, s.emergency_exit, s.street_access,
    s.owner_met, l.features, l.review_token, l.video_verified_at,
    l.currency, l.bills_water, l.bills_electricity, l.bills_internet
   FROM ((((listings l JOIN cities c ON ((c.id = l.city_id))) JOIN areas a ON ((a.id = l.area_id)))
     LEFT JOIN profiles p ON ((p.id = l.owner_id))) LEFT JOIN listing_safety s ON ((s.listing_id = l.id)));

alter view v_admin_listings set (security_invoker = on);
grant select on v_admin_listings to authenticated, service_role;

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
    private_bathroom, kitchen_access, heating,
    internet, emergency_exit, street_access, owner_met
  ) values (
    p_listing, p_visit, p_room, p_photos, p_lock,
    p_nocam, p_occ, p_light, p_gas, p_notes,
    (p_extras->>'private_bathroom')::boolean,
    (p_extras->>'kitchen_access')::boolean,
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
