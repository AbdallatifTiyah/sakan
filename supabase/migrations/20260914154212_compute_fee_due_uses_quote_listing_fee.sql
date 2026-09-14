create or replace function public.compute_fee_due()
returns trigger
language plpgsql
as $function$
declare pct smallint := 0;
begin
  if new.amount_base is null then
    new.amount_base := coalesce(
      (select quote_listing_fee(l.kind) from listings l where l.id = new.listing_id),
      setting_num('fee_base', 200)
    );
  end if;
  if new.promo_code is not null then
    select discount_pct into pct from promo_codes
     where code = new.promo_code and is_active
       and (valid_until is null or valid_until >= current_date)
       and (max_uses is null or used_count < max_uses);
    pct := coalesce(pct, 0);
  end if;
  new.amount_due := round(new.amount_base * (100 - pct) / 100.0, 2);
  return new;
end $function$;
