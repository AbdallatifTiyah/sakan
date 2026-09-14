-- إضافة video_verified_at لـv_admin_listings عشان الطاقم يشوف تاريخ
-- توثيق مكالمة الفيديو بنفس مكان تاريخ الزيارة الميدانية (visit_date).
-- العمود الجديد بذيل القائمة فقط (فخ إعادة ترتيب/تسمية أعمدة
-- create or replace view، موثّق بـCLAUDE.md). create or replace view
-- بيصفّر security_invoker تلقائياً (فخ ثانٍ) — alter view منفصل بعده
-- بنفس الملف، وتحقّق reloptions + set local role authenticated (غير
-- موظّف) = صفر صفوف.
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
    s.hot_water,
    s.heating,
    s.internet,
    s.emergency_exit,
    s.street_access,
    s.owner_met,
    l.features,
    l.review_token,
    l.video_verified_at
   FROM listings l
     JOIN cities c ON c.id = l.city_id
     JOIN areas a ON a.id = l.area_id
     LEFT JOIN profiles p ON p.id = l.owner_id
     LEFT JOIN listing_safety s ON s.listing_id = l.id;

alter view public.v_admin_listings set (security_invoker = on);
