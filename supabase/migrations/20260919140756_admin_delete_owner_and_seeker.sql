-- حذف نهائي لملف مالك أو باحث من مركز التحكم — بكبسة زر، بدون سبب يُكتب.
-- مالك له إعلانات ممنوع حذفه (listings.owner_id → SET NULL بيتيم الإعلان من مالكه).
-- باحث له طلبات ممنوع حذفه (seeker_requests.seeker_id → CASCADE بيمسح طلباته بصمت).
-- الطاقم لازم يحذف الإعلانات/الطلبات أولاً (admin_delete_listing/admin_delete_request)
-- قبل ما يقدر يحذف الملف نفسه — نفس سلسلة الأمان.

create or replace function public.admin_delete_owner(p_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_role user_role;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;

  select role into v_role from profiles where id = p_id;
  if not found then
    raise exception 'ملف غير موجود';
  end if;
  if v_role <> 'owner' then
    raise exception 'هذا الملف مش مالك';
  end if;

  if exists (select 1 from listings where owner_id = p_id) then
    raise exception 'لا يمكن حذف مالك له إعلانات — احذف إعلاناته أولاً';
  end if;

  insert into admin_actions (actor, action, subject_type, subject_id, from_state, to_state)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'delete_owner', 'profile', p_id, v_role::text, 'deleted');

  delete from profiles where id = p_id;
end $$;

revoke all on function public.admin_delete_owner(uuid) from public;
grant execute on function public.admin_delete_owner(uuid) to authenticated, service_role;

create or replace function public.admin_delete_seeker(p_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_role user_role;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;

  select role into v_role from profiles where id = p_id;
  if not found then
    raise exception 'ملف غير موجود';
  end if;
  if v_role <> 'seeker' then
    raise exception 'هذا الملف مش باحث';
  end if;

  if exists (select 1 from seeker_requests where seeker_id = p_id) then
    raise exception 'لا يمكن حذف باحث له طلبات — احذف طلباته أولاً';
  end if;

  insert into admin_actions (actor, action, subject_type, subject_id, from_state, to_state)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'delete_seeker', 'profile', p_id, v_role::text, 'deleted');

  delete from profiles where id = p_id;
end $$;

revoke all on function public.admin_delete_seeker(uuid) from public;
grant execute on function public.admin_delete_seeker(uuid) to authenticated, service_role;
