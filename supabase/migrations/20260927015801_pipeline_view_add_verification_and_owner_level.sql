-- v_admin_pipeline: إضافة توثيق الإعلان ومستوى توثيق المالك بذيل القائمة —
-- لعرضهما بشاشة تفاصيل طلب التواصل بمركز التحكم (وضوح أكتر، بدون تغيير أعمدة قديمة).
create or replace view v_admin_pipeline as
 SELECT cr.id, cr.status, cr.created_at, cr.outcome_at, cr.agent_notes, cr.outcome_source, cr.seeker_name,
    cr.seeker_phone, cr.seeker_id, sp.first_name AS seeker_profile_name, sp.phone AS seeker_profile_phone,
    sp.verification_level AS seeker_level, l.id AS listing_id, l.ref AS listing_ref, l.title AS listing_title,
    l.price, l.status AS listing_status, c.name_ar AS city, a.name_ar AS area, op.first_name AS owner_name,
    op.phone AS owner_phone, f.id AS fee_id, f.status AS fee_status, f.amount_due, l.currency,
    l.verification AS listing_verification, op.verification_level AS owner_level
   FROM ((((((contact_requests cr LEFT JOIN listings l ON ((l.id = cr.listing_id)))
     LEFT JOIN cities c ON ((c.id = l.city_id))) LEFT JOIN areas a ON ((a.id = l.area_id)))
     LEFT JOIN profiles op ON ((op.id = l.owner_id))) LEFT JOIN profiles sp ON ((sp.id = cr.seeker_id)))
     LEFT JOIN owner_fees f ON ((f.contact_request_id = cr.id)));

alter view public.v_admin_pipeline set (security_invoker = on);
