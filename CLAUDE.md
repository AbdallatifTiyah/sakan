# سكن (Sakan) — دليل المشروع

منصة تأجير غرف وسكن مشترك موثّق في رام الله والبيرة وبيرزيت.
واجهة عربية RTL. باك إند Supabase. نشر على Cloudflare Workers.

**آخر تحديث: ٢٩ آب ٢٠٢٦ — conv9 (مركز التحكم الإداري)**

---

## حالة المشروع الآن

| البند | الحالة |
|---|---|
| قاعدة البيانات | ✅ جاهزة ومؤمّنة (Frankfurt) — ١٥ جدول، ١٣ واجهة |
| ثغرة `confirm_listing_available` | ✅ انحلّت بـ`confirm_token` عشوائي |
| صلاحيات `service_role` | ✅ سليمة |
| منح `EXECUTE` من `PUBLIC` | ✅ انسكرت كلياً — متحقّقة بـ`has_function_privilege` |
| `TRUNCATE` لـ`anon` | ✅ انسحبت من كل الجداول |
| الموقع العام | ✅ منشور على `sakan.abdallatif-tiyah.workers.dev` |
| حماية `/admin` | ✅ Basic Auth من الـWorker |
| **لوحة الإدارة** | ✅ **مركز تحكم كامل — ١٣ قسم** |
| سجل إجراءات الإدارة | ✅ `admin_actions` + مشغّلات تدقيق على ٧ جداول |
| إعدادات المنصة | ✅ جدول `settings` — الرسم والصلاحية وعتبة التقييم صاروا قابلين للتعديل |
| النطاق `sakan.ps` | ❌ بيد أبواللطيف — خارج نطاق مساعدة Claude |
| البيانات | ✅ القاعدة نضيفة — `cities`/`areas`/`SAKAN50` بس |

---

## البنية

| ملف | الوصف |
|---|---|
| `public/index.html` | الموقع العام. صفحة واحدة، بدون build step، بدون npm |
| `public/admin/index.html` | مركز التحكم. منشور على `/admin`، محمي بـBasic Auth من الـWorker |
| `src/worker.js` | الـWorker. بيحرس `/admin` وبيمرّر الباقي لـ`ASSETS` |
| `wrangler.toml` | إعداد النشر — `main` + `binding = "ASSETS"` + `run_worker_first = true` |
| `supabase/migrations/` | كل تعديل على قاعدة البيانات بيصير هنا |
| `SETUP.md` | دليل النشر والتشغيل اليومي |

**Supabase**
- ref: `yckteijitcqjtedoyoyv` (eu-central-1)
- URL: `https://yckteijitcqjtedoyoyv.supabase.co`
- anon key (عام، مسموح يظهر بالكود):
  `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlja3RlaWppdGNxanRlZG95b3l2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc5MjA3MTksImV4cCI6MjEwMzQ5NjcxOX0.mAY5A6ROvtxN4kkD8g1s_tsDlSjGfy4TCNkgbYHeRvo`
- نظامين مفاتيح: القديم JWT (`eyJ...`) والجديد (`sb_publishable_...` / `sb_secret_...`). أي كود بيتعامل مع مفتاح لازم يقبل الشكلين.

**الـmigrations المسجّلة**
- `20260828161300_remote_schema`
- `20260828203602_restore_service_role_grants`
- `20260828222908_revoke_rls_auto_enable`
- `20260829012706_close_public_grants_leftovers`
- `20260829012742_admin_settings_and_audit`
- `20260829012755_wire_business_rules_to_settings`
- `20260829012826_admin_views`
- `20260829012858_admin_action_rpcs`
- `20260829120000_revoke_public_execute_grants`
- `20260829140000_remove_seed_data`
- `20260829150000_seed_reference_data`

> ملاحظة: migrations conv9 مسجّلة بطوابع `2026082901…` فبتسبق `…120000` بالترتيب. الترتيب سليم وظيفياً (كل واحدة بتعتمد بس على `remote_schema`)، بس لا تعيد ترقيمها — الريبو لازم يطابق `supabase_migrations` بالحرف.

**من يقرأ ماذا**
- `anon` → `v_listings_public`, `v_requests_public`, `areas`, `cities` — لا غير
- `authenticated` → `v_listings_public`, `v_requests_public`
- `service_role` → كل شي (بيتجاوز RLS) — لمركز التحكم فقط

**الواجهات الداخلية (service_role حصراً — فيها أرقام هواتف)**
`v_admin_listings` · `v_admin_owners` · `v_admin_seekers` · `v_admin_reports` ·
`v_admin_pipeline` · `v_admin_fees` · `v_admin_activity` · `v_kpi_daily` ·
`v_kpi_core` · `v_kpi_quality` · `v_reverse_matches`

**دوال الإدارة (service_role حصراً)**
`admin_listing_status` · `admin_listing_verification` · `admin_listing_extend` ·
`admin_profile_level` · `admin_profile_block` · `admin_report_status` ·
`admin_fee_status` · `admin_fee_promo` · `admin_contact_status` ·
`admin_save_safety` · `admin_set_setting` · `admin_log`

**Cloudflare**
- Worker: `sakan` → `sakan.abdallatif-tiyah.workers.dev`
- أسرار: `ADMIN_USER`, `ADMIN_PASS` — عبر `npx wrangler secret put`. ما بتنقرأ، بتنكتب فوق بس.
- بيانات الدخول لازم تكون ASCII بدون `:`.

---

## قواعد حاكمة — ممنوع كسرها

1. **الخصوصية:** أرقام الهواتف، العناوين الدقيقة، وجهة العمل **ما بتظهر أبداً** بأي واجهة عامة.
2. الموقع العام بيقرأ من `v_listings_public` و `v_requests_public` **فقط**.
3. `v_admin_*` و`v_reverse_matches` و`v_kpi_*` أدوات داخلية. ممنوع منح `anon` صلاحية عليها إطلاقاً.
4. أي تعديل schema بيصير كملف migration بالريبو **وينطبّق على القاعدة**. الاتنين مع بعض. **ممنوع SQL Editor.**
5. **ممنوع كتابة أي مفتاح سري بأي ملف بالريبو.** المفتاح بينلصق يدوياً وبينحفظ بـ`sessionStorage` فقط.
6. `/admin` ما بيوصله طلب إلا بعد Basic Auth. أي تعديل على `wrangler.toml` أو `worker.js` بيتبعه فحص: `/admin` و`/admin/index.html` = `401`، الجذر = `200`.
7. **أي سكربت تأمين بيسحب صلاحيات لازم يستثني `service_role` صراحةً.**
8. **`robots.txt` ما بيذكر `/admin` إطلاقاً.** الحماية = `401` + `X-Robots-Tag: noindex`.
9. المنصة **مش** أداة مراقبة. صفحة طمأنة الأهل بتوصف السكن، مش بتتبّع الساكن.
10. بدون dependencies جديدة. صفحة واحدة، vanilla JS.
11. **أي `function` جديدة: `revoke execute ... from public;` ثم `grant execute ... to` الأدوار المقصودة صراحةً.** التحقق الوحيد المعتبر: `has_function_privilege('anon','<signature>','execute')` = `false`.
12. **جديد — القيم التجارية بتنقرأ من `settings`، مش مكتوبة بالكود.** رسم النجاح، مدة الصلاحية، عتبة نشر التقييمات. لا ترجّعها لأرقام ثابتة.
13. **جديد — دور المندوب بمركز التحكم حاجز تشغيلي مش أمني.** أي حدا معه مفتاح الخدمة بيقدر يعمل كل شي. الحل الحقيقي (Cloudflare Access + دور `agent` بالقاعدة) لسا مؤجّل.

---

## مركز التحكم — الأقسام

| القسم | المدير | المندوب |
|---|---|---|
| لوحة القيادة (KPI + بوابة القرار + قائمة اليوم) | ✅ | ✅ |
| بانتظار المراجعة | ✅ | ✅ |
| البلاغات | ✅ | ❌ |
| مسار التأجير | ✅ | ✅ |
| كل الإعلانات | ✅ | ✅ |
| التوثيق | ✅ | ✅ |
| المطابقة العكسية | ✅ | ✅ |
| الملّاك | ✅ | ✅ (بدون إيقاف حساب) |
| الباحثون | ✅ | ❌ |
| الرسوم | ✅ | ✅ (تحصيل فقط، بدون إعفاء/شطب) |
| نشاط المنصة | ✅ | ❌ |
| سجل الإجراءات | ✅ | ❌ |
| الإعدادات | ✅ | ❌ |

كل إجراء بينتسجّل بـ`admin_actions` باسم الفاعل. أي تعديل مباشر على القاعدة من برّا اللوحة بينتسجّل باسم `direct`.

---

## تشخيص سريع

| العرض | المعنى |
|---|---|
| `401` من Supabase | المفتاح نفسه مرفوض أو ناقص هيدر `apikey` |
| `403` من Supabase | **المفتاح سليم** — الدور ناقصه GRANT على الجدول |
| `404` من Supabase | اسم جدول/واجهة غلط، أو كاش PostgREST قديم → `notify pgrst, 'reload schema';` |
| `/admin` بيفتح بدون سؤال | الـWorker مش شغّال — افحص `main` بـ`wrangler.toml` |
| `revoke` نجح بس الصلاحية باقية | المنحة من `PUBLIC` مش من الدور. تحقق دايماً بـ`has_function_privilege`. |
| إجراء باللوحة ما ظهر بالسجل | الإجراء صار كـ`PATCH` مباشر مش عبر `admin_*` RPC — بينتسجّل `direct` |

---

## السياق التجاري

- **الموسمية:** ذروة آب–تشرين أول (الآن)، ذروة أصغر شباط. السرعة أهم من الكمال.
- **بوابة القرار:** ١٠٠ غرفة موثّقة و٢٥ تأجير مؤكد قبل ٣٠ تشرين ثاني ٢٠٢٦ — القيم بجدول `settings`.
- **مؤشر PMF الأساسي:** نسبة إعادة الإدراج من المالك خلال ٦٠ يوم (`v_kpi_quality.owner_repeat_pct`).
- **الدخل:** رسم توثيق بسيط مرة وحدة من الباحث + عمولة نجاح من المالك تُحصّل نقداً عبر المندوب. الباحث مجاني بفترة الإطلاق. المالكين الأوائل: كود `SAKAN50` (٥٠٪ · ٥٠ استخدام · حتى ٣١/١٢/٢٠٢٦).
- **قانوني:** التسجيل بوزارة الاقتصاد الوطني حسب قانون التجارة الإلكترونية رقم ٢١ لسنة ٢٠٢٥.

---

## خارج النطاق (لا تبنيه)

شات داخلي · بوابة دفع · حساب ضمان (escrow) · تطبيق أصلي · تسجيل دخول بالبريد · أي ميزة بتأخّر الإطلاق.

---

## مهام مفتوحة

- [ ] ربط النطاق `sakan.ps` — أبواللطيف بيتولاها
- [ ] رفع `public/admin/index.html` الجديد + الخمس migrations على الريبو ونشر
- [ ] قرار: هل رسم شارة الباحث (٣٠ ₪) بينتتبّع بالنظام؟ حالياً قيمة بالإعدادات بدون جدول
- [ ] **لاحقاً (مش الآن):** Cloudflare Access بدل Basic Auth + دور `agent` محدود بالقاعدة بدل `service_role` بمتصفح المندوب

---

## أسلوب العمل

- اشتغل بالعربي. الكود بالإنجليزي، التعليقات والواجهة بالعربي.
- قبل أي تعديل schema: اقرأ آخر migration أولاً.
- بعد أي تعديل: commit برسالة وصفية وpush.
- لا تعيد كتابة ملف كامل لو التعديل سطرين.
- **الملفات الصغيرة (أقل من ١٠٠ سطر) بتنكتب كاملة بالشات وبتنلصق.**
- **بأول أي محادثة جديدة، شغّل وابعت النتيجة:** `ls` · `ls public` · `Get-Content wrangler.toml` · `git log --oneline -5`
- **بعد أي تغيير بالبنية: حدّث هذا الملف بالريبو وارفعه من جديد على رفوف المشروع.**
