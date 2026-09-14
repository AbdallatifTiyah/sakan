-- تعريض video_verified_at بـv_listings_public — الواجهة العامة (index.html)
-- بتقرأ العمود عبر select=* وبدها التاريخ لعرض «موثّق بمكالمة فيديو —
-- [التاريخ]». بذيل قائمة الأعمدة فقط (فخ إعادة الترتيب، موثّق بـCLAUDE.md).
-- هاي view عامة (anon) بدون security_invoker أصلاً (reloptions=null قبل
-- وبعد) — فخ التصفير التلقائي لا ينطبق هون، بس تحقّقت لأتأكد.
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
    s.hot_water,
    s.heating,
    s.internet,
    s.emergency_exit,
    s.street_access,
    l.features,
    l.video_verified_at
   FROM listings l
     JOIN cities c ON c.id = l.city_id
     JOIN areas a ON a.id = l.area_id
     LEFT JOIN profiles p ON p.id = l.owner_id
     LEFT JOIN listing_safety s ON s.listing_id = l.id
  WHERE l.status = 'published'::listing_status;
