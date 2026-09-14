-- admin_listing_verification تسمح بالفعل بأي قيمة نصية (p_level::listing_verification
-- بدون منطق خاص بأي قيمة) — التوقيع بلا أي تغيير، فما احتجت drop function
-- ولا إعادة grant (المنح محفوظة تلقائياً مع create or replace بنفس التوقيع).
-- الإضافة الوحيدة: تسجيل video_verified_at = تاريخ اليوم لما p_level='video'
-- (مقارنة نصية على p_level نفسه، بدون أي مرجع لقيمة الـenum 'video' —
-- احتياط إضافي متوافق مع قيد PostgreSQL بميغريشن الإضافة السابقة).
create or replace function public.admin_listing_verification(p_id uuid, p_level text, p_actor text default 'admin'::text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_old text;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  select verification::text into v_old from listings where id = p_id;
  update listings set
    verification = p_level::listing_verification,
    video_verified_at = case when p_level = 'video' then current_date else video_verified_at end,
    updated_at = now()
  where id = p_id;
  insert into verification_log (subject_type, subject_id, action, from_level, to_level, result)
  values ('listing', p_id, 'listing_verification', v_old, p_level, 'passed');
end $function$;
