-- إصلاح: admin_fee_promo كان حساس لحالة الأحرف — كود "sakan50" بيفشل بخطأ
-- foreign key خام (violates foreign key constraint) بدل رسالة واضحة، لأن
-- promo_codes.code محفوظ Uppercase ("SAKAN50") والمقارنة كانت حرفية.
-- اكتشفناها بفحص مباشر على القاعدة (owner_fees فاضي لسا — الكود ما انستخدم فعلياً).
--
-- بالمرة: شلنا p_actor غير المستخدَم أصلاً بجسم الدالة — نفس نمط باقي الدوال
-- الإدارية الجديدة (قاعدة ١٦). create or replace ما بيبدّل توقيع الدالة، فلازم
-- drop صريح للنسخة القديمة الثلاثية البارامترات قبل إنشاء النسخة الجديدة.
drop function if exists public.admin_fee_promo(uuid, text, text);

create or replace function public.admin_fee_promo(
  p_id uuid, p_code text
) returns numeric
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v numeric;
  v_code text := nullif(upper(trim(p_code)), '');
  pc record;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;

  if v_code is not null then
    select * into pc from promo_codes where code = v_code;
    if not found then
      raise exception 'الكود غير موجود';
    end if;
    if not pc.is_active then
      raise exception 'الكود غير مفعّل';
    end if;
    if pc.valid_until is not null and pc.valid_until < current_date then
      raise exception 'الكود منتهي الصلاحية';
    end if;
    if pc.max_uses is not null and pc.used_count >= pc.max_uses then
      raise exception 'الكود وصل الحد الأقصى للاستخدام';
    end if;
  end if;

  update owner_fees set promo_code = v_code where id = p_id
  returning amount_due into v;
  return v;
end $$;

revoke execute on function public.admin_fee_promo(uuid, text) from public;
revoke execute on function public.admin_fee_promo(uuid, text) from anon;
grant  execute on function public.admin_fee_promo(uuid, text) to authenticated, service_role;

notify pgrst, 'reload schema';
