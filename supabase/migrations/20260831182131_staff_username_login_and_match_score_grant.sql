-- ═══════════════════════════════════════════════════════════
-- ١) إصلاح: v_reverse_matches صارت security_invoker، فصارت
--    تتحقق من صلاحية الفاعل (authenticated) على sakan_match_score
--    نفسها بدل صلاحية مالك الواجهة. الدالة كانت service_role فقط
--    فطلعت "permission denied for function sakan_match_score".
-- ═══════════════════════════════════════════════════════════
revoke execute on function sakan_match_score(
  integer[], numeric, gender_type, listing_kind, date,
  integer, numeric, gender_policy, listing_kind, date
) from public;
grant execute on function sakan_match_score(
  integer[], numeric, gender_type, listing_kind, date,
  integer, numeric, gender_policy, listing_kind, date
) to authenticated, service_role;

-- ═══════════════════════════════════════════════════════════
-- ٢) دعم اسم مستخدم بديل عن الإيميل بشاشة الدخول
-- ═══════════════════════════════════════════════════════════
alter table staff add column if not exists username text;
create unique index if not exists staff_username_lower_idx
  on staff (lower(username)) where username is not null;

drop function if exists link_staff(text,text,text);

create or replace function link_staff(
  p_email text, p_name text, p_role text, p_username text default null
) returns uuid
language plpgsql security definer set search_path = public, auth as $$
declare v_id uuid;
begin
  select id into v_id from auth.users where lower(email) = lower(btrim(p_email));
  if v_id is null then
    raise exception 'ما في حساب Auth بهالإيميل: %. اعمله من Dashboard أولاً (Auto Confirm).', p_email;
  end if;

  insert into staff (id, email, name, role, username)
  values (v_id, lower(btrim(p_email)), btrim(p_name), p_role::staff_role,
          nullif(lower(btrim(p_username)), ''))
  on conflict (id) do update set
    email = excluded.email, name = excluded.name,
    role = excluded.role, username = excluded.username, is_active = true;

  return v_id;
end $$;

revoke execute on function link_staff(text,text,text,text) from public;
revoke execute on function link_staff(text,text,text,text) from anon;
revoke execute on function link_staff(text,text,text,text) from authenticated;
grant  execute on function link_staff(text,text,text,text) to service_role;

-- تحويل اسم مستخدم لإيميل قبل تسجيل الدخول (المتصفح لسا anon
-- بهالمرحلة). ما بترجّع غير الإيميل — صفر تسريب لأي عمود تاني.
create or replace function staff_email_for_username(p_username text) returns text
language sql stable security definer set search_path = public as $$
  select email from staff
   where lower(username) = lower(btrim(p_username)) and is_active
   limit 1;
$$;

revoke execute on function staff_email_for_username(text) from public;
grant  execute on function staff_email_for_username(text) to anon, authenticated, service_role;

notify pgrst, 'reload schema';
