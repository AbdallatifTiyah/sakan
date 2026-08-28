# سكن (Sakan) — دليل المشروع

منصة تأجير غرف وسكن مشترك موثّق في رام الله والبيرة وبيرزيت.
واجهة عربية RTL. باك إند Supabase. نشر على Cloudflare Workers من GitHub.

---

## البنية

| ملف | الوصف |
|---|---|
| `public/index.html` | الموقع العام. صفحة واحدة، بدون build step، بدون npm. **هاد الملف الوحيد اللي بينشر** |
| `wrangler.toml` | إعدادات النشر. `[assets] directory = "./public"` |
| `admin.html` | لوحة الإدارة. **service_role — محلي فقط، بالـ.gitignore، ممنوع رفعه** |
| `supabase/migrations/` | كل تعديل على قاعدة البيانات يصير هنا |
| `SETUP.md` | دليل النشر والتشغيل اليومي |

أي ملف برّا `public/` ما بينشر على الإنترنت. هاد مقصود — `CLAUDE.md` وملفات الـmigrations ما لازم تكون عامة.

**الريبو:** `github.com/AbdallatifTiyah/sakan` (خاص). الفرع الأساسي `main`. كل push على `main` بينشر تلقائياً.

**Supabase**
- ref: `yckteijitcqjtedoyoyv`
- URL: `https://yckteijitcqjtedoyoyv.supabase.co`
- anon key (عام، مسموح يظهر بالكود):
  `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlja3RlaWppdGNxanRlZG95b3l2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc5MjA3MTksImV4cCI6MjEwMzQ5NjcxOX0.mAY5A6ROvtxN4kkD8g1s_tsDlSjGfy4TCNkgbYHeRvo`

قاعدة البيانات: ١٣ جدول، RLS مفعّل على كلهم، ٩ مشغّلات، ٥ واجهات، pg_cron شغّال (`expire-stale` يومياً ٣:٠٥).

---

## قواعد حاكمة — ممنوع كسرها

1. **الخصوصية:** أرقام الهواتف، العناوين الدقيقة، وجهة العمل **ما بتظهر أبداً** بأي واجهة عامة.
2. الموقع بيقرأ من `v_listings_public` و `v_requests_public` **فقط**. أي استعلام مباشر على `listings` أو `profiles` من الواجهة = خطأ.
3. `v_reverse_matches` و `v_kpi_*` أدوات داخلية. ممنوع منح `anon` صلاحية عليها إطلاقاً.
4. أي تعديل schema بيصير كملف migration + `supabase db push`. **ممنوع SQL Editor.**
5. `admin.html` بالـ`.gitignore`. ممنوع إزالته منه، وممنوع نقله لـ`public/`.
6. المنصة **مش** أداة مراقبة. صفحة طمأنة الأهل بتوصف السكن، مش بتتبّع الساكن.
7. بدون dependencies جديدة. صفحة واحدة، vanilla JS.
8. ولا ملف حسّاس جوّا `public/`.

---

## طريقة الشغل مع قاعدة البيانات

```
supabase/migrations/YYYYMMDDHHMMSS_وصف.sql   ← اكتب التعديل
supabase db push                              ← طبّقه على السيرفر
git add -A && git commit && git push          ← احفظه وانشر
```

- `db push` **ما بيحتاج Docker**.
- `db pull` و `db diff` بيحتاجوا Docker Desktop شغّال.
- قبل أي migration جديد: اقرأ `supabase/migrations/20260828161300_remote_schema.sql` — هاد الأساس.

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

## خلصت ✅

- الريبو مربوط بـGitHub، `.gitignore` شغّال، `admin.html` ما انرفع ولا مرة
- الـschema مسحوب كأساس، سجل الـmigrations متطابق بين المحلي والسيرفر
- `index.html` مربوط بالمفاتيح وبيعرض الإعلانين، وطلب التواصل بيوصل للقاعدة فعلاً
- **ثغرة `confirm_token` انسكرت:** عمود `confirm_token uuid` بكل إعلان، والدالة صارت `confirm_listing_available(p_ref text, p_token uuid)` وبتتحقق من الاتنين
- **ثغرة تانية انسكرت:** سياسة `anon_insert_contact` كانت `with_check = true` — أي حدا كان بيقدر يزرع `status='rented'` ويولّد عمولة وهمية بـ`owner_fees`. صارت مضيّقة على `status='new'` وحقول المندوب فاضية

---

## مهام مفتوحة

- [ ] `public/index.html`: يقرأ `?c=<ref>&t=<token>` من الرابط ويمرّرهم لـ`confirm_listing_available`
- [ ] `admin.html`: يعرض `confirm_token` وزر نسخ يبني الرابط كامل للمندوب
- [ ] حذف القسم ١٨ (بيانات تجريبية) قبل أول إعلان حقيقي — وحذف طلب التواصل التجريبي من `contact_requests`
- [ ] التأكد إنه `/CLAUDE.md` و `/supabase/...` بيرجّعوا 404 على الرابط المنشور
- [ ] التسجيل بوزارة الاقتصاد الوطني

---

## أسلوب العمل

- اشتغل بالعربي. الكود بالإنجليزي، التعليقات والواجهة بالعربي.
- قبل أي تعديل schema: اقرأ آخر migration أولاً.
- بعد أي تعديل: commit برسالة وصفية وpush.
- لا تعيد كتابة ملف كامل لو التعديل سطرين.
