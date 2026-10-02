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
    COALESCE(p.verification_level::integer, 0) AS seeker_level,
    c.id AS city_id,
    r.rental_period_pref,
    r.rooms_pref,
    r.neighborhood_ids
   FROM seeker_requests r
     JOIN cities c ON c.id = r.city_id
     LEFT JOIN profiles p ON p.id = r.seeker_id
  WHERE r.status = 'published'::request_status;

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
    n.name_ar AS neighborhood
   FROM listings l
     JOIN cities c ON c.id = l.city_id
     JOIN areas a ON a.id = l.area_id
     LEFT JOIN profiles p ON p.id = l.owner_id
     LEFT JOIN listing_safety s ON s.listing_id = l.id
     LEFT JOIN neighborhoods n ON n.id = l.neighborhood_id;

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
          WHERE a.id = ANY (r.area_ids)) AS areas_ar,
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
    COALESCE(p.verification_level::integer, 0) AS seeker_level,
    p.is_blocked,
    r.rental_period_pref,
    r.rooms_pref,
    r.outreach_status,
    r.neighborhood_ids,
    ( SELECT COALESCE(string_agg(n.name_ar, '، '::text ORDER BY n.sort_order), '—'::text) AS "coalesce"
           FROM neighborhoods n
          WHERE n.id = ANY (r.neighborhood_ids)) AS neighborhoods_ar
   FROM seeker_requests r
     JOIN cities c ON c.id = r.city_id
     LEFT JOIN profiles p ON p.id = r.seeker_id;

alter view public.v_admin_requests set (security_invoker = on);

create or replace view public.v_admin_pipeline as
 SELECT cr.id,
    cr.status,
    cr.created_at,
    cr.outcome_at,
    cr.agent_notes,
    cr.outcome_source,
    cr.seeker_name,
    cr.seeker_phone,
    cr.seeker_id,
    sp.first_name AS seeker_profile_name,
    sp.phone AS seeker_profile_phone,
    sp.verification_level AS seeker_level,
    l.id AS listing_id,
    l.ref AS listing_ref,
    l.title AS listing_title,
    l.price,
    l.status AS listing_status,
    c.name_ar AS city,
    a.name_ar AS area,
    op.first_name AS owner_name,
    op.phone AS owner_phone,
    f.id AS fee_id,
    f.status AS fee_status,
    f.amount_due,
    l.currency,
    l.verification AS listing_verification,
    op.verification_level AS owner_level,
    n.name_ar AS neighborhood
   FROM contact_requests cr
     LEFT JOIN listings l ON l.id = cr.listing_id
     LEFT JOIN cities c ON c.id = l.city_id
     LEFT JOIN areas a ON a.id = l.area_id
     LEFT JOIN profiles op ON op.id = l.owner_id
     LEFT JOIN profiles sp ON sp.id = cr.seeker_id
     LEFT JOIN owner_fees f ON f.contact_request_id = cr.id
     LEFT JOIN neighborhoods n ON n.id = l.neighborhood_id;

alter view public.v_admin_pipeline set (security_invoker = on);

-- إضافة الحي لجلسات لوحتي المالك (الذاتية والرابط الموقّع)
create or replace function public.my_owner_dashboard()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
        'city', c.name_ar, 'area', a.name_ar, 'neighborhood', n.name_ar,
        'published_at', l.published_at, 'expires_at', l.expires_at,
        'days_left', case when l.expires_at is null then null
                          else l.expires_at::date - current_date end,
        'view_count', l.view_count, 'reject_reason', l.reject_reason,
        'confirm_token', l.confirm_token
      ) order by l.created_at desc), '[]'::jsonb)
      from listings l join cities c on c.id=l.city_id join areas a on a.id=l.area_id
      left join neighborhoods n on n.id = l.neighborhood_id
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
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
        'city', c.name_ar, 'area', a.name_ar, 'neighborhood', n.name_ar,
        'published_at', l.published_at, 'expires_at', l.expires_at,
        'days_left', case when l.expires_at is null then null
                          else l.expires_at::date - current_date end,
        'view_count', l.view_count, 'reject_reason', l.reject_reason,
        'confirm_token', l.confirm_token
      ) order by l.created_at desc), '[]'::jsonb)
      from listings l
      join cities c on c.id = l.city_id
      join areas  a on a.id = l.area_id
      left join neighborhoods n on n.id = l.neighborhood_id
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
