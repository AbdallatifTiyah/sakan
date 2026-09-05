create view v_admin_reviews as
select
  r.id,
  r.listing_id,
  l.ref as listing_ref,
  l.title as listing_title,
  c.name_ar as city,
  a.name_ar as area,
  r.stage,
  r.r_maintenance,
  r.r_quiet,
  r.r_accuracy,
  r.r_safety_night,
  round((r.r_maintenance + r.r_quiet + r.r_accuracy + r.r_safety_night)::numeric / 4.0, 1) as avg_rating,
  r.entered_without_permission,
  r.deposit_returned,
  r.is_published,
  r.created_at
from reviews r
join listings l on l.id = r.listing_id
join cities c on c.id = l.city_id
join areas a on a.id = l.area_id;

alter view v_admin_reviews set (security_invoker = on);
