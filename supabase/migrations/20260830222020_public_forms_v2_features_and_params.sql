-- ═══════════════════════════════════════════════════════════
-- ١) مواصفات الغرفة (checkboxes بنموذج «أضف غرفة»)
-- ═══════════════════════════════════════════════════════════
alter table listings add column if not exists features text[] not null default '{}';

-- ملاحظة: create or replace view بتسمح بإضافة أعمدة بالآخر فقط،
-- فالأعمدة الجديدة كلها متضافة بذيل القائمة والترتيب الأصلي محفوظ.
create or replace view v_listings_public as
select l.id, l.ref, l.title, l.description,
       c.name_ar as city, c.slug as city_slug,
       a.name_ar as area, a.id as area_id,
       l.landmark, l.kind, l.price, l.bills_included, l.deposit,
       l.gender_pol, l.furnished, l.rooms_total, l.occupants_now, l.occupants_note,
       l.available_from, l.min_stay_months, l.images, l.verification,
       l.published_at, l.expires_at, l.view_count,
       coalesce(p.verification_level::int, 0) as owner_level,
       s.visit_date, s.door_lock, s.no_indoor_cameras, s.room_exists,
       s.photos_match, s.occupants_verified, s.exterior_lighting, s.gas_detector,
       (select count(*) from reviews r where r.listing_id = l.id and r.is_published) as review_count,
       (select round(avg((r.r_maintenance + r.r_quiet + r.r_accuracy + r.r_safety_night)::numeric / 4.0), 1)
          from reviews r where r.listing_id = l.id and r.is_published) as review_avg,
       -- ▼ جديد
       c.id as city_id,
       s.private_bathroom, s.kitchen_access, s.hot_water, s.heating,
       s.internet, s.emergency_exit, s.street_access,
       l.features
from listings l
join cities c on c.id = l.city_id
join areas  a on a.id = l.area_id
left join profiles p on p.id = l.owner_id
left join listing_safety s on s.listing_id = l.id
where l.status = 'published'::listing_status;

create or replace view v_requests_public as
select r.id, r.ref, r.budget_max, r.gender, r.kind_pref, r.furnished_pref,
       r.move_in_date, r.min_stay_months, r.smoker, r.lifestyle_tags, r.note,
       r.area_ids, c.name_ar as city, r.created_at,
       p.first_name, p.occupation,
       coalesce(p.verification_level::int, 0) as seeker_level,
       -- ▼ جديد
       c.id as city_id
from seeker_requests r
join cities c on c.id = r.city_id
left join profiles p on p.id = r.seeker_id
where r.status = 'published'::request_status;

grant select on v_listings_public to anon, authenticated;
grant select on v_requests_public to anon, authenticated;


-- ═══════════════════════════════════════════════════════════
-- ٢) submit_listing: مواصفات + تأمين + فواتير + عدد غرف + أقل مدة
--    البارامترات الجديدة كلها اختيارية — الاستدعاء القديم بيضل يشتغل
-- ═══════════════════════════════════════════════════════════
drop function if exists submit_listing(text,text,text,integer,numeric,text,text,boolean,date,text,text,text);

create function submit_listing(
  p_name text, p_phone text, p_title text, p_area integer, p_price numeric,
  p_kind text, p_pol text, p_furnished boolean, p_from date,
  p_occ text default null, p_landmark text default null, p_desc text default null,
  p_features text[] default '{}', p_deposit numeric default null,
  p_bills boolean default false, p_rooms smallint default null,
  p_min_stay smallint default null
) returns text
language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_ref text; v_city int;
begin
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' then
    raise exception 'الاسم والرقم مطلوبان';
  end if;

  select city_id into v_city from areas where id = p_area and is_active;
  if v_city is null then raise exception 'منطقة غير صحيحة'; end if;

  select id into v_owner from profiles
   where phone = trim(p_phone) and role = 'owner' limit 1;

  if v_owner is null then
    insert into profiles (role, first_name, phone, city_id)
    values ('owner', trim(p_name), trim(p_phone), v_city)
    returning id into v_owner;
  end if;

  insert into listings (owner_id, city_id, area_id, title, description, price,
                        kind, gender_pol, furnished, available_from,
                        occupants_note, landmark, features, deposit,
                        bills_included, rooms_total, min_stay_months)
  values (v_owner, v_city, p_area, trim(p_title), nullif(trim(coalesce(p_desc,'')),''),
          p_price, p_kind::listing_kind, p_pol::gender_policy, coalesce(p_furnished,true),
          p_from, nullif(trim(coalesce(p_occ,'')),''), nullif(trim(coalesce(p_landmark,'')),''),
          coalesce(p_features,'{}'), p_deposit, coalesce(p_bills,false), p_rooms, p_min_stay)
  returning ref into v_ref;

  insert into events (event_type, source, actor_role, meta)
  values ('listing_created','user','owner', jsonb_build_object('ref', v_ref));

  return v_ref;
end $$;

revoke execute on function submit_listing(text,text,text,integer,numeric,text,text,boolean,date,text,text,text,text[],numeric,boolean,smallint,smallint) from public;
grant  execute on function submit_listing(text,text,text,integer,numeric,text,text,boolean,date,text,text,text,text[],numeric,boolean,smallint,smallint) to anon, authenticated, service_role;


-- ═══════════════════════════════════════════════════════════
-- ٣) submit_request: مدينة صريحة + تفضيل النوع/الفرش/المدة/التدخين
-- ═══════════════════════════════════════════════════════════
drop function if exists submit_request(text,text,text,text,numeric,integer[],date,text[],text);

create function submit_request(
  p_name text, p_phone text, p_gender text, p_occupation text, p_budget numeric,
  p_areas integer[], p_move_in date, p_tags text[] default '{}', p_note text default null,
  p_city integer default null, p_kind text default null,
  p_furnished boolean default null, p_min_stay smallint default null,
  p_smoker boolean default null
) returns text
language plpgsql security definer set search_path = public as $$
declare v_seeker uuid; v_ref text; v_city int;
begin
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' then
    raise exception 'الاسم والرقم مطلوبان';
  end if;

  v_city := p_city;
  if v_city is null then
    select min(city_id) into v_city from areas where id = any(coalesce(p_areas,'{}'));
  end if;
  if v_city is null then raise exception 'اختر المدينة'; end if;
  if not exists (select 1 from cities where id = v_city and is_active) then
    raise exception 'مدينة غير صحيحة';
  end if;

  select id into v_seeker from profiles
   where phone = trim(p_phone) and role = 'seeker' limit 1;

  if v_seeker is null then
    insert into profiles (role, first_name, phone, gender, occupation, city_id)
    values ('seeker', trim(p_name), trim(p_phone),
            nullif(p_gender,'')::gender_type,
            coalesce(nullif(p_occupation,''),'other')::occupation_type, v_city)
    returning id into v_seeker;
  end if;

  insert into seeker_requests (seeker_id, city_id, area_ids, budget_max, gender,
                               move_in_date, lifestyle_tags, note,
                               kind_pref, furnished_pref, min_stay_months, smoker)
  values (v_seeker, v_city, coalesce(p_areas,'{}'), p_budget,
          nullif(p_gender,'')::gender_type, p_move_in,
          coalesce(p_tags,'{}'), nullif(trim(coalesce(p_note,'')),''),
          nullif(p_kind,'')::listing_kind, p_furnished, p_min_stay, p_smoker)
  returning ref into v_ref;

  insert into events (event_type, source, actor_role, meta)
  values ('request_created','user','seeker', jsonb_build_object('ref', v_ref));

  return v_ref;
end $$;

revoke execute on function submit_request(text,text,text,text,numeric,integer[],date,text[],text,integer,text,boolean,smallint,boolean) from public;
grant  execute on function submit_request(text,text,text,text,numeric,integer[],date,text[],text,integer,text,boolean,smallint,boolean) to anon, authenticated, service_role;
