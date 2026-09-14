-- submit_listing ما عادت تعيد استخدام profiles بمطابقة الهاتف (migration
-- 20260914204457) — ملّاك بدون حساب بياخدوا صف/owner_id جديد كل مرة يسجّلوا
-- بدونه، فـowner_repeat_pct (بتجميع listings.owner_id) صار دايماً قريب صفر
-- حتى لو نفس الشخص كرّر التسجيل فعلياً. الإصلاح: التجميع صار على
-- profiles.phone (عبر join مع listings) بدل profiles.id.
--
-- مطابقة الهاتف غير آمنة للكتابة (بالضبط الثغرة اللي انسدّت بـ
-- link_account_role وsubmit_listing) لأن الهاتف مش مُتحقَّق منه بأي OTP —
-- لكنها آمنة هون تماماً: هاي view داخلية للطاقم فقط (security_invoker=on +
-- staff_read RLS على listings/profiles تحتها)، عملية عد إحصائي بحت،
-- ما بتمنح وصول ولا بتغيّر حالة. **ممنوع تحويلها رجوعاً لـowner_id** —
-- هذا كان بالضبط سبب كسر المؤشر.
--
-- create or replace view ممنوع يعيد ترتيب/تسمية الأعمدة (فخ موثّق بـ
-- CLAUDE.md) — الأعمدة الخمسة بنفس الاسم والترتيب، تغيير التعبير الداخلي
-- لـowner_repeat_pct فقط. create or replace view بيصفّر security_invoker
-- تلقائياً (فخ ثانٍ موثّق) — لازم alter view منفصل بعده بنفس الملف.
create or replace view public.v_kpi_quality as
 SELECT round(100.0 * NULLIF(( SELECT count(*) AS count
           FROM contact_requests
          WHERE contact_requests.status = 'rented'::contact_status), 0)::numeric / NULLIF(( SELECT count(*) AS count
           FROM contact_requests), 0)::numeric, 1) AS contact_to_rent_pct,
    ( SELECT percentile_cont(0.5::double precision) WITHIN GROUP (ORDER BY (EXTRACT(day FROM listings.rented_at - listings.published_at)::double precision)) AS percentile_cont
           FROM listings
          WHERE listings.rented_at IS NOT NULL) AS median_days_to_rent,
    round(100.0 * (( SELECT count(*) AS count
           FROM ( SELECT p.phone
                   FROM listings l
                   JOIN profiles p ON p.id = l.owner_id
                  WHERE l.created_at > (now() - '180 days'::interval) AND l.owner_id IS NOT NULL AND p.phone IS NOT NULL
                  GROUP BY p.phone
                 HAVING count(*) > 1) x))::numeric / NULLIF(( SELECT count(DISTINCT p.phone) AS count
           FROM listings l
           JOIN profiles p ON p.id = l.owner_id
          WHERE l.created_at > (now() - '180 days'::interval) AND l.owner_id IS NOT NULL AND p.phone IS NOT NULL), 0)::numeric, 1) AS owner_repeat_pct,
    round(100.0 * (( SELECT count(*) AS count
           FROM listings
          WHERE listings.status = 'published'::listing_status AND listings.verification = 'field'::listing_verification))::numeric / NULLIF(( SELECT count(*) AS count
           FROM listings
          WHERE listings.status = 'published'::listing_status), 0)::numeric, 1) AS field_verified_pct,
    round(100.0 * (( SELECT count(*) AS count
           FROM reports))::numeric / NULLIF(( SELECT count(*) AS count
           FROM listings), 0)::numeric, 2) AS report_rate_pct;

alter view public.v_kpi_quality set (security_invoker = on);
