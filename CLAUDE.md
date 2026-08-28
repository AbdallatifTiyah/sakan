# سكن (Sakan) — دليل المشروع

منصة تأجير غرف وسكن مشترك موثّق في رام الله والبيرة وبيرزيت.
واجهة عربية RTL. باك إند Supabase. نشر على Cloudflare Workers.

**آخر تحديث: ٢٩ آب ٢٠٢٦ — conv7 (إغلاق منحة PUBLIC)**

---

## حالة المشروع الآن

| البند | الحالة |
|---|---|
| قاعدة البيانات | ✅ جاهزة ومؤمّنة (Frankfurt) |
| ثغرة `confirm_listing_available` | ✅ انحلّت بـ`confirm_token` عشوائي — متحقّقة من القاعدة |
| صلاحيات `service_role` | ✅ استُعيدت — كانت مسحوبة بالغلط وكانت بتوقف اللوحة كلياً |
| الموقع العام | ✅ منشور على `sakan.abdallatif-tiyah.workers.dev` |
| حماية `/admin` | ✅ Basic Auth من الـWorker — متحقّقة: `401` / `401` / `200` |
| لوحة الإدارة | ✅ قراءة وكتابة شغالة — تغيير حالة إعلان وصل للقاعدة |
| الريبو ↔ القاعدة | ✅ متطابقين |
| النطاق `sakan.ps` | ❌ بيد أبواللطيف — خارج نطاق مساعدة Claude |
| البيانات التجريبية | ❌ لسا موجودة (إعلانين + ٣ ملفات + طلب Yasmin + سجل أحداث) |

---

## البنية

| ملف | الوصف |
|---|---|
| `public/index.html` | الموقع العام. صفحة واحدة، بدون build step، بدون npm. **نضيف — ما فيه بيانات تجريبية** |
| `public/admin/index.html` | لوحة الإدارة. منشورة على `/admin`، محمية بـBasic Auth من الـWorker |
| `src/worker.js` | الـWorker. بيحرس `/admin` وبيمرّر الباقي لـ`ASSETS` |
| `wrangler.toml` | إعداد النشر — `main` + `binding = "ASSETS"` + `run_worker_first = true` |
| `supabase/migrations/` | كل تعديل على قاعدة البيانات بيصير هنا |
| `task.md` | مهمة Claude Code الحالية |
| `SETUP.md` | دليل النشر والتشغيل اليومي |

**Supabase**
- ref: `yckteijitcqjtedoyoyv` (eu-central-1)
- URL: `https://yckteijitcqjtedoyoyv.supabase.co`
- anon key (عام، مسموح يظهر بالكود):
  `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlja3RlaWppdGNxanRlZG95b3l2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc5MjA3MTksImV4cCI6MjEwMzQ5NjcxOX0.mAY5A6ROvtxN4kkD8g1s_tsDlSjGfy4TCNkgbYHeRvo`
- المشروع عليه **نظامين مفاتيح**: القديم JWT (`eyJ...`) والجديد (`sb_publishable_...` / `sb_secret_...`). أي كود بيتعامل مع مفتاح لازم يقبل الشكلين.

قاعدة البيانات: ١٣ جدول، RLS مفعّل على كلهم، ٩ مشغّلات، ٥ واجهات، pg_cron شغّال (`expire-stale` يومياً ٣:٠٥).

**الـmigrations المسجّلة**
- `20260828161300_remote_schema`
- `20260828203602_restore_service_role_grants`
- `20260828222908_revoke_rls_auto_enable`
- `20260829120000_revoke_public_execute_grants`

**من يقرأ ماذا**
- `anon` → `v_listings_public`, `v_requests_public`, `areas`, `cities` — لا غير
- `authenticated` → `v_listings_public`, `v_requests_public`
- `service_role` → كل شي (بيتجاوز RLS) — للوحة الإدارة فقط

**Cloudflare**
- Worker: `sakan` → `sakan.abdallatif-tiyah.workers.dev`
- أسرار: `ADMIN_USER`, `ADMIN_PASS` — عبر `npx wrangler secret put`. مش بالكود ولا بالريبو. **ما بتنقرأ، بتنكتب فوق بس.**
- بيانات الدخول لازم تكون ASCII بدون `:` — `atob` بينكسر مع العربي، والـBasic Auth بيفصل على النقطتين.

---

## قواعد حاكمة — ممنوع كسرها

1. **الخصوصية:** أرقام الهواتف، العناوين الدقيقة، وجهة العمل **ما بتظهر أبداً** بأي واجهة عامة.
2. الموقع بيقرأ من `v_listings_public` و `v_requests_public` **فقط**. أي استعلام مباشر على `listings` أو `profiles` من الواجهة = خطأ.
3. `v_reverse_matches` و `v_kpi_*` أدوات داخلية. ممنوع منح `anon` صلاحية عليها إطلاقاً.
4. أي تعديل schema بيصير كملف migration بالريبو **وينطبّق على القاعدة**. الاتنين مع بعض. **ممنوع SQL Editor.**
5. **ممنوع كتابة أي مفتاح سري بأي ملف بالريبو.** `public/admin/index.html` بينرفع — بس المفتاح بينلصق يدوياً وبينحفظ بـ`sessionStorage` فقط. أي `sb_secret_` أو `service_role` مكتوب بملف = وقّف كل شي.
6. `/admin` ما بيوصله طلب إلا بعد Basic Auth. أي تعديل على `wrangler.toml` أو `worker.js` بيتبعه فحص: `/admin` و`/admin/index.html` = `401`، الجذر = `200`.
7. **أي سكربت تأمين بيسحب صلاحيات لازم يستثني `service_role` صراحةً.** سحبها بيوقف لوحة الإدارة بالكامل.
8. **`robots.txt` ما بيذكر `/admin` إطلاقاً.** كتابة `Disallow: /admin` بتدلّ على مكان اللوحة بدل ما تخفيها. الحماية = `401` + `X-Robots-Tag: noindex`.
9. المنصة **مش** أداة مراقبة. صفحة طمأنة الأهل بتوصف السكن، مش بتتبّع الساكن.
10. بدون dependencies جديدة. صفحة واحدة، vanilla JS.
11. **أي `function` جديدة بتنكتب: `revoke execute on function ... from public;` وبعدها `grant execute ... to` الأدوار المقصودة صراحةً.** الافتراضي بـPostgres بيمنح التنفيذ لـ`PUBLIC` — يعني الدالة مكشوفة على `/rest/v1/rpc/` من لحظة إنشائها. سحبها من `anon` لحاله ما بينفع. التحقق الوحيد المعتبر: `has_function_privilege('anon', '<signature>', 'execute')` = `false`.

---

## تشخيص سريع

| العرض | المعنى |
|---|---|
| `401` من Supabase | المفتاح نفسه مرفوض أو ناقص هيدر `apikey` |
| `403` من Supabase | **المفتاح سليم** — الدور ناقصه GRANT على الجدول |
| `404` من Supabase | اسم جدول/واجهة غلط، أو الschema مش مكشوف |
| `/admin` بيفتح بدون سؤال | الـWorker مش شغّال — افحص `main` بـ`wrangler.toml` |
| `revoke` نجح بس الصلاحية باقية | المنحة من `PUBLIC` مش من الدور. Postgres بيمنح `EXECUTE to PUBLIC` تلقائياً على كل function جديدة — لازم `revoke ... from public` صراحةً، وبعدها `grant` للأدوار المقصودة. تحقق دايماً بـ`has_function_privilege`، مش بنجاح الأمر. |

---

## السياق التجاري

- **الموسمية:** ذروة آب–تشرين أول (الآن)، ذروة أصغر شباط. السرعة أهم من الكمال.
- **بوابة القرار:** ١٠٠ غرفة موثّقة و٢٠–٣٠ تأجير مؤكد قبل ٣٠ تشرين ثاني ٢٠٢٦.
- **مؤشر PMF الأساسي:** نسبة إعادة الإدراج من المالك خلال ٦٠ يوم.
- **الدخل:** رسم توثيق بسيط مرة وحدة من الباحث + عمولة نجاح من المالك تُحصّل نقداً عبر المندوب الميداني. الباحث مجاني بفترة الإطلاق. المالكين الأوائل: كود خصم `SAKAN50` — مش مجاني بالكامل.
- **قانوني:** التسجيل بوزارة الاقتصاد الوطني حسب قانون التجارة الإلكترونية رقم ٢١ لسنة ٢٠٢٥.

---

## خارج النطاق (لا تبنيه)

شات داخلي · بوابة دفع · حساب ضمان (escrow) · تطبيق أصلي · تسجيل دخول بالبريد · أي ميزة بتأخّر الإطلاق.

---

## مهام مفتوحة

- [ ] **مسح البيانات التجريبية** — إعلانين، ٣ ملفات، طلب Yasmin، سجل الأحداث. (هذا هو "القسم ١٨" — كان بـ`schema.sql` مش بـ`index.html`)
- [ ] ربط النطاق `sakan.ps` — أبواللطيف بيتولاها
- [ ] **لاحقاً (مش الآن):** Cloudflare Access بدل Basic Auth + دور `agent` محدود الصلاحيات بدل `service_role` بمتصفح المندوب

---

## أسلوب العمل

- اشتغل بالعربي. الكود بالإنجليزي، التعليقات والواجهة بالعربي.
- قبل أي تعديل schema: اقرأ آخر migration أولاً.
- بعد أي تعديل: commit برسالة وصفية وpush.
- لا تعيد كتابة ملف كامل لو التعديل سطرين.
- **الملفات الصغيرة (أقل من ١٠٠ سطر) بتنكتب كاملة بالشات وبتنلصق — مش بتنوصف لـClaude Code.**
- **بأول أي محادثة جديدة، شغّل وابعت النتيجة:** `ls` · `ls public` · `Get-Content wrangler.toml` · `git log --oneline -5`
- **بعد أي تغيير بالبنية: حدّث هذا الملف بالريبو وارفعه من جديد على رفوف المشروع.** الخطوة التانية هي المهمة — بدونها الشات بيشتغل على خريطة قديمة.
