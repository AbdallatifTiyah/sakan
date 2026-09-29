create or replace function public.admin_contact_link(p_listing_id uuid, p_request_id uuid)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_phone text;
  v_name text;
  v_id uuid;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;

  if not exists (select 1 from listings where id = p_listing_id) then
    raise exception 'الإعلان غير موجود';
  end if;

  select p.phone, p.first_name into v_phone, v_name
  from seeker_requests r
  join profiles p on p.id = r.seeker_id
  where r.id = p_request_id;

  if v_phone is null then
    raise exception 'طلب الباحث أو رقم هاتفه غير موجود';
  end if;

  -- agent_id يشير لـ profiles.id لا staff.id (تحقّق حي بـpg_get_constraintdef) —
  -- ما إله علاقة بموظف الطاقم اللي عمل الربط، وما بينستخدم بأي دالة تانية بالقاعدة. يترك NULL.
  insert into contact_requests (listing_id, request_id, seeker_phone, seeker_name, status, outcome_source)
  values (p_listing_id, p_request_id, v_phone, v_name, 'new', 'agent')
  returning id into v_id;

  insert into admin_actions (actor, action, subject_type, subject_id, reason, meta)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'contact_linked', 'contact', v_id,
          'ربط يدوي من الطاقم بين إعلان وطلب باحث',
          jsonb_build_object('listing_id', p_listing_id, 'request_id', p_request_id));

  perform admin_contact_status(v_id, 'rented', 'ربط يدوي من الطاقم — تأجير مؤكّد خارج تدفق التواصل العادي');

  return v_id;
end;
$$;

revoke all on function public.admin_contact_link(uuid, uuid) from public;
grant execute on function public.admin_contact_link(uuid, uuid) to authenticated, service_role;
