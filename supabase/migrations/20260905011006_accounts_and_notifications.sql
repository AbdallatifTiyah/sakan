-- ═══════════════ الحسابات: عمود ربط إضافي على profiles ═══════════════
alter table profiles add column account_uid uuid;
create index idx_profiles_account_uid on profiles(account_uid);
create unique index uq_profiles_account_role on profiles(account_uid, role) where account_uid is not null;

-- ═══════════════ جدول الإشعارات ═══════════════
create table notifications (
  id uuid primary key default gen_random_uuid(),
  account_uid uuid not null,
  event_type text not null,
  title text not null,
  body text,
  listing_ref text,
  request_ref text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index idx_notifications_account on notifications(account_uid, created_at desc);

alter table notifications enable row level security;
create policy self_read on notifications for select to authenticated using (account_uid = auth.uid());
create policy self_update on notifications for update to authenticated
  using (account_uid = auth.uid()) with check (account_uid = auth.uid());
create policy staff_read on notifications for select to authenticated using (is_staff());

grant select, update on notifications to authenticated;
revoke all on notifications from anon;

-- ═══════════════ جدول الوحدات المحفوظة (للباحث) ═══════════════
create table saved_listings (
  account_uid uuid not null,
  listing_id uuid not null references listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (account_uid, listing_id)
);
alter table saved_listings enable row level security;
create policy self_all on saved_listings for all to authenticated
  using (account_uid = auth.uid()) with check (account_uid = auth.uid());

grant select, insert, delete on saved_listings to authenticated;
revoke all on saved_listings from anon;

-- ═══════════════ محفزات الإشعارات ═══════════════

-- طلب تواصل جديد: يُبلّغ صاحب الإعلان (إن كان حسابه مربوطاً)، أو الباحث صاحب الطلب لو التواصل عبر seeker_requests
create or replace function notify_contact_request() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare v_acct uuid; v_ref text;
begin
  if new.listing_id is not null then
    select p.account_uid, l.ref into v_acct, v_ref
      from listings l join profiles p on p.id = l.owner_id
     where l.id = new.listing_id;
    if v_acct is not null then
      insert into notifications(account_uid, event_type, title, body, listing_ref)
      values (v_acct, 'contact_received', 'وصل طلب تواصل جديد',
              'وصل طلب تواصل جديد على إعلانك ' || coalesce(v_ref,''), v_ref);
    end if;
  end if;

  if new.request_id is not null then
    select p.account_uid, r.ref into v_acct, v_ref
      from seeker_requests r join profiles p on p.id = r.seeker_id
     where r.id = new.request_id;
    if v_acct is not null then
      insert into notifications(account_uid, event_type, title, body, request_ref)
      values (v_acct, 'contact_received', 'وصل تواصل بخصوص طلبك',
              'وصل تواصل من مالك سكن بخصوص طلبك ' || coalesce(v_ref,''), v_ref);
    end if;
  end if;
  return new;
end $$;
revoke execute on function notify_contact_request() from public;

create trigger trg_notify_contact_request
  after insert on contact_requests
  for each row execute function notify_contact_request();

-- تغيّر حالة/توثيق إعلان، أو نشره (فرصة تطابق لطلبات باحثين منشورة)
create or replace function notify_listing_change() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare v_acct uuid; v_status_txt text; v_r record;
begin
  select account_uid into v_acct from profiles where id = new.owner_id;

  if v_acct is not null and old.status is distinct from new.status then
    v_status_txt := case new.status
      when 'published' then 'نُشر إعلانك'
      when 'rejected'  then 'رُفض إعلانك'
      when 'reserved'  then 'أصبح إعلانك محجوزاً'
      when 'rented'    then 'تم تأجير إعلانك'
      when 'expired'   then 'انتهت صلاحية إعلانك'
      else 'تغيّرت حالة إعلانك'
    end;
    insert into notifications(account_uid, event_type, title, body, listing_ref)
    values (v_acct, 'listing_status_changed', v_status_txt, 'الإعلان ' || new.ref, new.ref);
  end if;

  if v_acct is not null and old.verification is distinct from new.verification then
    insert into notifications(account_uid, event_type, title, body, listing_ref)
    values (v_acct, 'listing_verification_changed', 'تغيّر مستوى توثيق إعلانك',
            'الإعلان ' || new.ref, new.ref);
  end if;

  if new.status = 'published' and old.status is distinct from 'published' then
    for v_r in
      select r.ref, p.account_uid as seeker_acct
        from seeker_requests r
        join profiles p on p.id = r.seeker_id
       where r.status = 'published'
         and p.account_uid is not null
         and r.city_id = new.city_id
         and (r.area_ids = '{}' or new.area_id = any(r.area_ids))
         and r.budget_max >= new.price
         and (r.kind_pref is null or r.kind_pref = new.kind)
    loop
      insert into notifications(account_uid, event_type, title, body, listing_ref, request_ref)
      values (v_r.seeker_acct, 'new_matching_listing', 'وصل سكن يطابق طلبك',
              'إعلان جديد يطابق طلبك ' || v_r.ref, new.ref, v_r.ref);
    end loop;
  end if;

  return new;
end $$;
revoke execute on function notify_listing_change() from public;

create trigger trg_notify_listing_change
  after update of status, verification on listings
  for each row execute function notify_listing_change();

-- نشر طلب الباحث
create or replace function notify_request_published() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare v_acct uuid;
begin
  if new.status = 'published' and old.status is distinct from 'published' then
    select account_uid into v_acct from profiles where id = new.seeker_id;
    if v_acct is not null then
      insert into notifications(account_uid, event_type, title, body, request_ref)
      values (v_acct, 'request_published', 'نُشر طلبك', 'طلبك ' || new.ref || ' أصبح منشوراً', new.ref);
    end if;
  end if;
  return new;
end $$;
revoke execute on function notify_request_published() from public;

create trigger trg_notify_request_published
  after update of status on seeker_requests
  for each row execute function notify_request_published();

-- اقتراب انتهاء الإعلان — دالة مجدولة (cron)، مش RPC عام
create or replace function notify_expiring_soon() returns integer
language plpgsql security definer set search_path to 'public' as $$
declare n int;
begin
  with due as (
    select l.ref, p.account_uid
      from listings l
      join profiles p on p.id = l.owner_id
     where l.status = 'published'
       and p.account_uid is not null
       and l.expires_at is not null
       and l.expires_at <= now() + (setting_num('expiring_soon_days',3) || ' days')::interval
       and l.expires_at > now()
       and not exists (
         select 1 from notifications nf
          where nf.listing_ref = l.ref and nf.event_type = 'listing_expiring_soon'
            and nf.created_at > now() - (setting_num('expiring_soon_days',3) || ' days')::interval
       )
  )
  insert into notifications(account_uid, event_type, title, body, listing_ref)
  select account_uid, 'listing_expiring_soon', 'إعلانك على وشك الانتهاء',
         'إعلانك ' || ref || ' ينتهي قريباً — أكّد أنه ما زال متاحاً', ref
    from due;
  get diagnostics n = row_count;
  return n;
end $$;
revoke execute on function notify_expiring_soon() from public;

select cron.schedule('notify-expiring-soon', '10 3 * * *', $cron$select notify_expiring_soon();$cron$);

-- ═══════════════ واجهات الحساب الذاتية (authenticated فقط) ═══════════════

create or replace function link_account_role(p_role text, p_name text, p_phone text) returns uuid
language plpgsql security definer set search_path to 'public' as $$
declare v_uid uuid := auth.uid(); v_id uuid;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
  if p_role not in ('owner','seeker') then raise exception 'صفة غير صحيحة'; end if;
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' then
    raise exception 'الاسم والرقم مطلوبان';
  end if;

  select id into v_id from profiles where account_uid = v_uid and role = p_role::user_role;
  if v_id is not null then return v_id; end if;

  insert into profiles (role, first_name, phone, account_uid)
  values (p_role::user_role, trim(p_name), trim(p_phone), v_uid)
  returning id into v_id;
  return v_id;
end $$;
revoke execute on function link_account_role(text,text,text) from public;
grant execute on function link_account_role(text,text,text) to authenticated;

create or replace function my_profile() returns jsonb
language sql security definer set search_path to 'public' as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'role', role, 'first_name', first_name, 'phone', phone,
           'verification_level', verification_level, 'is_blocked', is_blocked,
           'created_at', created_at
         )), '[]'::jsonb)
  from profiles where account_uid = auth.uid();
$$;
revoke execute on function my_profile() from public;
grant execute on function my_profile() to authenticated;

create or replace function my_owner_dashboard() returns jsonb
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
        'verification', l.verification, 'price', l.price,
        'city', c.name_ar, 'area', a.name_ar,
        'published_at', l.published_at, 'expires_at', l.expires_at,
        'days_left', case when l.expires_at is null then null
                          else l.expires_at::date - current_date end,
        'view_count', l.view_count, 'reject_reason', l.reject_reason,
        'confirm_token', l.confirm_token
      ) order by l.created_at desc), '[]'::jsonb)
      from listings l join cities c on c.id=l.city_id join areas a on a.id=l.area_id
      where l.owner_id = v_owner
    ),
    'requests', (
      -- رقم الباحث ما بيظهر إلا بعد ما حالة الطلب تصير غير new — نفس بوابة owner_dashboard(token)
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
revoke execute on function my_owner_dashboard() from public;
grant execute on function my_owner_dashboard() to authenticated;

create or replace function my_seeker_dashboard() returns jsonb
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
        'ref', r.ref, 'status', r.status, 'city', c.name_ar,
        'budget_max', r.budget_max, 'created_at', r.created_at,
        'expires_at', r.expires_at
      ) order by r.created_at desc), '[]'::jsonb)
      from seeker_requests r join cities c on c.id=r.city_id
      where r.seeker_id = v_seeker
    ),
    'saved', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'ref', v.ref, 'title', v.title, 'city', v.city, 'area', v.area,
        'price', v.price, 'status', case when v.id is null then 'removed' else 'active' end
      ) order by s.created_at desc), '[]'::jsonb)
      from saved_listings s
      left join v_listings_public v on v.id = s.listing_id
      where s.account_uid = v_uid
    )
  );
end $$;
revoke execute on function my_seeker_dashboard() from public;
grant execute on function my_seeker_dashboard() to authenticated;

-- ═══════════════ واجهات الطاقم (is_staff فقط) ═══════════════

create or replace function admin_list_accounts() returns jsonb
language plpgsql security definer set search_path to 'public', 'auth' as $$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'ممنوع';
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'auth_uid', u.id, 'email', u.email, 'created_at', u.created_at,
      'profiles', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', p.id, 'role', p.role, 'first_name', p.first_name,
          'phone', p.phone, 'is_blocked', p.is_blocked,
          'verification_level', p.verification_level
        )), '[]'::jsonb)
        from profiles p where p.account_uid = u.id
      )
    ) order by u.created_at desc), '[]'::jsonb)
    from auth.users u
    where exists (select 1 from profiles p where p.account_uid = u.id)
  );
end $$;
revoke execute on function admin_list_accounts() from public;
grant execute on function admin_list_accounts() to authenticated, service_role;

create or replace function admin_list_notifications(p_limit integer default 100) returns jsonb
language plpgsql security definer set search_path to 'public' as $$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'ممنوع';
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', id, 'account_uid', account_uid, 'event_type', event_type,
      'title', title, 'body', body, 'listing_ref', listing_ref,
      'request_ref', request_ref, 'is_read', is_read, 'created_at', created_at
    ) order by created_at desc), '[]'::jsonb)
    from (select * from notifications order by created_at desc limit p_limit) t
  );
end $$;
revoke execute on function admin_list_notifications(integer) from public;
grant execute on function admin_list_notifications(integer) to authenticated, service_role;

create or replace function admin_send_notification(p_account_uid uuid, p_title text, p_body text) returns void
language plpgsql security definer set search_path to 'public' as $$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'ممنوع';
  end if;
  if coalesce(trim(p_title),'')='' then raise exception 'العنوان مطلوب'; end if;
  insert into notifications(account_uid, event_type, title, body)
  values (p_account_uid, 'manual_staff', trim(p_title), nullif(trim(coalesce(p_body,'')),''));
  perform admin_log('notification_sent','account', p_account_uid::text, p_title);
end $$;
revoke execute on function admin_send_notification(uuid,text,text) from public;
grant execute on function admin_send_notification(uuid,text,text) to authenticated, service_role;

-- ربط سجل profiles قائم (بدون حساب) بحساب مصادَق عليه — يدوي وبعد تأكد الطاقم هاتفياً فقط
create or replace function admin_link_profile(p_profile_id uuid, p_account_uid uuid) returns void
language plpgsql security definer set search_path to 'public' as $$
declare v_role user_role;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'ممنوع';
  end if;
  select role into v_role from profiles where id = p_profile_id;
  if v_role is null then raise exception 'سجل غير موجود'; end if;
  if exists (select 1 from profiles where account_uid = p_account_uid and role = v_role and id <> p_profile_id) then
    raise exception 'هذا الحساب مربوط أصلاً بسجل من نفس الصفة';
  end if;
  update profiles set account_uid = p_account_uid where id = p_profile_id;
  perform admin_log('profile_linked','profile', p_profile_id::text, p_account_uid::text);
end $$;
revoke execute on function admin_link_profile(uuid,uuid) from public;
grant execute on function admin_link_profile(uuid,uuid) to authenticated, service_role;
