-- حالة تواصل المندوب — CRM بسيط لتتبّع محاولات التواصل مع المالك (بانتظار
-- المراجعة) والباحث (طلبات الباحثين) قبل اعتماد الإعلان/الطلب. منفصل تماماً
-- عن contact_requests.status (ده لمسار تواصل الباحث مع إعلان منشور فعلاً).
create type outreach_status as enum ('not_contacted','no_answer','called','whatsapp_sent','viewing_scheduled');

alter table listings add column outreach_status outreach_status not null default 'not_contacted';
alter table seeker_requests add column outreach_status outreach_status not null default 'not_contacted';

-- توسيع المدقّق: بند تواصل المالك على الإعلانات + قسم كامل جديد لـ
-- seeker_requests (حالة وتواصل معاً — ما كان فيه تريغر تدقيق على الجدول
-- هذا من الأساس، فتغييرات حالته ما كانت تظهر بأي سجل نشاط).
create or replace function public.audit_admin_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare v text := coalesce(nullif(current_setting('app.actor', true), ''), 'direct');
begin
  if tg_table_name = 'listings' then
    if new.status is distinct from old.status then
      insert into admin_actions(actor,action,subject_type,subject_id,subject_ref,from_state,to_state,reason)
      values (v,'listing_status','listing',new.id,new.ref,old.status::text,new.status::text,new.reject_reason);
    end if;
    if new.verification is distinct from old.verification then
      insert into admin_actions(actor,action,subject_type,subject_id,subject_ref,from_state,to_state)
      values (v,'listing_verification','listing',new.id,new.ref,old.verification::text,new.verification::text);
    end if;
    if new.expires_at is distinct from old.expires_at and new.status is not distinct from old.status then
      insert into admin_actions(actor,action,subject_type,subject_id,subject_ref,from_state,to_state)
      values (v,'listing_expiry','listing',new.id,new.ref,old.expires_at::text,new.expires_at::text);
    end if;
    if new.outreach_status is distinct from old.outreach_status then
      insert into admin_actions(actor,action,subject_type,subject_id,subject_ref,from_state,to_state)
      values (v,'listing_outreach','listing',new.id,new.ref,old.outreach_status::text,new.outreach_status::text);
    end if;

  elsif tg_table_name = 'profiles' then
    if new.verification_level is distinct from old.verification_level then
      insert into admin_actions(actor,action,subject_type,subject_id,subject_ref,from_state,to_state)
      values (v,'profile_level','profile',new.id,new.first_name,old.verification_level::text,new.verification_level::text);
    end if;
    if new.is_blocked is distinct from old.is_blocked then
      insert into admin_actions(actor,action,subject_type,subject_id,subject_ref,from_state,to_state)
      values (v, case when new.is_blocked then 'profile_block' else 'profile_unblock' end,
              'profile',new.id,new.first_name,old.is_blocked::text,new.is_blocked::text);
    end if;

  elsif tg_table_name = 'reports' then
    if new.status is distinct from old.status then
      insert into admin_actions(actor,action,subject_type,subject_id,from_state,to_state,reason,meta)
      values (v,'report_status','report',new.id,old.status::text,new.status::text,new.action_note,
              jsonb_build_object('category', new.category, 'listing_id', new.listing_id));
    end if;

  elsif tg_table_name = 'owner_fees' then
    if new.status is distinct from old.status then
      insert into admin_actions(actor,action,subject_type,subject_id,from_state,to_state,reason,meta)
      values (v,'fee_status','fee',new.id,old.status::text,new.status::text,new.note,
              jsonb_build_object('amount_due', new.amount_due, 'listing_id', new.listing_id));
    end if;

  elsif tg_table_name = 'contact_requests' then
    if new.status is distinct from old.status then
      insert into admin_actions(actor,action,subject_type,subject_id,from_state,to_state,reason,meta)
      values (v,'contact_status','contact',new.id,old.status::text,new.status::text,new.agent_notes,
              jsonb_build_object('listing_id', new.listing_id));
    end if;

  elsif tg_table_name = 'seeker_requests' then
    if new.status is distinct from old.status then
      insert into admin_actions(actor,action,subject_type,subject_id,subject_ref,from_state,to_state)
      values (v,'request_status','request',new.id,new.ref,old.status::text,new.status::text);
    end if;
    if new.outreach_status is distinct from old.outreach_status then
      insert into admin_actions(actor,action,subject_type,subject_id,subject_ref,from_state,to_state)
      values (v,'request_outreach','request',new.id,new.ref,old.outreach_status::text,new.outreach_status::text);
    end if;

  elsif tg_table_name = 'settings' then
    if new.value is distinct from old.value then
      insert into admin_actions(actor,action,subject_type,subject_ref,from_state,to_state)
      values (v,'setting_change','setting',new.key,old.value #>> '{}',new.value #>> '{}');
    end if;

  elsif tg_table_name = 'listing_safety' then
    insert into admin_actions(actor,action,subject_type,subject_id,to_state,meta)
    values (v,'field_visit','listing',new.listing_id,new.visit_date::text,
            jsonb_build_object('no_indoor_cameras', new.no_indoor_cameras,
                               'door_lock', new.door_lock,
                               'room_exists', new.room_exists,
                               'photos_match', new.photos_match));
  end if;
  return null;
end $$;

drop trigger if exists trg_audit_requests on public.seeker_requests;
create trigger trg_audit_requests after update on public.seeker_requests for each row execute function audit_admin_change();

-- القاعدة ١٦: بدون p_actor — الفاعل من actor_name() مباشرة عبر app.actor
-- للمدقّق. القاعدة ١١: revoke من PUBLIC ثم grant صريح.
create or replace function public.admin_listing_outreach(p_id uuid, p_status outreach_status)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), 'admin'), true);
  update listings set outreach_status = p_status where id = p_id;
end $$;
revoke execute on function public.admin_listing_outreach(uuid, outreach_status) from public;
grant execute on function public.admin_listing_outreach(uuid, outreach_status) to authenticated, service_role;

create or replace function public.admin_request_outreach(p_id uuid, p_status outreach_status)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), 'admin'), true);
  update seeker_requests set outreach_status = p_status where id = p_id;
end $$;
revoke execute on function public.admin_request_outreach(uuid, outreach_status) from public;
grant execute on function public.admin_request_outreach(uuid, outreach_status) to authenticated, service_role;

-- الواجهات: outreach_status بذيل القائمة + إعادة ضبط security_invoker
-- (create or replace بيصفّرها لو ما انكتبت صراحة بنفس الأمر).
create or replace view v_admin_listings as
 SELECT l.id, l.ref, l.title, l.description, l.kind, l.status, l.verification, l.price, l.deposit,
    l.bills_included, l.gender_pol, l.furnished, l.rooms_total, l.occupants_now, l.occupants_note,
    l.available_from, l.min_stay_months, l.landmark, l.exact_address, l.images, l.reject_reason,
    l.published_at, l.expires_at, l.last_confirmed_at, l.rented_at, l.created_at, l.updated_at,
    l.view_count, l.confirm_token, l.city_id, c.name_ar AS city, l.area_id, a.name_ar AS area,
    p.id AS owner_id, p.first_name AS owner_name, p.phone AS owner_phone, p.verification_level AS owner_level,
    p.is_blocked AS owner_blocked, s.visit_date, s.room_exists, s.photos_match, s.door_lock,
    s.no_indoor_cameras, s.occupants_verified, s.exterior_lighting, s.gas_detector, s.notes AS safety_notes,
    (select count(*) from contact_requests cr where cr.listing_id = l.id) AS contacts,
    (select count(*) from contact_requests cr where cr.listing_id = l.id and cr.status='rented'::contact_status) AS rentals,
    (select count(*) from reports r where r.listing_id = l.id and r.status='open'::report_status) AS open_reports,
    (select count(*) from reviews rv where rv.listing_id = l.id) AS reviews_count,
    case when l.expires_at is null then null::integer else l.expires_at::date - current_date end AS days_left,
    s.private_bathroom, s.kitchen_access, s.heating, s.internet, s.emergency_exit, s.street_access, s.owner_met,
    l.features, l.review_token, l.video_verified_at, l.currency, l.bills_water, l.bills_electricity,
    l.bills_internet, l.rental_period, l.video_url, l.rented_via_platform, l.outreach_status
   FROM listings l
     JOIN cities c ON c.id = l.city_id
     JOIN areas a ON a.id = l.area_id
     LEFT JOIN profiles p ON p.id = l.owner_id
     LEFT JOIN listing_safety s ON s.listing_id = l.id;
alter view public.v_admin_listings set (security_invoker = on);

create or replace view v_admin_requests as
 SELECT r.id, r.ref, r.status, r.created_at, r.expires_at, c.id AS city_id, c.name_ar AS city, r.area_ids,
    (select coalesce(string_agg(a.name_ar, '، ' order by a.sort_order), '—') from areas a where a.id = any(r.area_ids)) AS areas_ar,
    r.budget_max, r.gender, r.kind_pref, r.furnished_pref, r.move_in_date, r.min_stay_months, r.smoker,
    r.lifestyle_tags, r.note, p.id AS seeker_id, p.first_name, p.full_name, p.phone, p.occupation, p.org_name,
    coalesce(p.verification_level::integer, 0) AS seeker_level, p.is_blocked, r.rental_period_pref, r.rooms_pref,
    r.outreach_status
   FROM seeker_requests r
     JOIN cities c ON c.id = r.city_id
     LEFT JOIN profiles p ON p.id = r.seeker_id;
alter view public.v_admin_requests set (security_invoker = on);

notify pgrst, 'reload schema';
