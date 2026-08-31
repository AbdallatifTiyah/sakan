-- إضافة خانات الزيارة الجديدة + المواصفات لواجهة الإدارة.
-- الأعمدة الجديدة متضافة بذيل القائمة فقط (شرط create or replace view).
create or replace view v_admin_listings as
select l.id, l.ref, l.title, l.description, l.kind, l.status, l.verification,
       l.price, l.deposit, l.bills_included, l.gender_pol, l.furnished,
       l.rooms_total, l.occupants_now, l.occupants_note, l.available_from,
       l.min_stay_months, l.landmark, l.exact_address, l.images, l.reject_reason,
       l.published_at, l.expires_at, l.last_confirmed_at, l.rented_at,
       l.created_at, l.updated_at, l.view_count, l.confirm_token,
       l.city_id, c.name_ar as city, l.area_id, a.name_ar as area,
       p.id as owner_id, p.first_name as owner_name, p.phone as owner_phone,
       p.verification_level as owner_level, p.is_blocked as owner_blocked,
       s.visit_date, s.room_exists, s.photos_match, s.door_lock,
       s.no_indoor_cameras, s.occupants_verified, s.exterior_lighting,
       s.gas_detector, s.notes as safety_notes,
       (select count(*) from contact_requests cr where cr.listing_id = l.id) as contacts,
       (select count(*) from contact_requests cr
         where cr.listing_id = l.id and cr.status = 'rented'::contact_status) as rentals,
       (select count(*) from reports r
         where r.listing_id = l.id and r.status = 'open'::report_status) as open_reports,
       (select count(*) from reviews rv where rv.listing_id = l.id) as reviews_count,
       case when l.expires_at is null then null::integer
            else l.expires_at::date - current_date end as days_left,
       -- ▼ جديد
       s.private_bathroom, s.kitchen_access, s.hot_water, s.heating,
       s.internet, s.emergency_exit, s.street_access, s.owner_met,
       l.features
from listings l
join cities c on c.id = l.city_id
join areas  a on a.id = l.area_id
left join profiles p on p.id = l.owner_id
left join listing_safety s on s.listing_id = l.id;

revoke all on v_admin_listings from public;
revoke all on v_admin_listings from anon;
revoke all on v_admin_listings from authenticated;
grant select on v_admin_listings to service_role;
