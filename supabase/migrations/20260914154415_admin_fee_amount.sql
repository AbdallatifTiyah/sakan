create or replace function public.admin_fee_amount(p_fee_id uuid, p_amount numeric, p_reason text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_old numeric;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;

  select amount_due into v_old from owner_fees where id = p_fee_id;
  if not found then
    raise exception 'رسم غير موجود';
  end if;

  update owner_fees set amount_due = p_amount where id = p_fee_id;

  insert into admin_actions (actor, action, subject_type, subject_id, from_state, to_state, reason)
  values (actor_name(), 'admin_fee_amount', 'owner_fees', p_fee_id, v_old::text, p_amount::text, p_reason);
end $function$;

revoke execute on function public.admin_fee_amount(uuid, numeric, text) from public;
grant execute on function public.admin_fee_amount(uuid, numeric, text) to authenticated, service_role;
