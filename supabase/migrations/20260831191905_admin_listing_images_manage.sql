-- ═══════════════════════════════════════════════════════════
-- إدارة صور الإعلان من مركز التحكم (إضافة/حذف/ترتيب)
-- ═══════════════════════════════════════════════════════════

-- الطاقم (authenticated + is_staff()) يقدر يحذف ملفات من هالـbucket.
-- الرفع أصلاً مسموح لـauthenticated من migration سابقة (نفس مسار
-- المالك العام). الحذف المباشر بـSQL ممنوع دايماً (protect_delete)،
-- هاي سياسة على Storage API نفسها.
drop policy if exists listing_images_staff_delete on storage.objects;
create policy listing_images_staff_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'listing-images' and is_staff());

create or replace function public.admin_listing_images(p_id uuid, p_images jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), 'admin'), true);

  update listings set images = coalesce(p_images, '[]'::jsonb), updated_at = now()
   where id = p_id;

  insert into admin_actions(actor, action, subject_type, subject_id)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'listing_images', 'listing', p_id);
end $$;

revoke execute on function admin_listing_images(uuid, jsonb) from public;
grant  execute on function admin_listing_images(uuid, jsonb) to authenticated, service_role;

notify pgrst, 'reload schema';
