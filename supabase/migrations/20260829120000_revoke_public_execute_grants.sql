-- Postgres grants EXECUTE to PUBLIC by default on every new function.
-- Revoking from anon/authenticated does nothing while PUBLIC still holds it.
-- Replace the blanket PUBLIC grant with explicit per-role grants.

-- 1. Admin helper: must not be reachable from the public API at all.
revoke execute on function public.rls_auto_enable() from public;
grant  execute on function public.rls_auto_enable() to service_role;

-- 2. Public submission RPCs: anon access is intended, but scope it explicitly.
revoke execute on function public.submit_listing(
  text, text, text, integer, numeric, text,
  text, boolean, date, text, text, text
) from public;
grant execute on function public.submit_listing(
  text, text, text, integer, numeric, text,
  text, boolean, date, text, text, text
) to anon, authenticated, service_role;

revoke execute on function public.submit_request(
  text, text, text, text, numeric, integer[], date, text[], text
) from public;
grant execute on function public.submit_request(
  text, text, text, text, numeric, integer[], date, text[], text
) to anon, authenticated, service_role;
