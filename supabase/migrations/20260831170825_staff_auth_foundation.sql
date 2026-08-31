-- ═══════════════════════════════════════════════════════════
-- نظام المستخدمين — الطبقة الأولى: الهوية والصلاحيات
--
-- الهدف: شيل مفتاح service_role من متصفح المندوب.
-- الطريقة: Supabase Auth + جدول staff + security_invoker على
-- الواجهات الإدارية، فتنطبّق RLS على الجداول الأساسية.
--
-- ملاحظة: service_role بيتجاوز RLS، فمركز التحكم الحالي
-- بيضل شغّال بدون كسر خلال فترة الانتقال.
-- ═══════════════════════════════════════════════════════════

do $$ begin
  create type staff_role as enum ('admin','agent');
exception when duplicate_object then null; end $$;

create table if not exists staff (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text not null unique,
  name       text not null,
  role       staff_role not null default 'agent',
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

alter table staff enable row level security;
-- صفر سياسات عن قصد: ولا دور بيقرأ الجدول مباشرة.
-- الوصول الوحيد عبر is_staff()/is_admin() وهنّ security definer.
grant all on staff to service_role;


-- ── دوال الهوية ───────────────────────────────────────────
-- security definer عشان تتجاوز RLS على staff نفسه (وإلا
-- بيصير استدعاء دائري: السياسة بتنادي الدالة والدالة بتقرأ
-- الجدول اللي عليه السياسة).

create or replace function is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from staff s
     where s.id = auth.uid() and s.is_active
  );
$$;

create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from staff s
     where s.id = auth.uid() and s.is_active and s.role = 'admin'
  );
$$;

-- اسم الفاعل للسجل — بيجي من الهوية مش من حقل نصي بيكتبه
-- المستخدم. هيك المندوب ما بيقدر يوقّع باسم غيره.
create or replace function actor_name() returns text
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select s.name from staff s where s.id = auth.uid()),
    'service'
  );
$$;

revoke execute on function is_staff()    from public;
revoke execute on function is_admin()    from public;
revoke execute on function actor_name()  from public;
grant  execute on function is_staff()    to authenticated, service_role;
grant  execute on function is_admin()    to authenticated, service_role;
grant  execute on function actor_name()  to authenticated, service_role;


-- ── ربط حساب Auth بجدول staff ─────────────────────────────
-- بتنستدعى بعد ما تنعمل الحسابات من Supabase Dashboard.
create or replace function link_staff(p_email text, p_name text, p_role text)
returns uuid
language plpgsql security definer set search_path = public, auth as $$
declare v_id uuid;
begin
  select id into v_id from auth.users where lower(email) = lower(btrim(p_email));
  if v_id is null then
    raise exception 'ما في حساب Auth بهالإيميل: %. اعمله من Dashboard أولاً (Auto Confirm).', p_email;
  end if;

  insert into staff (id, email, name, role)
  values (v_id, lower(btrim(p_email)), btrim(p_name), p_role::staff_role)
  on conflict (id) do update set
    email = excluded.email, name = excluded.name,
    role = excluded.role, is_active = true;

  return v_id;
end $$;

revoke execute on function link_staff(text,text,text) from public;
revoke execute on function link_staff(text,text,text) from anon;
revoke execute on function link_staff(text,text,text) from authenticated;
grant  execute on function link_staff(text,text,text) to service_role;


-- ── سياسات قراءة للطاقم على الجداول الأساسية ──────────────
-- ضرورية لأن الواجهات رح تصير security_invoker: بتشتغل
-- بصلاحية المستدعي، يعني RLS بتنطبّق.
do $$
declare t text;
begin
  foreach t in array array[
    'listings','profiles','seeker_requests','contact_requests','reports',
    'reviews','owner_fees','listing_safety','admin_actions','events',
    'verification_log','promo_codes','settings','cities','areas','pages'
  ] loop
    execute format('drop policy if exists staff_read on %I', t);
    execute format(
      'create policy staff_read on %I for select to authenticated using (is_staff())', t);
    execute format('grant select on %I to authenticated', t);
  end loop;
end $$;
