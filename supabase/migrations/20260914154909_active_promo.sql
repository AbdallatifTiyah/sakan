create or replace function public.active_promo()
returns table(code text, discount_pct smallint, valid_until date)
language sql
stable security definer
set search_path to 'public'
as $function$
  select code, discount_pct, valid_until
  from promo_codes
  where is_active
    and (valid_until is null or valid_until >= current_date)
    and (max_uses is null or used_count < max_uses)
  order by valid_until nulls last
  limit 1;
$function$;

revoke execute on function public.active_promo() from public;
grant execute on function public.active_promo() to anon, authenticated, service_role;
