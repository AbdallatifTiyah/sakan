-- ═══════════════════════════════════════════════════════════
-- فخ الـzero-policy: cities و areas كان RLS عليهم مفعّل بصفر
-- سياسات. النتيجة قراءة فاضية صامتة لـanon (مش خطأ — مصفوفة
-- فاضية). لهيك كانت المناطق مكتوبة يدوياً بجافاسكربت الموقع.
-- ═══════════════════════════════════════════════════════════

drop policy if exists public_read_cities on cities;
create policy public_read_cities on cities
  for select to anon, authenticated
  using (is_active);

drop policy if exists public_read_areas on areas;
create policy public_read_areas on areas
  for select to anon, authenticated
  using (
    is_active
    and exists (select 1 from cities c where c.id = areas.city_id and c.is_active)
  );

-- ═══════════════════════════════════════════════════════════
-- تضييق بلاغات anon: كانت with_check = true، يعني الزائر
-- بيقدر يبعث بلاغ حالته 'dismissed' أو 'actioned' ويكتب
-- action_note — يعني يدفن بلاغه أو يزوّر ملاحظة إدارية.
-- ═══════════════════════════════════════════════════════════

drop policy if exists anon_insert_report on reports;
create policy anon_insert_report on reports
  for insert to anon, authenticated
  with check (
    status = 'open'::report_status
    and action_note is null
    and reporter_id is null
    and details is not null
    and length(btrim(details)) between 5 and 2000
    and (reporter_phone is null
         or length(btrim(reporter_phone)) between 9 and 20)
  );
