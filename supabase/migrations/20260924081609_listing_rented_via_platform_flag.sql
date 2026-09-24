alter table listings add column rented_via_platform boolean;

drop function if exists admin_listing_status(uuid, text, text, text);

create or replace function admin_listing_status(p_id uuid, p_status text, p_reason text default null, p_actor text default 'admin', p_rented_via_platform boolean default null)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  update listings
     set status = p_status::listing_status,
         reject_reason = case when p_status in ('rejected','expired') then p_reason else null end,
         rented_via_platform = case when p_status = 'rented' then p_rented_via_platform else rented_via_platform end
   where id = p_id;
end $function$;

revoke execute on function admin_listing_status(uuid, text, text, text, boolean) from public;
grant execute on function admin_listing_status(uuid, text, text, text, boolean) to authenticated, service_role;

create or replace view v_admin_listings as
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
    l.rented_via_platform
   FROM listings l
     JOIN cities c ON c.id = l.city_id
     JOIN areas a ON a.id = l.area_id
     LEFT JOIN profiles p ON p.id = l.owner_id
     LEFT JOIN listing_safety s ON s.listing_id = l.id;

alter view v_admin_listings set (security_invoker = on);

create or replace view v_kpi_quality as
 SELECT round(100.0 * NULLIF(( SELECT count(*) AS count
           FROM contact_requests
          WHERE contact_requests.status = 'rented'::contact_status), 0)::numeric / NULLIF(( SELECT count(*) AS count
           FROM contact_requests), 0)::numeric, 1) AS contact_to_rent_pct,
    ( SELECT percentile_cont(0.5::double precision) WITHIN GROUP (ORDER BY (EXTRACT(day FROM listings.rented_at - listings.published_at)::double precision)) AS percentile_cont
           FROM listings
          WHERE listings.rented_at IS NOT NULL AND listings.rented_via_platform IS NOT FALSE) AS median_days_to_rent,
    round(100.0 * (( SELECT count(*) AS count
           FROM ( SELECT p.phone
                   FROM listings l
                     JOIN profiles p ON p.id = l.owner_id
                  WHERE l.created_at > (now() - '180 days'::interval) AND l.owner_id IS NOT NULL AND p.phone IS NOT NULL
                  GROUP BY p.phone
                 HAVING count(*) > 1) x))::numeric / NULLIF(( SELECT count(DISTINCT p.phone) AS count
           FROM listings l
             JOIN profiles p ON p.id = l.owner_id
          WHERE l.created_at > (now() - '180 days'::interval) AND l.owner_id IS NOT NULL AND p.phone IS NOT NULL), 0)::numeric, 1) AS owner_repeat_pct,
    round(100.0 * (( SELECT count(*) AS count
           FROM listings
          WHERE listings.status = 'published'::listing_status AND listings.verification = 'field'::listing_verification))::numeric / NULLIF(( SELECT count(*) AS count
           FROM listings
          WHERE listings.status = 'published'::listing_status), 0)::numeric, 1) AS field_verified_pct,
    round(100.0 * (( SELECT count(*) AS count
           FROM reports))::numeric / NULLIF(( SELECT count(*) AS count
           FROM listings), 0)::numeric, 2) AS report_rate_pct,
    round(100.0 * (( SELECT count(*) AS count
           FROM listings
          WHERE listings.status = 'published'::listing_status AND listings.verification = 'video'::listing_verification))::numeric / NULLIF(( SELECT count(*) AS count
           FROM listings
          WHERE listings.status = 'published'::listing_status), 0)::numeric, 1) AS video_verified_pct;

alter view v_kpi_quality set (security_invoker = on);
