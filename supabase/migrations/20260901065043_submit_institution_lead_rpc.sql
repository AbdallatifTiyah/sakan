-- استبدال الـinsert المباشر على institution_leads بدالة submit_institution_lead،
-- نفس نمط submit_listing/submit_request/submit_review — تحقّق من المدخلات بمكان
-- واحد، وما بتحتاج anon تنمنح insert مباشر على الجدول (نفس وضع listings/reviews).

create or replace function public.submit_institution_lead(
  p_org_name text,
  p_org_type text,
  p_contact_name text,
  p_contact_phone text,
  p_city integer default null,
  p_contact_email text default null,
  p_rooms_needed smallint default null,
  p_message text default null
) returns boolean
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
begin
  if coalesce(trim(p_org_name),'') = '' or coalesce(trim(p_contact_name),'') = '' then
    raise exception 'اسم المؤسسة واسم شخص التواصل مطلوبان';
  end if;
  if coalesce(trim(p_contact_phone),'') = '' or length(trim(p_contact_phone)) < 9 then
    raise exception 'رقم هاتف صحيح مطلوب';
  end if;

  insert into institution_leads (org_name, org_type, contact_name, contact_phone,
                                  contact_email, city_id, rooms_needed, message)
  values (trim(p_org_name),
          coalesce(nullif(trim(p_org_type),''), 'other')::institution_org_type,
          trim(p_contact_name), trim(p_contact_phone),
          nullif(trim(coalesce(p_contact_email,'')),''), p_city, p_rooms_needed,
          nullif(trim(coalesce(p_message,'')),''));

  return true;
end $$;

revoke execute on function public.submit_institution_lead(text,text,text,text,integer,text,smallint,text) from public;
grant  execute on function public.submit_institution_lead(text,text,text,text,integer,text,smallint,text) to anon, authenticated, service_role;

-- الـinsert المباشر ما عاد إله لزوم — نفس نمط listings/seeker_requests/reviews:
-- الجدول مش ممنوح anon عليه إطلاقاً، الكتابة حصراً عبر الدالة SECURITY DEFINER.
drop policy if exists anon_insert_institution_lead on public.institution_leads;
revoke insert on public.institution_leads from anon, authenticated;

notify pgrst, 'reload schema';
