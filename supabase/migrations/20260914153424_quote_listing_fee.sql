create or replace function public.quote_listing_fee(p_kind listing_kind)
returns numeric
language sql
stable security definer
set search_path to 'public'
as $function$
  select setting_num('fee_' || p_kind::text, setting_num('fee_base', 200));
$function$;

revoke execute on function public.quote_listing_fee(listing_kind) from public;
grant execute on function public.quote_listing_fee(listing_kind) to anon, authenticated, service_role;
