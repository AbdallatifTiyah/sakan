-- ═══════════════════════════════════════════════════════════
-- تحويل الواجهات الإدارية لـsecurity_invoker.
--
-- قبل: الواجهة بتشتغل بصلاحية مالكها (postgres) وبتتجاوز RLS
--       كلياً — فمنحها لأي دور بيعني كشف كل أرقام الهواتف.
-- بعد: بتشتغل بصلاحية المستدعي، فسياسة staff_read بتحكمها.
--       غير الطاقم بيرجعله صفر صفوف.
--
-- service_role بيتجاوز RLS، فمركز التحكم الحالي ما بينكسر.
-- الواجهتان العامتان (v_listings_public / v_requests_public)
-- ما بتنلمسا — لازم تضلا تشتغلا بصلاحية المالك لـanon.
-- ═══════════════════════════════════════════════════════════

do $$
declare v text;
begin
  foreach v in array array[
    'v_admin_listings','v_admin_owners','v_admin_seekers','v_admin_requests',
    'v_admin_reports','v_admin_pipeline','v_admin_fees','v_admin_activity',
    'v_kpi_core','v_kpi_daily','v_kpi_quality','v_reverse_matches'
  ] loop
    execute format('alter view %I set (security_invoker = on)', v);
    execute format('revoke all on %I from anon', v);
    execute format('grant select on %I to authenticated, service_role', v);
  end loop;
end $$;

notify pgrst, 'reload schema';
