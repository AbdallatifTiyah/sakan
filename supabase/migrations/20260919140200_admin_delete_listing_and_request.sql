-- حذف نهائي لإعلان أو طلب باحث من مركز التحكم — بكبسة زر، بدون سبب يُكتب.
-- إعلان له رسوم مسجّلة (owner_fees) ممنوع حذفه: الحذف CASCADE بيمسح السجل المالي معه.
-- يبقى يتسجّل بـadmin_actions تلقائياً (from_state/to_state) — بدون إدخال يدوي من الطاقم.

create or replace function public.admin_delete_listing(p_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_status text;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;

  select status::text into v_status from listings where id = p_id;
  if not found then
    raise exception 'إعلان غير موجود';
  end if;

  if exists (select 1 from owner_fees where listing_id = p_id) then
    raise exception 'لا يمكن حذف إعلان له رسوم مسجّلة';
  end if;

  insert into admin_actions (actor, action, subject_type, subject_id, from_state, to_state)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'delete_listing', 'listing', p_id, v_status, 'deleted');

  delete from listings where id = p_id;
end $$;

revoke all on function public.admin_delete_listing(uuid) from public;
grant execute on function public.admin_delete_listing(uuid) to authenticated, service_role;

create or replace function public.admin_delete_request(p_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_status text;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;

  select status::text into v_status from seeker_requests where id = p_id;
  if not found then
    raise exception 'طلب غير موجود';
  end if;

  insert into admin_actions (actor, action, subject_type, subject_id, from_state, to_state)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'delete_request', 'seeker_request', p_id, v_status, 'deleted');

  delete from seeker_requests where id = p_id;
end $$;

revoke all on function public.admin_delete_request(uuid) from public;
grant execute on function public.admin_delete_request(uuid) to authenticated, service_role;
