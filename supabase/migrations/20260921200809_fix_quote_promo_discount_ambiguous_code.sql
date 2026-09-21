create or replace function public.quote_promo_discount(p_code text, p_kind listing_kind)
returns table(code text, discount_pct smallint, fee_before numeric, fee_after numeric)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_code text := nullif(upper(trim(p_code)), '');
  pc record;
  v_fee numeric;
begin
  if v_code is null then
    raise exception 'اكتب كود الخصم أولاً';
  end if;

  select * into pc from promo_codes where promo_codes.code = v_code;
  if not found then
    raise exception 'كود الخصم غير موجود';
  end if;
  if not pc.is_active then
    raise exception 'كود الخصم غير مفعّل';
  end if;
  if pc.valid_until is not null and pc.valid_until < current_date then
    raise exception 'كود الخصم منتهي الصلاحية';
  end if;
  if pc.max_uses is not null and pc.used_count >= pc.max_uses then
    raise exception 'كود الخصم وصل الحد الأقصى للاستخدام';
  end if;

  v_fee := quote_listing_fee(p_kind);

  return query
    select pc.code, pc.discount_pct, v_fee, round(v_fee * (100 - pc.discount_pct) / 100.0, 2);
end
$function$;

revoke all on function public.quote_promo_discount(text, listing_kind) from public;
grant execute on function public.quote_promo_discount(text, listing_kind) to anon, authenticated;
