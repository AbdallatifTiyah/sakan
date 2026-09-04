# سكن (Sakan) — دليل المشروع

منصة تأجير غرف وسكن مشترك موثّق في رام الله والبيرة وبيرزيت.
واجهة عربية RTL. باك إند Supabase. نشر على Cloudflare Workers.

> **الاسم موضع (Mawdi).** كل نص وواجهة عامة تقول «موضع»/Mawdi (النصوص، كود الخصم `MAWDI50`، بادئة الإعلان `MW-`، مفتاح اللغة `mawdi_lang`).
> **البنية التحتية فقط** ثابتة بـ"سكن" (اسم الـWorker، النطاق، اسم المستودع، وكل الأسماء التقنية بالقاعدة) — بيد أبواللطيف، خارج نطاق مساعدة Claude. لا تخلط بين الاسمين.

للحالة الحالية والمهام المفتوحة، شوف `STATUS.md`. لجدول التشخيص السريع، شوف `docs/TROUBLESHOOTING.md`.

## البنية

| ملف | الوصف |
|---|---|
| `public/index.html` | الموقع العام — صفحة واحدة، بدون build ولا npm. فيها رفع الصور، عارض صور مكبّر (lightbox)، بحث نصي، مشاركة إعلان، مسودة محلية لنموذج «أضف غرفة»، وعربي/إنجليزي (`toggleLang()` بيحفظ باللغة بـ`localStorage` مفتاح `mawdi_lang` ويعمل `location.reload()` — كل النصوص الثابتة عن طريق `tt(ar, en)` جنب مكان استخدامها، مش قاموس مركزي). `FEATURES`/`TAGS` كائنات `{slug, ar, en}` — الـslug هو المخزّن بالقاعدة، `FEATURE_LABEL()`/`TAG_LABEL()` بيترجموه وقت العرض. |
| `public/page.html` | صفحات المحتوى (كيف بشتغل موضع · سياسة الخصوصية · شروط الاستخدام) — بتقرأ من جدول `pages`. ثنائي اللغة (نفس نمط `index.html`) — `title_en`/`body_en` لو فاضيين بترجع للعربي. |
| `public/owner.html` | رابط المالك الموقّع — بتوكن `profiles.owner_token`، بدون تسجيل دخول. عربي بس (لوحة داخلية للمالك، مش أولوية ترجمة). |
| `public/institutions.html` | نموذج التقاط طلبات المؤسسات/NGOs — عبر `submit_institution_lead`. ثنائي اللغة. |
| `public/admin/index.html` | مركز التحكم — منشور على `/admin`، دخول عبر Supabase Auth. عربي بس دايماً (أداة داخلية للطاقم). |
| `src/whatsapp.js` | `sendWhatsAppTemplate()` — مجهّز، غير مستدعى من أي مكان لحد ما يصير حساب Meta جاهز |
| `src/worker.js` | بيمرّر لـ`ASSETS` ويضيف `X-Robots-Tag: noindex` على `/admin`، وعلى `/?l=REF` بيبدّل meta tags (عنوان/وصف/`og:image`) بجلب بيانات الإعلان من `v_listings_public` بمفتاح anon، وبيولّد `/robots.txt` و`/sitemap.xml` ديناميكياً (الأخير فيه كل إعلان منشور) |
| `wrangler.toml` | `main` + `binding = "ASSETS"` + `run_worker_first = true` |
| `supabase/migrations/` | لازم تطابق `supabase_migrations` بالحرف — العدد والحالة: `npx supabase migration list` |

**Supabase**
- ref: `yckteijitcqjtedoyoyv` (eu-central-1، Postgres 17.6) · URL: `https://yckteijitcqjtedoyoyv.supabase.co`
- anon key عام ومسموح يظهر بالكود. `service_role` **ممنوع** يظهر بأي ملف — وما عاد يُلصق يدوياً بمركز التحكم أصلاً.
- نظامين مفاتيح: JWT قديم (`eyJ...`) وجديد (`sb_publishable_...` / `sb_secret_...`). أي كود بيتعامل مع مفتاح لازم يقبل الشكلين.

**Storage**
- bucket `listing-images` — عام (قراءة)، حجم أقصى ٥ MB، أنواع مسموحة `jpeg`/`png`/`webp` فقط. `anon`/`authenticated` عندهم `insert`، و`authenticated`+`is_staff()` عندهم كمان `delete`. ممنوع `update` للجميع.
- الرفع بيصير من متصفح المالك مباشرة قبل `submit_listing` (روابط بـ`p_images`). الطاقم بيرفع/يحذف/يرتّب من اللوحة عبر `admin_listing_images`.
- ممنوع حذف/تعديل صفوف `storage.objects` مباشرة بـSQL (حتى بـservice_role) — `protect_delete` trigger بيرفض. الحذف عبر Storage API فقط.

**Cloudflare**
- Worker: `sakan` → `sakan.abdallatif-tiyah.workers.dev`. النشر يدوي: `npx wrangler deploy`. **ما في CI/CD.**
- أسرار `ADMIN_USER`/`ADMIN_PASS` (Basic Auth القديم) ما عاد الـWorker يستخدمها — الحماية صارت بالقاعدة.

**الجداول (١٨)**
`admin_actions` · `areas` · `cities` · `contact_requests` · `events` · `institution_leads` ·
`listing_safety` · `listings` · `owner_fees` · `pages` · `profiles` · `promo_codes` · `reports` ·
`reviews` · `seeker_requests` · `settings` · `staff` (فيها `username` — اختياري، فريد بدون حساسية لحالة الأحرف) · `verification_log`

**الأنواع (enums) الإضافية:** `staff_role` (`admin` · `agent`) · `institution_org_type` · `institution_lead_status`

**ربط حساب طاقم جديد** (بعد إنشائه من Dashboard بـAuto Confirm):
```sql
select link_staff('email@example.com', 'الاسم بالعربي', 'agent', 'username');
```
لازم `select` قبلها. الترتيب: إيميل، اسم، دور (`admin`/`agent`)، يوزرنيم (اختياري، أو `null`).

**قاعدة migrations:** لا تعيد ترقيم ملف موجود — الريبو لازم يطابق `supabase_migrations` بالحرف. تحقّق دايماً بـ`npx supabase migration list`.

## من يقرأ ماذا

**`anon` — الموقع العام**

| نوع | الأسماء |
|---|---|
| قراءة | `v_listings_public` · `v_requests_public` · `cities` · `areas` · `pages` |
| كتابة (insert فقط) | `contact_requests` · `reports` · `events` |
| دوال | `submit_listing` · `submit_request` · `confirm_listing_available` · `bump_listing_view` · `staff_email_for_username` (تحويل يوزرنيم لإيميل قبل تسجيل الدخول — ما بترجّع غير الإيميل) · `review_link_info` · `submit_review` · `owner_dashboard` · `submit_institution_lead` — كلهن بدون تسجيل دخول |

**`authenticated` (بشرط `is_staff()`/`is_admin()`) + `service_role` — مركز التحكم فقط**

الواجهات الداخلية (فيها أرقام هواتف — **ممنوع منح `anon` عليها إطلاقاً**) صارت `security_invoker = on`، والحماية الفعلية سياسة `staff_read` على الجداول تحتها:
`v_admin_listings` · `v_admin_owners` · `v_admin_seekers` · `v_admin_requests` · `v_admin_reports` · `v_admin_pipeline` · `v_admin_fees` · `v_admin_activity` · `v_kpi_daily` · `v_kpi_core` · `v_kpi_quality` · `v_reverse_matches`

الدوال الإدارية (١٧) — كل وحدة فيها حارس `if not (is_staff() or auth.uid() is null) then raise exception` (أربعة بـ`is_admin()`: `admin_profile_block` · `admin_set_setting` · `admin_page_save` · `admin_report_status`)، ومنحصرة بـ`authenticated, service_role`:
`admin_listing_status` · `admin_listing_verification` · `admin_listing_extend` · `admin_request_status` · `admin_profile_level` · `admin_profile_block` · `admin_report_status` · `admin_fee_status` · `admin_fee_promo` · `admin_contact_status` · `admin_save_safety` · `admin_city_save` · `admin_area_save` · `admin_page_save` · `admin_set_setting` · `admin_log` · `admin_listing_images`

> `admin_listing_images` بدون `p_actor` إطلاقاً — الفاعل من `auth.uid()` حصراً. `auth.uid() is null` (استدعاء من `service_role`/SQL مباشر) بيعدّي الحارس، لطوارئ القاعدة فقط.

> **درس:** لما view تصير `security_invoker = on`، أي دالة مستخدَمة **جوّا تعريف الـview نفسه** بتتفحص صلاحيتها على حساب **الفاعل**، مش مالك الـview. `v_reverse_matches` بتنادي `sakan_match_score()` وكانت `service_role` بس ففشلت لأي `authenticated` — الإصلاح: منح `execute` صريح لـ`authenticated`.

**واتساب Business API — مجهّز بالكود، غير مفعّل (`src/whatsapp.js`)**
- التواصل الحالي كله يدوي عبر روابط `wa.me` — شغّال ومش محتاج أي حساب. `whatsapp.js` بديل تلقائي جاهز لما يصير في حساب.
- قبل ما يشتغل: حساب Meta Business موثّق + تطبيق WhatsApp + رقم مخصّص + permanent token + Phone Number ID + اعتماد ٣ قوالب رسائل (تفاصيل بتعليق أعلى الملف).
- بعد الجهوزية: `npx wrangler secret put WHATSAPP_TOKEN` و`WHATSAPP_PHONE_ID` ثم استدعاء `sendWhatsAppTemplate()` من `worker.js`. **لا تفعّلها بدون حساب حقيقي مختبر.**

## قواعد حاكمة — ممنوع كسرها

1. **الخصوصية:** أرقام الهواتف، العناوين الدقيقة، وجهة العمل **ما بتظهر أبداً** بأي واجهة عامة.
2. الموقع العام بيقرأ من `v_listings_public` و`v_requests_public` و`cities` و`areas` و`pages` **فقط**.
3. `v_admin_*` و`v_reverse_matches` و`v_kpi_*` أدوات داخلية. ممنوع منح `anon` صلاحية عليها إطلاقاً.
4. أي تعديل schema بيصير **كملف migration بالريبو + ينطبّق على القاعدة**. الاتنين مع بعض. **ممنوع SQL Editor.**
5. **ممنوع كتابة أي مفتاح سري بأي ملف بالريبو.** الدخول لمركز التحكم بإيميل/كلمة سر عبر Supabase Auth؛ `access_token`/`refresh_token` بينحفظوا بـ`sessionStorage` فقط، وما في لصق `service_role` إطلاقاً.
6. `/admin` بيوصله أي حدا (`200` + شاشة دخول) — الحماية الفعلية صارت بالقاعدة: حارس `is_staff()`/`is_admin()` جوّا كل دالة إدارية + `security_invoker` على الواجهات. أي تعديل على `worker.js` بيتبعه فحص: `/admin` = `200`، الجذر = `200`.
7. **أي سكربت تأمين بيسحب صلاحيات لازم يستثني `service_role` صراحةً.**
8. **`robots.txt` ما بيذكر `/admin` إطلاقاً.** الحماية = شاشة دخول Supabase Auth + `X-Robots-Tag: noindex` (مش `robots.txt`).
9. المنصة **مش** أداة مراقبة. صفحة طمأنة الأهل بتوصف السكن، مش بتتبّع الساكن.
10. بدون dependencies جديدة. vanilla JS.
11. **أي `function` جديدة:** `revoke execute … from public;` ثم `grant execute … to` الأدوار المقصودة صراحةً. التحقق الوحيد المعتبر: `has_function_privilege('anon','<sig>','execute') = false`.
12. **القيم التجارية بتنقرأ من `settings`، مش مكتوبة بالكود.** لا ترجّعها لأرقام ثابتة.
13. **المدن والمناطق بتنقرأ من القاعدة، مش من مصفوفة بالجافاسكربت.**
14. **بند الكاميرا ملاحظة مندوب، مش ضمانة.** الحماية الحقيقية = بلاغ `category='camera'` بيشغّل `suspend_on_serious_report`.
15. **دور المندوب بمركز التحكم حاجز تشغيلي مش أمني.** أي حدا معه مفتاح الخدمة بيقدر يعمل كل شي.
16. **الأدوار من القاعدة (`staff`) مش من الواجهة.** `p_actor` النصي ممنوع بكل الدوال الإدارية — الفاعل بييجي حصراً من `auth.uid()` عبر `actor_name()`/`is_staff()`/`is_admin()`.

## السياق التجاري

- **الموسمية:** ذروة آب–تشرين أول، ذروة أصغر شباط. السرعة أهم من الكمال.
- **بوابة القرار:** أرقام الغرف/التأجيرات والتاريخ بجدول `settings` (`gate_rooms`/`gate_rentals`/`gate_date`).
- **مؤشر PMF الأساسي:** نسبة إعادة الإدراج من المالك خلال ٦٠ يوم (`v_kpi_quality.owner_repeat_pct`).
- **الدخل:** رسم نجاح يُحصّل نقداً عبر المندوب (القيمة بـ`settings.fee_base`). الباحث مجاني. `MAWDI50` كود خصم (القيمة والحد بجدول `promo_codes`).
- **التسعير:** الرسم أرخص من قيمة الخدمة. **لا تنزّل الرسم أبداً** — الخصم بكود، مش بتغيير السعر.
- **المؤسسات/NGOs:** تسعير معكوس — المؤسسة تدفع لكل غرفة والمالك ما بيدفع. `institutions.html` بس بتلتقط الطلب — التسعير والمتابعة يدوية بالكامل.
- **قانوني:** التسجيل بوزارة الاقتصاد الوطني حسب قانون التجارة الإلكترونية رقم ٢١ لسنة ٢٠٢٥ شرط لفوترة المؤسسات — الحالة الفعلية بـ`STATUS.md`.

## خارج النطاق (لا تبنيه)

شات داخلي · بوابة دفع · حساب ضمان (escrow) · تطبيق أصلي · إيجار يومي/سياحي · أي ميزة بتأخّر الإطلاق.

> **تسجيل دخول للمالك والباحث** خارج النطاق كحساب/كلمة سر. البديل المعتمد: **رابط موقّع بدون كلمة سر** (زي `confirm_token`/`owner_token`) — بيعطي ٩٠٪ من الفايدة بدون خسارة نموذج «بدون تسجيل».

## أسلوب العمل

- اشتغل بالعربي. الكود بالإنجليزي، التعليقات والواجهة بالعربي.
- بأول كل جلسة: اقرأ `STATUS.md` قبل أي شي.
- قبل أي تعديل schema: اقرأ آخر migration أولاً.
- بعد أي تعديل: commit برسالة وصفية وpush.
- لا تعيد كتابة ملف كامل لو التعديل سطرين. الملفات الصغيرة (أقل من ١٠٠ سطر) بتنكتب كاملة بالشات وبتنلصق.
- بأول أي محادثة جديدة، شغّل وابعت النتيجة: `ls` · `ls public` · `Get-Content wrangler.toml` · `git log --oneline -5` · `npx supabase migration list`
- بآخر كل جلسة: حدّث «آخر جلسة» و«سجل الجلسات» بـ`STATUS.md`. حدّث `CLAUDE.md` فقط لو تغيّرت البنية أو القواعد.
- **مستندات الإدارة (قرارات، عقود، SOPs) بمجلد `Sakan-HQ` محلي — برّا الريبو.**
