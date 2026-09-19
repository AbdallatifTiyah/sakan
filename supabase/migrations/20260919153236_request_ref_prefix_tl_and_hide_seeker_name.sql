-- سكنّا: بادئة مرجع طلب الباحث RQ- ← TL-، وحجب first_name عن v_requests_public
-- (قرار: اسم الباحث ما بيظهر بأي واجهة عامة — رمز الطلب TL-xxx بدلاً منه، بنفس منطق SK- للإعلانات)

create or replace function public.set_request_ref()
 returns trigger
 language plpgsql
as $function$
begin
  if new.ref is null then new.ref := 'TL-' || nextval('request_ref_seq')::text; end if;
  return new;
end $function$;

update seeker_requests
set ref = 'TL-' || substring(ref from 'RQ-(\d+)$')
where ref like 'RQ-%';

drop view v_requests_public;

create view v_requests_public as
select r.id, r.ref, r.budget_max, r.gender, r.kind_pref, r.furnished_pref,
       r.move_in_date, r.min_stay_months, r.smoker, r.lifestyle_tags, r.note,
       r.area_ids, c.name_ar as city, r.created_at,
       p.occupation,
       coalesce(p.verification_level::int, 0) as seeker_level,
       c.id as city_id
from seeker_requests r
join cities c on c.id = r.city_id
left join profiles p on p.id = r.seeker_id
where r.status = 'published'::request_status;

grant select on v_requests_public to anon, authenticated;
