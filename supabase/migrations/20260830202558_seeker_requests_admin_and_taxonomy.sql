-- ═══════════════════════════════════════════════════════════
-- ١) واجهة إدارية لطلبات الباحثين + دالة نشر/رفض
--    السبب: ما كان في أي طريق لتحويل seeker_requests من
--    'pending' لـ'published'. v_requests_public بتفلتر على
--    status='published' — فالطلبات بتضل مخفية للأبد.
-- ═══════════════════════════════════════════════════════════

create or replace view v_admin_requests as
select
  r.id,
  r.ref,
  r.status,
  r.created_at,
  r.expires_at,
  c.id            as city_id,
  c.name_ar       as city,
  r.area_ids,
  (select coalesce(string_agg(a.name_ar, '، ' order by a.sort_order), '—')
     from areas a where a.id = any(r.area_ids)) as areas_ar,
  r.budget_max,
  r.gender,
  r.kind_pref,
  r.furnished_pref,
  r.move_in_date,
  r.min_stay_months,
  r.smoker,
  r.lifestyle_tags,
  r.note,
  p.id            as seeker_id,
  p.first_name,
  p.full_name,
  p.phone,
  p.occupation,
  p.org_name,
  coalesce(p.verification_level::int, 0) as seeker_level,
  p.is_blocked
from seeker_requests r
join cities c on c.id = r.city_id
left join profiles p on p.id = r.seeker_id;

revoke all on v_admin_requests from public;
revoke all on v_admin_requests from anon;
revoke all on v_admin_requests from authenticated;
grant select on v_admin_requests to service_role;

create or replace function admin_request_status(
  p_id uuid, p_status text, p_reason text default null, p_actor text default null
) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);

  update seeker_requests
     set status = p_status::request_status,
         expires_at = case
           when p_status = 'published'
           then now() + (setting_num('listing_expiry_days', 21) || ' days')::interval
           else expires_at end
   where id = p_id;

  insert into admin_actions(actor, action, subject_type, subject_id, to_state, reason)
  values (coalesce(p_actor,'admin'), 'request_status', 'request', p_id, p_status, p_reason);
end $$;

revoke execute on function admin_request_status(uuid,text,text,text) from public;
revoke execute on function admin_request_status(uuid,text,text,text) from anon;
revoke execute on function admin_request_status(uuid,text,text,text) from authenticated;
grant  execute on function admin_request_status(uuid,text,text,text) to service_role;


-- ═══════════════════════════════════════════════════════════
-- ٢) تحكم الإدارة بالمدن والمناطق
-- ═══════════════════════════════════════════════════════════

alter table areas add column if not exists is_active boolean not null default true;

create or replace function admin_city_save(
  p_id int, p_name text, p_slug text, p_active boolean default true, p_actor text default null
) returns int
language plpgsql security definer set search_path = public as $$
declare v_id int;
begin
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);
  if p_id is null then
    insert into cities(name_ar, slug, is_active) values (p_name, p_slug, p_active)
    returning id into v_id;
  else
    update cities set name_ar = p_name, slug = p_slug, is_active = p_active
     where id = p_id returning id into v_id;
  end if;
  insert into admin_actions(actor, action, subject_type, subject_ref, to_state)
  values (coalesce(p_actor,'admin'), 'city_save', 'city', p_name, p_active::text);
  return v_id;
end $$;

create or replace function admin_area_save(
  p_id int, p_city int, p_name text, p_slug text,
  p_sort int default 100, p_active boolean default true, p_actor text default null
) returns int
language plpgsql security definer set search_path = public as $$
declare v_id int;
begin
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);
  if p_id is null then
    insert into areas(city_id, name_ar, slug, sort_order, is_active)
    values (p_city, p_name, p_slug, coalesce(p_sort,100), p_active)
    returning id into v_id;
  else
    update areas set city_id = p_city, name_ar = p_name, slug = p_slug,
                     sort_order = coalesce(p_sort,100), is_active = p_active
     where id = p_id returning id into v_id;
  end if;
  insert into admin_actions(actor, action, subject_type, subject_ref, to_state)
  values (coalesce(p_actor,'admin'), 'area_save', 'area', p_name, p_active::text);
  return v_id;
end $$;

revoke execute on function admin_city_save(int,text,text,boolean,text) from public;
revoke execute on function admin_city_save(int,text,text,boolean,text) from anon;
revoke execute on function admin_city_save(int,text,text,boolean,text) from authenticated;
grant  execute on function admin_city_save(int,text,text,boolean,text) to service_role;

revoke execute on function admin_area_save(int,int,text,text,int,boolean,text) from public;
revoke execute on function admin_area_save(int,int,text,text,int,boolean,text) from anon;
revoke execute on function admin_area_save(int,int,text,text,int,boolean,text) from authenticated;
grant  execute on function admin_area_save(int,int,text,text,int,boolean,text) to service_role;


-- ═══════════════════════════════════════════════════════════
-- ٣) إلغاء الرفض التلقائي بسبب الكاميرا
--    السبب: no_indoor_cameras كان default false، والمشغّل
--    بيرفض الإعلان لما تكون false. يعني أي زيارة ميدانية
--    بتنحفظ والخانة مش متأشّرة = رفض فوري للإعلان.
--    الحماية الحقيقية بتضل عبر بلاغ category='camera'
--    اللي بيشغّل suspend_on_serious_report.
-- ═══════════════════════════════════════════════════════════

drop trigger if exists trg_block_camera on listing_safety;
drop function if exists block_camera_listings();

alter table listing_safety alter column no_indoor_cameras drop not null;
alter table listing_safety alter column no_indoor_cameras drop default;


-- ═══════════════════════════════════════════════════════════
-- ٤) خانات إضافية للزيارة الميدانية
-- ═══════════════════════════════════════════════════════════

alter table listing_safety add column if not exists private_bathroom  boolean;
alter table listing_safety add column if not exists kitchen_access    boolean;
alter table listing_safety add column if not exists hot_water         boolean;
alter table listing_safety add column if not exists heating           boolean;
alter table listing_safety add column if not exists internet          boolean;
alter table listing_safety add column if not exists emergency_exit    boolean;
alter table listing_safety add column if not exists street_access     boolean;
alter table listing_safety add column if not exists owner_met         boolean;
