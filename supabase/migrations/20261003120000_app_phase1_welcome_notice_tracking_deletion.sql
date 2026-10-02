-- مرحلة ١ من تعديلات تطبيق سكنّا — ثلاث إضافات منطقية بدون أي تعديل على
-- الموقع العام أو مركز التحكم البصري:
--   ١) إشعار ترحيبي عند تسجيل بروفايل جديد مربوط بحساب (link_account_role).
--   ٢) طلب حذف ذاتي (مالك/باحث) يراجعه الطاقم — عمود + RPCs + ظهور بلوحة الطاقم.
--   ٣) تغذية لوحتي "حسابي" الذاتيتين (my_owner_dashboard/my_seeker_dashboard)
--      بالحقول اللازمة لصفحة تتبّع الحالة بالتطبيق (outreach_status، تاريخ
--      الزيارة الميدانية، حالة طلب الحذف).

-- ═══════════════ ١) إشعار ترحيبي عند تسجيل بروفايل جديد ═══════════════
-- لو هاد أول بروفايل إطلاقاً على الحساب: رسالة "تسجيل حساب" (نفس نص الطلب).
-- لو الحساب عنده بروفايل أصلاً وبس عم يفعّل صفة إضافية: رسالة أخف مخصّصة.
-- التوقيع نفسه (text,text,text) — create or replace بدون drop.
create or replace function link_account_role(p_role text, p_name text, p_phone text) returns uuid
language plpgsql security definer set search_path to 'public' as $$
declare v_uid uuid := auth.uid(); v_id uuid; v_first_ever boolean;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
  if p_role not in ('owner','seeker') then raise exception 'صفة غير صحيحة'; end if;
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' then
    raise exception 'الاسم والرقم مطلوبان';
  end if;

  select id into v_id from profiles where account_uid = v_uid and role = p_role::user_role;
  if v_id is not null then return v_id; end if;

  v_first_ever := not exists (select 1 from profiles where account_uid = v_uid);

  insert into profiles (role, first_name, phone, account_uid)
  values (p_role::user_role, trim(p_name), trim(p_phone), v_uid)
  returning id into v_id;

  insert into notifications(account_uid, event_type, title, body)
  values (
    v_uid,
    'account_registered',
    case when v_first_ever then 'تم تسجيل حسابك بنجاح' else 'تم تفعيل صفة جديدة على حسابك' end,
    case when v_first_ever then 'سيتواصل معك الطاقم لتأكيد معلوماتك.'
         else 'صفة ' || (case p_role when 'owner' then 'مالك' else 'باحث عن سكن' end) || ' صارت مفعّلة على حسابك.'
    end
  );

  return v_id;
end $$;
revoke execute on function link_account_role(text,text,text) from public;
grant execute on function link_account_role(text,text,text) to authenticated;

-- ═══════════════ ٢) طلب حذف ذاتي — يراجعه الطاقم ═══════════════
alter table listings add column deletion_requested_at timestamptz;
alter table seeker_requests add column deletion_requested_at timestamptz;

-- المالك: يطلب حذف إعلانه. تحقّق ملكية عبر account_uid، لا سبب مطلوب،
-- idempotent (طلب مكرر ما بيحدّث الوقت). الحذف الفعلي يبقى admin_delete_listing
-- (موجودة أصلاً، مربوطة بزر بمركز التحكم) — هاي الدالة بس تعلّم الطلب.
create or replace function public.my_request_listing_deletion(p_listing_id uuid)
returns void
language plpgsql security definer set search_path to 'public' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
  if not exists (
    select 1 from listings l join profiles p on p.id = l.owner_id
    where l.id = p_listing_id and p.account_uid = v_uid
  ) then
    raise exception 'إعلان غير موجود أو غير تابع لحسابك';
  end if;

  update listings set deletion_requested_at = coalesce(deletion_requested_at, now())
  where id = p_listing_id;

  insert into admin_actions(actor, action, subject_type, subject_id, to_state)
  select 'owner_self', 'deletion_requested', 'listing', p_listing_id, 'requested'
  where not exists (
    select 1 from admin_actions
     where subject_type = 'listing' and subject_id = p_listing_id and action = 'deletion_requested'
  );
end $$;
revoke all on function public.my_request_listing_deletion(uuid) from public;
grant execute on function public.my_request_listing_deletion(uuid) to authenticated;

-- الباحث: يطلب حذف طلبه، بنفس المبدأ.
create or replace function public.my_request_seeker_deletion(p_request_id uuid)
returns void
language plpgsql security definer set search_path to 'public' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
  if not exists (
    select 1 from seeker_requests r join profiles p on p.id = r.seeker_id
    where r.id = p_request_id and p.account_uid = v_uid
  ) then
    raise exception 'طلب غير موجود أو غير تابع لحسابك';
  end if;

  update seeker_requests set deletion_requested_at = coalesce(deletion_requested_at, now())
  where id = p_request_id;

  insert into admin_actions(actor, action, subject_type, subject_id, to_state)
  select 'seeker_self', 'deletion_requested', 'seeker_request', p_request_id, 'requested'
  where not exists (
    select 1 from admin_actions
     where subject_type = 'seeker_request' and subject_id = p_request_id and action = 'deletion_requested'
  );
end $$;
revoke all on function public.my_request_seeker_deletion(uuid) from public;
grant execute on function public.my_request_seeker_deletion(uuid) to authenticated;

-- الطاقم: تجاهل طلب الحذف (قرروا الاحتفاظ بالإعلان/الطلب) بدون حذف فعلي.
-- الحذف الفعلي يبقى admin_delete_listing/admin_delete_request الموجودتان أصلاً.
create or replace function public.admin_dismiss_listing_deletion(p_id uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  update listings set deletion_requested_at = null where id = p_id;
  insert into admin_actions(actor, action, subject_type, subject_id, to_state)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'deletion_dismissed', 'listing', p_id, 'dismissed');
end $$;
revoke all on function public.admin_dismiss_listing_deletion(uuid) from public;
grant execute on function public.admin_dismiss_listing_deletion(uuid) to authenticated, service_role;

create or replace function public.admin_dismiss_request_deletion(p_id uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  update seeker_requests set deletion_requested_at = null where id = p_id;
  insert into admin_actions(actor, action, subject_type, subject_id, to_state)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'deletion_dismissed', 'seeker_request', p_id, 'dismissed');
end $$;
revoke all on function public.admin_dismiss_request_deletion(uuid) from public;
grant execute on function public.admin_dismiss_request_deletion(uuid) to authenticated, service_role;

-- ظهور طلب الحذف بمركز التحكم (بذيل القائمة، وإعادة ضبط security_invoker
-- فوراً — create or replace view بيصفّرها لو ما انكتبت صراحة بنفس الأمر).
create or replace view public.v_admin_listings as
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
    l.bills_internet, l.rental_period, l.video_url, l.rented_via_platform, l.outreach_status,
    l.neighborhood_id, n.name_ar AS neighborhood, l.deletion_requested_at
   FROM listings l
     JOIN cities c ON c.id = l.city_id
     JOIN areas a ON a.id = l.area_id
     LEFT JOIN profiles p ON p.id = l.owner_id
     LEFT JOIN listing_safety s ON s.listing_id = l.id
     LEFT JOIN neighborhoods n ON n.id = l.neighborhood_id;
alter view public.v_admin_listings set (security_invoker = on);

create or replace view public.v_admin_requests as
 SELECT r.id, r.ref, r.status, r.created_at, r.expires_at, c.id AS city_id, c.name_ar AS city, r.area_ids,
    (select coalesce(string_agg(a.name_ar, '، ' order by a.sort_order), '—') from areas a where a.id = any(r.area_ids)) AS areas_ar,
    r.budget_max, r.gender, r.kind_pref, r.furnished_pref, r.move_in_date, r.min_stay_months, r.smoker,
    r.lifestyle_tags, r.note, p.id AS seeker_id, p.first_name, p.full_name, p.phone, p.occupation, p.org_name,
    coalesce(p.verification_level::integer, 0) AS seeker_level, p.is_blocked, r.rental_period_pref, r.rooms_pref,
    r.outreach_status, r.neighborhood_ids,
    (select coalesce(string_agg(n.name_ar, '، ' order by n.sort_order), '—') from neighborhoods n where n.id = any(r.neighborhood_ids)) AS neighborhoods_ar,
    r.deletion_requested_at
   FROM seeker_requests r
     JOIN cities c ON c.id = r.city_id
     LEFT JOIN profiles p ON p.id = r.seeker_id;
alter view public.v_admin_requests set (security_invoker = on);

-- ═══════════════ ٣) لوحتا "حسابي" الذاتيتان — حقول صفحة تتبّع الحالة ═══════════════
-- أضيف: outreach_status (المؤشر العملي لـ"تم التأكيد هاتفياً")، visit_date
-- (تاريخ الزيارة الميدانية لو حصلت)، deletion_requested_at، و id لطلبات الباحث
-- (كان غائباً — لازم لاستدعاء my_request_seeker_deletion من التطبيق).
create or replace function public.my_owner_dashboard()
returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare v_uid uuid := auth.uid(); v_owner uuid;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
  select id into v_owner from profiles where account_uid = v_uid and role = 'owner';
  if v_owner is null then
    return jsonb_build_object('listings','[]'::jsonb,'requests','[]'::jsonb);
  end if;

  return jsonb_build_object(
    'listings', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', l.id, 'ref', l.ref, 'title', l.title, 'status', l.status,
        'verification', l.verification, 'price', l.price, 'currency', l.currency,
        'city', c.name_ar, 'area', a.name_ar, 'neighborhood', n.name_ar,
        'published_at', l.published_at, 'expires_at', l.expires_at,
        'days_left', case when l.expires_at is null then null
                          else l.expires_at::date - current_date end,
        'view_count', l.view_count, 'reject_reason', l.reject_reason,
        'confirm_token', l.confirm_token,
        'outreach_status', l.outreach_status,
        'visit_date', s.visit_date,
        'video_verified_at', l.video_verified_at,
        'deletion_requested_at', l.deletion_requested_at
      ) order by l.created_at desc), '[]'::jsonb)
      from listings l join cities c on c.id=l.city_id join areas a on a.id=l.area_id
      left join neighborhoods n on n.id = l.neighborhood_id
      left join listing_safety s on s.listing_id = l.id
      where l.owner_id = v_owner
    ),
    'requests', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'listing_ref', l.ref, 'listing_title', l.title,
        'seeker_name', cr.seeker_name,
        'seeker_phone', case when cr.status <> 'new' then cr.seeker_phone else null end,
        'status', cr.status, 'created_at', cr.created_at
      ) order by cr.created_at desc), '[]'::jsonb)
      from contact_requests cr join listings l on l.id = cr.listing_id
      where l.owner_id = v_owner
    )
  );
end $$;

create or replace function public.my_seeker_dashboard()
returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare v_uid uuid := auth.uid(); v_seeker uuid;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
  select id into v_seeker from profiles where account_uid = v_uid and role = 'seeker';
  if v_seeker is null then
    return jsonb_build_object('requests','[]'::jsonb,'saved','[]'::jsonb);
  end if;

  return jsonb_build_object(
    'requests', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', r.id, 'ref', r.ref, 'status', r.status, 'city', c.name_ar,
        'budget_max', r.budget_max, 'created_at', r.created_at,
        'expires_at', r.expires_at, 'outreach_status', r.outreach_status,
        'deletion_requested_at', r.deletion_requested_at
      ) order by r.created_at desc), '[]'::jsonb)
      from seeker_requests r join cities c on c.id=r.city_id
      where r.seeker_id = v_seeker
    ),
    'saved', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'ref', v.ref, 'title', v.title, 'city', v.city, 'area', v.area, 'neighborhood', v.neighborhood,
        'price', v.price, 'currency', v.currency, 'status', case when v.id is null then 'removed' else 'active' end
      ) order by s.created_at desc), '[]'::jsonb)
      from saved_listings s
      left join v_listings_public v on v.id = s.listing_id
      where s.account_uid = v_uid
    )
  );
end $$;

notify pgrst, 'reload schema';
