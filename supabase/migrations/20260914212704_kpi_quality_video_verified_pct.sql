-- video_verified_pct عمود جديد منفصل — field_verified_pct لازم يضل يقيس
-- الزيارة الميدانية فقط، ما ينتفخ بتوثيق الفيديو. فلترة field_verified_pct
-- بلا أي تغيير (= 'field' حرفياً)، عمود جديد بذيل القائمة (فخ إعادة
-- الترتيب) بنفس منطق field_verified_pct تماماً بس بفلتر verification='video'.
-- create or replace view بيصفّر security_invoker تلقائياً (فخ ثانٍ) —
-- alter view منفصل بعده، وتحقّق reloptions + set local role authenticated
-- (غير موظّف) = صف واحد بكل القيم null (نفس توقيع الحماية لهاي الـview
-- أحادية الصف من migration 20260914205232).
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
           FROM listings), 0)::numeric, 2) AS report_rate_pct,
    round(100.0 * (( SELECT count(*) AS count
           FROM listings
          WHERE listings.status = 'published'::listing_status AND listings.verification = 'video'::listing_verification))::numeric / NULLIF(( SELECT count(*) AS count
           FROM listings
          WHERE listings.status = 'published'::listing_status), 0)::numeric, 1) AS video_verified_pct;

alter view public.v_kpi_quality set (security_invoker = on);
