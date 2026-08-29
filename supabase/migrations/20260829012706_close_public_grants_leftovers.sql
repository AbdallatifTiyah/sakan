-- إغلاق منح EXECUTE من PUBLIC اللي فاتت على migration 20260829120000
revoke execute on function public.expire_stale_listings() from public;
revoke execute on function public.is_field_verified(uuid) from public;
revoke execute on function public.sakan_match_score(integer[], numeric, gender_type, listing_kind, date, integer, numeric, gender_policy, listing_kind, date) from public;

grant execute on function public.expire_stale_listings() to service_role;
grant execute on function public.is_field_verified(uuid) to service_role;
grant execute on function public.sakan_match_score(integer[], numeric, gender_type, listing_kind, date, integer, numeric, gender_policy, listing_kind, date) to service_role;

-- سحب TRUNCATE/REFERENCES/TRIGGER المتبقية من anon و authenticated (بقايا افتراضات Supabase)
-- ملاحظة: service_role مستثنى صراحةً حسب القاعدة رقم ٧
do $$
declare r record;
begin
  for r in select table_name from information_schema.tables where table_schema = 'public'
  loop
    execute format('revoke truncate, references, trigger on public.%I from anon, authenticated', r.table_name);
  end loop;
end $$;
