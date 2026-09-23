# سكن (Sakan) — دليل المشروع

منصة تأجير غرف وسكن مشترك موثّق في رام الله والبيرة وبيرزيت.
واجهة عربية RTL. باك إند Supabase. نشر على Cloudflare Workers.

> **الاسم سكنّا (Sakanna).** كل نص وواجهة عامة تقول «سكنّا»/Sakanna (النصوص، كود الخصم `SAKANNA50`، مفتاح اللغة `sakanna_lang`).
> **استثناء موثّق:** بادئة مرجع الإعلان `SK-` (لا `MW-`) — قرار بتاريخ ٢٠٢٦-٠٩-١٤ بإرجاعها لـ«سكن» عمداً رغم إن باقي الواجهة العامة «سكنّا». المصدر الوحيد: `set_listing_ref()` (تريغر على `listings`) + `listing_ref_seq` (أُعيد ضبطه لـ١٠٠١ وقت التبديل — migration `20260914145004_listing_ref_prefix_sk`).
> **البنية التحتية** (اسم الـWorker `sakan`، اسم المستودع، وكل الأسماء التقنية بالقاعدة) ثابتة بـ«سكن» — قرار أبواللطيف، خارج نطاق مساعدة Claude. **استثناء:** النطاق العام الفعلي `sakanna.ps` (لا `sakan.ps`) — اشتراه أبواللطيف من domain.ps وربطه بتاريخ ٢٠٢٦-٠٩-٢٠، مطابقاً لاسم العلامة «سكنّا» لا لاسم الـWorker. لا تخلط بين الاسمين لما تدور بالكود.

**للحالة الحالية (أرقام، آخر جلسة، مهام مفتوحة): `STATUS.md`.**
هذا الملف للثابت فقط — بنية، صلاحيات، قواعد، تشخيص. ما بينحدّث إلا لما تتغيّر بنية أو قاعدة.

---

## البنية

| ملف | الوصف |
|---|---|
| `public/index.html` | الموقع العام — صفحة واحدة، بدون build ولا npm. فيها رفع الصور، عارض صور مكبّر (lightbox)، بحث نصي، مشاركة إعلان، مسودة محلية لنموذج «أضف غرفة» (`localStorage` — بتنحفظ تلقائياً وبتنمسح بعد الإرسال الناجح)، وعربي/إنجليزي (`toggleLang()` بيحفظ باللغة بـ`localStorage` مفتاح `sakanna_lang` ويعمل `location.reload()` — كل النصوص الثابتة عن طريق `tt(ar, en)` جنب مكان استخدامها، مش قاموس مركزي). `FEATURES`/`TAGS` كائنات `{slug, ar, en}` — الـslug هو المخزّن بالقاعدة، `FEATURE_LABEL()`/`TAG_LABEL()` بيترجموه وقت العرض. |
| `public/page.html` | صفحات المحتوى (كيف بشتغل سكنّا · سياسة الخصوصية · شروط الاستخدام) — بتقرأ من جدول `pages`. ثنائي اللغة — `title_en`/`body_en` لو فاضيين بترجع للعربي. |
| `public/owner.html` | رابط المالك الموقّع — `?id=..&t=..` بتوكن `profiles.owner_token`، بدون تسجيل دخول. بيوريه إعلاناته وطلبات التواصل عليها. عربي بس. |
| `public/institutions.html` | نموذج التقاط طلبات المؤسسات/NGOs — عبر `submit_institution_lead`. ثنائي اللغة. |
| `public/account.html` | حساب اختياري (مالك/باحث/الاثنين) عبر Supabase Auth بالبريد وكلمة السر. لوحة ذاتية عبر `my_owner_dashboard`/`my_seeker_dashboard`، ربط صفة جديدة عبر `link_account_role`، جرس إشعارات (قراءة/تحديث مباشر من جدول `notifications` بجلسة المستخدم). ثنائي اللغة. `access_token`/`refresh_token` بـ`sessionStorage` فقط. |
| `public/admin/index.html` | مركز التحكم — منشور على `/admin`، دخول عبر Supabase Auth. عربي بس دايماً (أداة داخلية للطاقم). فيه قسمي «المستخدمون» و«الإشعارات» فوق نفس التوكنز الغامقة القديمة (لم تُستبدل بالكامل — قرار متحفّظ، شوف «الهوية البصرية»). |
| `src/whatsapp.js` | `sendWhatsAppTemplate()` — مجهّز، غير مستدعى من أي مكان لحد ما يصير حساب Meta جاهز |
| `src/worker.js` | بيمرّر لـ`ASSETS` ويضيف `X-Robots-Tag: noindex` على `/admin`، وعلى `/?l=REF` بيبدّل meta tags (عنوان/وصف/`og:image`) بجلب بيانات الإعلان من `v_listings_public` بمفتاح anon قبل ما يرجّع الصفحة، وبيولّد `/robots.txt` و`/sitemap.xml` ديناميكياً (الأخير فيه كل إعلان منشور) |
| `wrangler.toml` | `main` + `binding = "ASSETS"` + `run_worker_first = true` |
| `supabase/migrations/` | لازم تطابق `supabase_migrations` بالحرف — العدد والحالة: `npx supabase migration list` |

> **التسجيل ببريد وكلمة سر بدون تأكيد.** خدمة البريد المدمجة في Supabase لا تسلّم إلا لأعضاء الفريق، لذا لا رسائل تأكيد ولا استرجاع كلمة سر. الاسترجاع إجراء يدوي: تعيين كلمة سر جديدة من لوحة Auth. **ممنوع حذف مستخدم من لوحة Auth قبل التحقق من قاعدة الحذف على `profiles.account_uid`** (لا يوجد قيد مفتاح خارجي على العمود أصلاً — تحقّق حيّ: `select confdeltype from pg_constraint where conname like '%account_uid%'` يرجع صفراً، فلا cascade مرتبط بالعمود، لكن تحقّق من جديد لو أُضيف قيد لاحقاً). يُعاد تفعيل التأكيد بعد ربط النطاق وتوثيق مزوّد إرسال.

**Supabase**
- ref: `yckteijitcqjtedoyoyv` (eu-central-1، Postgres 17.6) · URL: `https://yckteijitcqjtedoyoyv.supabase.co`
- anon key عام ومسموح يظهر بالكود. `service_role` **ممنوع** يظهر بأي ملف — وما عاد يُلصق يدوياً بمركز التحكم أصلاً.
- نظامين مفاتيح: JWT قديم (`eyJ...`) وجديد (`sb_publishable_...` / `sb_secret_...`). أي كود بيتعامل مع مفتاح لازم يقبل الشكلين.

**Storage**
- bucket `listing-images` — عام (قراءة)، حجم أقصى ٥ MB، أنواع مسموحة `jpeg`/`png`/`webp` فقط. `anon`/`authenticated` عندهم `insert`، و`authenticated`+`is_staff()` عندهم كمان `delete`. ممنوع `update` للجميع.
- الرفع بيصير من متصفح المالك مباشرة قبل `submit_listing` (الروابط بتنمرّر كـ`p_images` بنفس الاستدعاء). الطاقم بيرفع/يحذف/يرتّب من اللوحة عبر `admin_listing_images`.
- ممنوع حذف/تعديل صفوف `storage.objects` مباشرة بـSQL (حتى بـ`service_role`) — `protect_delete` trigger بيرفض. الحذف عبر Storage API فقط.

**Cloudflare**
- Worker: `sakan` → `sakan.abdallatif-tiyah.workers.dev` **و** Custom Domains `sakanna.ps`/`www.sakanna.ps` (الأخير بيحوّل `301` للأول — منطق التحويل بـ`src/worker.js`، مش Cloudflare Redirect Rule). الدومين مسجّل بـdomain.ps، أسماء سيرفراته أشيرت لـCloudflare (`roan.ns.cloudflare.com`/`sue.ns.cloudflare.com`) بتاريخ ٢٠٢٦-٠٩-٢٠. الربط عبر `[[routes]]` بـ`wrangler.toml` (`custom_domain = true` لكل نطاق) — **لازم** `workers_dev = true` مكتوبة صراحة بنفس الملف، وإلا Wrangler بيعطّل رابط `workers.dev` تلقائياً أول ما يلاقي أي route (شوف جدول التشخيص). النشر يدوي: `npx wrangler deploy`. **ما في CI/CD.**
- أسرار `ADMIN_USER`/`ADMIN_PASS` (Basic Auth القديم) ما عاد الـWorker يستخدمها — الحماية صارت بالقاعدة.

**الجداول (٢٠)**
`admin_actions` · `areas` · `cities` · `contact_requests` · `events` · `institution_leads` ·
`listing_safety` · `listings` · `notifications` · `owner_fees` · `pages` · `profiles` · `promo_codes` · `reports` ·
`reviews` · `saved_listings` · `seeker_requests` · `settings` · `staff` (فيها `username` — اختياري، فريد بدون حساسية لحالة الأحرف) · `verification_log`

**الحسابات (اختيارية، إضافية فوق النموذج بدون تسجيل):**
- `profiles.account_uid` (uuid، غير فريد، مفهرس) — يربط صف `profiles` بحساب Supabase Auth (`auth.users.id`). فهرس فريد جزئي `(account_uid, role)` بيمنع أكثر من صف بنفس الصفة لنفس الحساب — شخص واحد ممكن يفعّل مالك **و**باحث بنفس الوقت (صفّان منفصلان بنفس `account_uid`).
- **لا ربط تلقائي بالرقم.** `link_account_role()` بينشئ صف `profiles` جديد مربوط بالحساب دايماً — ما بيسطو على صف قديم غير مربوط بمطابقة الهاتف (لأن الهاتف مش مُتحقَّق منه بأي OTP، والمطابقة التلقائية كانت بتفتح ثغرة انتحال). ربط صف قديم بحساب موجود = يدوي حصراً عبر `admin_link_profile()` بعد ما الطاقم يتأكد هاتفياً إنه نفس الشخص (نفس منطق التوثيق الهاتفي الموجود أصلاً). **نفس المبدأ ينطبق على `submit_listing()`** (migration `20260914204457`): كانت تربط الإعلان الجديد بأي صف `profiles` بدور `owner` بمطابقة الهاتف وحده — أي حدا يعرف رقم مالك حقيقي كان يقدر ينشر إعلاناً منسوباً لبروفايله. صارت تنشئ صف `profiles` جديد **دايماً** بدون أي `lookup` بالهاتف. الأثر الجانبي المقصود: أي شخص يكرّر التسجيل بدون حساب بياخد صف `profiles` جديد كل مرة (نفس الهاتف، `id` مختلف)، ودمج الصفوف المكررة يدوي بالكامل (لا أداة دمج تلقائي — `admin_link_profile()` بتربط صف بحساب Auth موجود، **ما بتدمج** إعلانات صفّين منفصلين ببعض). هالأثر كسر `owner_repeat_pct` مؤقتاً (كانت بتجمّع بـ`listings.owner_id`) — الإصلاح موثّق تحت «السياق التجاري».
- `notifications` — RLS: `self_read`/`self_update` (`account_uid = auth.uid()`) + `staff_read`. **بدون** سياسة `insert` لـ`authenticated` — الإدراج فقط من دوال/محفزات `SECURITY DEFINER` (مالكها بيتجاوز RLS). العميل بيقرأ/يعلّم كمقروء مباشرة عبر REST بجلسته — **هذا مقصود ومطابق لمبدأ «كل منطق عبر RPC»**: ذاك المبدأ يخص منطق العمل (قرارات، تحقّق، تغيير حالة)، والقراءة/التعليم بمقروء هون مجرد صف محمي بالكامل بـRLS بلا أي منطق، فمسار REST المباشر سليم عمداً. المنحة على `update` مقيَّدة لعمود `is_read` فقط (`grant update (is_read) on notifications to authenticated`) — لأن `with check` بسياسة RLS يحرس **الصفوف** (مين يملك الصف) لا **الأعمدة** (أي حقل يقدر يتغيّر)، فبدون تقييد العمود يقدر المستخدم يزوّر `title`/`body`/`event_type` بصفوفه الخاصة (لا يمسّ غيره — RLS يمنع النقل بين حسابات، لكنه لا يمنع هذا التزوير الذاتي).
- `saved_listings` — سياسة `self_all` (`account_uid = auth.uid()`)، PK مركّب `(account_uid, listing_id)`.
- محفزات إشعار تلقائي: `notify_contact_request` (AFTER INSERT على `contact_requests`) · `notify_listing_change` (AFTER UPDATE OF status,verification على `listings` — وفيها منطق تطابق للباحثين المنشورين عند أول نشر) · `notify_request_published` (AFTER UPDATE OF status على `seeker_requests`) · `notify_expiring_soon` (مجدولة عبر `pg_cron`، مش RPC عام — القيمة من `settings.expiring_soon_days` مش رقم ثابت).

**الأنواع (enums) الإضافية:** `staff_role` (`admin` · `agent`) · `institution_org_type` · `institution_lead_status` · `currency_code` (`ILS`/`JOD`/`USD` — عملة `listings.price`/`listings.deposit` معاً، عمود واحد لكل إعلان) · `rental_period` (`monthly`/`weekly`/`daily` — `listings.rental_period` غير قابل للـnull، افتراضي `monthly`؛ `seeker_requests.rental_period_pref` نفس النوع لكن قابل للـnull = مرن)

**ربط حساب طاقم جديد** (بعد إنشائه من Dashboard بـAuto Confirm):
```sql
select link_staff('email@example.com', 'الاسم بالعربي', 'agent', 'username');
```
لازم `select` قبلها. الترتيب: إيميل، اسم، دور (`admin`/`agent`)، يوزرنيم (اختياري، أو `null`).

**قاعدة migrations:** لا تعيد ترقيم ملف موجود — الريبو لازم يطابق `supabase_migrations` بالحرف. تحقّق دايماً بـ`npx supabase migration list`.

---

## من يقرأ ماذا

**`anon` — الموقع العام**

| نوع | الأسماء |
|---|---|
| قراءة | `v_listings_public` · `v_requests_public` · `cities` · `areas` · `pages` |
| كتابة (insert فقط) | `contact_requests` · `reports` · `events` |
| دوال | `submit_listing` (منذ ٢٠٢٦-٠٩-٢١ فيها `p_promo_code` اختياري — شوف قاعدة ١٧) · `submit_request` · `confirm_listing_available` · `bump_listing_view` · `staff_email_for_username` (تحويل يوزرنيم لإيميل قبل الدخول — ما بترجّع غير الإيميل) · `review_link_info` · `submit_review` · `owner_dashboard` · `owner_contact_status` (تغيير حالة طلب تواصل من طرف المالك بتوكنه الموقّع — بيسمح فقط بـ`owner_responded`/`viewing_set`/`dead`؛ `rented`/`forwarded`/`new` مرفوضة دايماً، `rented` تحديداً لأنها حدث فوترة بتخلق صف `owner_fees` عبر `on_contact_rented` وتضل بيد الطاقم حصراً) · `submit_institution_lead` · `quote_listing_fee(p_kind listing_kind)` (رسم النوع — المصدر الوحيد لأي سعر، بيُستخدم الآن فقط داخل `quote_promo_discount`، بدون عرض مباشر بالفورم) · `quote_promo_discount(p_code text, p_kind listing_kind)` (تحقّق كود الخصم + رسم قبل/بعد — زر «تطبيق الخصم» بنموذج «أضف غرفة»، شوف قاعدة ١٧) · `active_promo()` (غير مستخدَمة حالياً من أي واجهة عامة بعد قرار ٢٠٢٦-٠٩-٢١ — باقية بالقاعدة لاحتمال استخدام مستقبلي، عرض فقط لو استُخدمت) — كلهن بدون تسجيل دخول |

**`authenticated` (حساب مسجّل، بدون شرط طاقم) — لوحة «حسابي» الذاتية فقط**

`link_account_role` · `my_profile` · `my_owner_dashboard` · `my_seeker_dashboard` — الفاعل حصراً `auth.uid()`، بدون أي `p_actor`/`p_id` يحدّد شخص غيره. `my_owner_dashboard` بتطبّق نفس بوابة القاعدة ١٨ (رقم الباحث محجوب لحد ما تصير حالة طلب التواصل غير `new`) رغم إنها ذاتية.

**`authenticated` (بشرط `is_staff()`/`is_admin()`) + `service_role` — مركز التحكم فقط**

الواجهات الداخلية (فيها أرقام هواتف — **ممنوع منح `anon` عليها إطلاقاً**) صارت `security_invoker = on`، والحماية الفعلية سياسة `staff_read` على الجداول تحتها:
`v_admin_listings` · `v_admin_owners` · `v_admin_seekers` · `v_admin_requests` · `v_admin_reports` · `v_admin_pipeline` · `v_admin_fees` · `v_admin_activity` · `v_admin_reviews` · `v_kpi_daily` · `v_kpi_core` · `v_kpi_quality` · `v_reverse_matches`

> **`v_admin_reviews` منحة صريحة، مش وراثة.** views الجداد بدون `grant select ... to authenticated, service_role` صريح ما بتنقرأ حتى من الطاقم — `security_invoker=on` وحدها مش كافية، لازم الاثنين معاً (تحقّق بـ`has_table_privilege('authenticated', '<view>', 'select')`).

> `v_admin_owners`/`v_admin_seekers` فيهن عمود `has_account` (بذيل القائمة) — `true` لو الصف مربوط بحساب Supabase Auth.

الدوال الإدارية (٢٤) — كل وحدة فيها حارس `if not (is_staff() or auth.uid() is null) then raise exception` (أربعة بـ`is_admin()`: `admin_profile_block` · `admin_set_setting` · `admin_page_save` · `admin_report_status`)، ومنحصرة بـ`authenticated, service_role`:
`admin_listing_status` · `admin_listing_verification` · `admin_listing_extend` · `admin_request_status` · `admin_profile_level` · `admin_profile_block` · `admin_report_status` · `admin_fee_status` · `admin_fee_promo` · `admin_fee_amount` · `admin_contact_status` · `admin_save_safety` · `admin_city_save` · `admin_area_save` · `admin_page_save` · `admin_set_setting` · `admin_log` · `admin_listing_images` · `admin_list_accounts` · `admin_list_notifications` · `admin_send_notification` · `admin_link_profile` · `admin_listing_update` · `admin_request_update`

> `admin_fee_amount(p_fee_id uuid, p_amount numeric, p_reason text)` — تعديل يدوي استثنائي لـ`amount_due` على صف `owner_fees` واحد، بدون `p_actor` (الفاعل من `auth.uid()` عبر `actor_name()` حصراً، قاعدة ١٦). يسجّل بـ`admin_actions` (`from_state`/`to_state` = القيمة القديمة/الجديدة كنص).

> `admin_listing_images` بدون `p_actor` إطلاقاً — الفاعل من `auth.uid()` حصراً. `auth.uid() is null` (استدعاء من `service_role`/SQL مباشر) بيعدّي الحارس، لطوارئ القاعدة فقط.

> `admin_listing_update`/`admin_request_update` (migration `20260921185205`) — تعديل الطاقم لكل الحقول اللي المالك/الباحث بيعبّيها بنموذج التسجيل العام (العنوان، الوصف، السعر، العملة، التأمين، النوع، السياسة، الفواتير الثلاثة، عدد الغرف، أقل مدة، الموقع، المواصفات/الصفات…)، لتصحيح بيانات مُدخَلة غلط بدون رجوع للمالك/الباحث. بدون `p_actor` (قاعدة ١٦). لا تلمس أعمدة الحالة/التوثيق/الصور — هاي بتبقى عبر الدوال المخصّصة الموجودة أصلاً.

> **درس:** لما view تصير `security_invoker = on`، أي دالة مستخدَمة **جوّا تعريف الـview نفسه** بتتفحص صلاحيتها على حساب **الفاعل**، مش مالك الـview. `v_reverse_matches` بتنادي `sakan_match_score()` وكانت `service_role` بس ففشلت لأي `authenticated` — الإصلاح: منح `execute` صريح لـ`authenticated`.

**واتساب Business API — مجهّز بالكود، غير مفعّل (`src/whatsapp.js`)**
- التواصل الحالي كله يدوي عبر روابط `wa.me` (تذكير الإعلانات، رابط المالك) — شغّال ومش محتاج أي حساب.
- قبل ما يشتغل: حساب Meta Business موثّق + تطبيق WhatsApp + رقم مخصّص + permanent token + Phone Number ID + اعتماد ٣ قوالب (تفاصيل بتعليق أعلى الملف).
- بعد الجهوزية: `npx wrangler secret put WHATSAPP_TOKEN` و`WHATSAPP_PHONE_ID` ثم استدعاء `sendWhatsAppTemplate()` من `worker.js`. **لا تفعّلها بدون حساب حقيقي مختبر.**

---

## قواعد حاكمة — ممنوع كسرها

1. **الخصوصية:** أرقام الهواتف، العناوين الدقيقة، وجهة العمل **ما بتظهر أبداً** بأي واجهة عامة.
2. الموقع العام بيقرأ من `v_listings_public` و`v_requests_public` و`cities` و`areas` و`pages` **فقط**.
3. `v_admin_*` و`v_reverse_matches` و`v_kpi_*` أدوات داخلية. ممنوع منح `anon` صلاحية عليها إطلاقاً.
4. أي تعديل schema بيصير **كملف migration بالريبو + ينطبّق على القاعدة**. الاتنين مع بعض. **ممنوع SQL Editor.**
5. **ممنوع كتابة أي مفتاح سري بأي ملف بالريبو.** الدخول لمركز التحكم بإيميل/كلمة سر عبر Supabase Auth؛ `access_token`/`refresh_token` بـ`sessionStorage` فقط.
6. `/admin` بيوصله أي حدا (شاشة دخول) — الحماية الفعلية بالقاعدة: حارس `is_staff()`/`is_admin()` جوّا كل دالة إدارية + `security_invoker` على الواجهات. أي تعديل على `worker.js` بيتبعه فحص: الجذر = `200`، و`/admin` = `307` (تحويل Cloudflare Assets الطبيعي لملف `index.html` داخل مجلد لمساره الحقيقي `/admin/`) يتبعه `200` على `/admin/` مع هيدر `X-Robots-Tag: noindex`.
7. **أي سكربت تأمين بيسحب صلاحيات لازم يستثني `service_role` صراحةً.**
8. **`robots.txt` ما بيذكر `/admin` إطلاقاً.** الحماية = شاشة دخول Supabase Auth + `X-Robots-Tag: noindex`.
9. المنصة **مش** أداة مراقبة. صفحة طمأنة الأهل بتوصف السكن، مش بتتبّع الساكن.
10. بدون dependencies جديدة. vanilla JS.
11. **أي `function` جديدة:** `revoke execute … from public;` ثم `grant execute … to` الأدوار المقصودة صراحةً. التحقق الوحيد المعتبر: `has_function_privilege('anon','<sig>','execute') = false`.
12. **القيم التجارية بتنقرأ من `settings`، مش مكتوبة بالكود.** لا ترجّعها لأرقام ثابتة.
13. **المدن والمناطق بتنقرأ من القاعدة، مش من مصفوفة بالجافاسكربت.** (كانت مثبّتة يدوياً بسبب فخ الـzero-policy — انحلّ.)
14. **بند الكاميرا ملاحظة مندوب، مش ضمانة.** الحماية الحقيقية = بلاغ `category='camera'` بيشغّل `suspend_on_serious_report`. (خاص حصراً بالزيارة الميدانية — عمود `listing_safety.no_indoor_cameras`. التوثيق بمكالمة فيديو ما بيفحص كاميرات إطلاقاً، وما إله صف `listing_safety` من الأساس — لا تعرض أي بند كاميرا لإعلان موثّق بفيديو.)
15. **دور المندوب بمركز التحكم حاجز تشغيلي مش أمني.** أي حدا معه مفتاح الخدمة بيقدر يعمل كل شي.
16. **الأدوار من القاعدة (`staff`) مش من الواجهة.** الفاعل يُشتق حصراً من `auth.uid()` عبر `actor_name()`/`is_staff()`/`is_admin()`. معظم الدوال الإدارية القديمة (تحقّق حي عبر `pg_get_function_identity_arguments`: `admin_set_setting`/`admin_listing_status`/`admin_report_status`/`admin_page_save`/`admin_city_save`/`admin_area_save`/`admin_contact_status`/`admin_fee_status`/`admin_listing_extend`/`admin_listing_verification`/`admin_log`/`admin_profile_block`/`admin_profile_level`/`admin_request_status`/`admin_save_safety` — خمس عشرة دالة، مش ثلاث فقط) لسا شايلة معطى `p_actor` بتوقيعها القديم — قيمة احتياطية لا تُستخدم إلا حين يكون `auth.uid()` فارغاً (`service_role`/SQL مباشر)، ولا تتجاوز حارس `is_staff()`/`is_admin()` أبداً (تحقّق عملياً بتدقيق ٢٠٢٦-٠٩-٠٥: مستخدم `authenticated` عادي مرّر `p_actor` بقيمة `'admin'` وانرفض بـ"غير مصرّح" رغم ذلك). الدوال الأحدث (`admin_fee_amount`/`admin_listing_images`/`admin_fee_promo`/`admin_institution_lead_status`/`admin_link_profile`/`admin_send_notification`/`admin_listing_update`/`admin_request_update`) اتضافت **بدونه عمداً**. **ممنوع إضافته لأي دالة جديدة**، وممنوع جعله مصدر الفاعل حين يكون `auth.uid()` موجوداً.
17. **كود الخصم يدخله المالك ذاتياً وقت التسجيل، أو الطاقم وقت التحصيل — قرار بتاريخ ٢٠٢٦-٠٩-٢١ يلغي المنع الأصلي (كان: «يدخله الطاقم فقط، ممنوع أي حقل إدخال بواجهة عامة»، خوفاً من استغلال بدون تحقق مندوب).** نموذج «أضف غرفة» بـ`index.html` فيه حقل كود خصم + زر «تطبيق الخصم» بآخر الفورم (بعد وصف السكن، قبل زر الإرسال). الزر بينادي `quote_promo_discount(p_code, p_kind)` — بترجّع الخصم الحقيقي من `promo_codes` والرسم قبل/بعد من `quote_listing_fee`، وبتفشل بنفس فحوصات `admin_fee_promo` (موجود/مفعّل/غير منتهي/تحت حد الاستخدام) لو الكود غلط. **ممنوع أي نص ثابت يقول «صفر شيكل»** — الرسالة المعروضة (بعربي وإنجليزي) لازم تُبنى من `discount_pct`/`fee_after` الفعليين العائدين من الدالة؛ تقول «صفر» بس لو `fee_after = 0` حقيقةً (كود بخصم ١٠٠٪). الكود المكتوب بينمرّر أيضاً كـ`p_promo_code` لـ`submit_listing()` (يتحقّق منه بنفس الفحوصات مرة ثانية وقت الإرسال، ويُخزَّن بـ`listings.promo_code`) — الزر تجربة/تأكيد فوري، مش بوابة: حتى لو المالك كتب الكود وضغط إرسال بدون الضغط على «تطبيق»، الكود لسا بينطبّق. عند التأجير، `on_contact_rented()` بينسخ `listings.promo_code` تلقائياً لصف `owner_fees.promo_code` الجديد — و`compute_fee_due()` (الموجودة أصلاً، بدون تعديل) بتعيد التحقق والحساب وقتها، فكود انتهى/نفد بين التسجيل والتحصيل بيرجع تلقائياً للسعر الكامل. الطاقم يقدر يبدّل/يلغي الكود المطبَّق لاحقاً عبر `admin_fee_promo()` كما كانت (بدون تعديل عليها). **ممنوع** إضافة هذا الحقل بـ`owner.html` (الرابط الموقّع بعد الإرسال) — الإدخال حصراً بلحظة التسجيل الأولى بـ`index.html`. `active_promo()` صارت غير مستخدَمة من أي واجهة عامة (كانت تعرض الكود النشط للعلم فقط) — باقية بالقاعدة بدون حذف.
18. **رقم الباحث ما بيظهر للمالك بـ`owner.html` إلا بعد ما حالة الطلب تصير غير `new`** — نفس بوابة التحويل اليدوي. الرابط الموقّع مش واجهة عامة، فالقاعدة ١ ما بتغطيه.
19. **ممنوع موقع دقيق لأي غرفة مشغولة على خريطة.** لو انبنى عرض خرائطي: دائرة تقريبية ٣٠٠–٥٠٠م + نص عربي واضح إنه العنوان الدقيق بيعطيه المندوب وقت ترتيب الزيارة. دبوس دقيق + سياسة الجنس على إعلان عام = خطر على الساكن.
20. **لا تنزّل رسم النجاح أبداً.** الخصم بكود خصم فقط، مش بتغيير `settings.fee_base`. رفع السعر من صفر أصعب بنيوياً من التخفيض.
21. **نصوص الموقع ما بتوحي بمخزون كبير.** كل ادّعاء لازم يكون مسنود بالبيانات الفعلية بالقاعدة. طلبات الباحثين هي دليل الطلب لاستقطاب الملّاك، مش العكس.
22. **المصطلح الجامع لكل نصوص الواجهة العامة: «سكن»** (وللجمع «وحدات»)، لأنه `listing_kind` فيه أكثر من نوع (`room_shared`/`bed_shared`/`studio`/`apartment`/`family`). كلمة «غرفة» تُستعمل فقط لما السياق فعلاً عن نوع محدّد (تسمية `listing_kind` نفسها، أو حقل عددي زي «عدد الغرف بالسكن»)، مش وصف عام للمنصة. **`bed_shared` و`family` موجودتان بالـenum ومسعّرتان (`fee_bed_shared`/`fee_family` بـ`settings`) لكن مش معروضتين بمنتقي النوع بأي نموذج عام** (`index.html` — لا بنموذج «أضف غرفة» ولا بتفضيل نوع الباحث) — القيمتان تبقيان صالحتين لإعلانات قديمة أو حالات يدوية استثنائية، بس مش خيار عند إضافة إعلان جديد.
23. **نبرة النصوص العامة: عربية فصحى معاصرة بسيطة**، مش محكية ومش لغة شركات متكلّفة. جملة قصيرة، فعل مباشر. بدون «نسعى»/«حلول متكاملة»/«فريقنا»، وبدون علامات تعجب أو إيموجي. (مركز التحكم استثناء — عربي داخلي عادي، مش موجّه لعامة الناس.)
24. **أي إعلان موثّق لازم يذكر طريقة التوثيق والتاريخ بالكلمات — ممنوع عرض «موثّق» وحدها بأي واجهة عامة.** النصوص الحرفية الوحيدة المسموحة: «موثّق بزيارة ميدانية — [التاريخ]» (`verification='field'`، التاريخ من `listing_safety.visit_date`) و«موثّق بمكالمة فيديو — [التاريخ]» (`verification='video'`، التاريخ من `listings.video_verified_at`)، وبالإنجليزي عبر `tt()`: "Verified by site visit" / "Verified by video call". **الإعلان غير الموثّق (`none`) ما بيعرض أي نص توثيق إطلاقاً — بدون اختراع تسمية بديلة له.** `verifBadge()` بـ`index.html` هي المصدر الوحيد لهالنص — أي مكان تاني يعرض توثيق لازم يستدعيها، مش يعيد كتابة المنطق.
    > **`desk` قيمة تاريخية بالـenum، مش خيار متاح.** كانت موجودة (وقابلة للضبط من اللوحة) قبل بناء نظام الطبقتين، واكتُشفت أثناء البناء **حيّة وغير موثّقة بـ`CLAUDE.md`** — بالضبط الفشل اللي قاعدة ٢٤ وُجدت لمنعه: إعلان مصنَّف موثّق داخلياً (`verification='desk'`) بدون أي نص توثيق يظهر للعامة إطلاقاً (`verifBadge()` ما كانت تغطيها بتاريخ، بادج قديم بلا معنى). أُزيل زر ضبطها من اللوحة (`238e9f1`) — بقيت بالـenum لأن PostgreSQL ما بيسمح بحذف قيمة enum (يحتاج إعادة بناء النوع وكل view تابع له)، وبقيت بكائنات `L_VERIF`/`VER` كنص احتياطي لو صف قديم طلع. **ممنوع تفعيلها من جديد بأي زر/واجهة قبل تعريف نصّها العلني بالعربي وإجراء توثيقها بدقة** (بالضبط متل ما صار مع الميداني والفيديو) — إعادة تفعيلها بدون هالخطوتين تكرار لنفس الفشل.

---

## الهوية البصرية

- **التوكنز** (بكل ملف `public/*.html` عدا `admin/index.html`): `--blue-700:#12309B` `--blue-600:#1E45D6` `--blue-500:#3A63F0` `--blue-100:#E4EAFF` `--blue-050:#F2F5FF` `--amber:#F5A524` `--amber-ink:#9A5B00` `--navy:#080F2E` `--ink:#080F2E` `--mut:#6B748F` `--bg:#F2F5FF` `--card:#FFFFFF` `--line:#E1E6F5` `--ok:#12A150` `--warn:#C2410C` `--danger:#DC2626`. أشكال: `--r-sm:8px` `--r:14px` `--r-lg:20px` `--r-pill:999px`. ظل واحد `--sh:0 10px 30px rgba(8,15,46,.10)` — بدون تدرّجات ولا تكديس ظلال.
- **قاعدة الزر الكهرماني:** `--amber` تعبئات فقط، **زر أساسي واحد بالشاشة الواحدة** (`.btn.acc`، نص `var(--navy)` أو `var(--amber-ink)` — أبيض على كهرماني ضعيف التباين). أي زر إضافي يصير `--blue-600`.
- **الشعار:** أيقونة SVG ثابتة (مبنى بثلاث كتل + نافذة كهرمانية) — نسخة عادية (`fill="var(--blue-600)"`، لخلفية بيضاء) ونسخة معكوسة (`fill="#FFFFFF"` + نافذة `var(--amber)`، لخلفية زرقاء غامقة). البلاطة/الفافيكون (`public/favicon.svg`, `public/favicon-16.svg`) بخلفية `#1E45D6` مربّعة الزوايا. **الرمز نفسه لا يُعكس أبداً بين عربي/إنجليزي** — بس ترتيب DOM (الأيقونة قبل النص بالعربي) بيخلّيها تظهر يمين النص تلقائياً بـRTL.
- **الخطوط:** `IBM Plex Sans Arabic` للنص كله، `Archivo` للاتيني بالشعار (`SAKANNA` تحت «سكنّا») وعناوين إنجليزية فقط. ارتفاع سطر عربي ≥ 1.60 دايماً. بدون `letter-spacing`/`italic` عربي.
- **`public/admin/index.html` قرار متحفّظ:** ظل توكناته القديمة (`--ink`/`--ink-2`/`--info`/`--gold`...) بدون استبدال كامل — لوحة داخلية كثيفة (٢١٠٠+ سطر) بيعتمد عليها كل مكان تقريباً، واستبدال الأسماء كان بده يكسرها بدون فحص بصري ممكن. اللي انعمل: فافيكون + شعار مصغّر بالـ`.brand` + تقريب قيم `--info`/`--gold` الفعلية لدرجات الأزرق/الكهرماني الجديدة. أي إعادة تصميم كاملة للوحة تحتاج جلسة مخصّصة بفحص بصري فعلي.

---

## السياق التجاري

- **الموسمية:** ذروة آب–تشرين أول، ذروة أصغر شباط. السرعة أهم من الكمال — تفويت افتتاح الفصل الدراسي كلفة استراتيجية حقيقية.
- **بوابة القرار:** غرف موثّقة + تأجيرات مؤكدة قبل تاريخ محدّد — الأرقام بجدول `settings` (`gate_rooms`/`gate_rentals`/`gate_date`). هاي بوابة استمرار/توقف للاستثمار، مش مؤشر أداء.
- **مؤشر PMF الأساسي:** نسبة إعادة الإدراج من المالك خلال ٦٠ يوم (`v_kpi_quality.owner_repeat_pct`). **يُحسب بتجميع `profiles.phone` عمداً، مش `profiles.id`/`listings.owner_id`** (migration `20260914205232`) — لأن `submit_listing()` (منذ `20260914204457`) بتنشئ صف `profiles` جديد بكل استدعاء بلا حساب (سدّ ثغرة انتحال، شوف قسم «الحسابات»)، فمالك متكرر بدون حساب بياخد `owner_id` مختلف كل مرة، والتجميع بـ`owner_id` كان بيصفّر المؤشر دايماً بغض النظر عن التكرار الفعلي. **ممنوع تحويله رجوعاً لـ`owner_id`** — هذا بالضبط سبب الكسر. مطابقة الهاتف غير آمنة للكتابة (نفس سبب منعها بـ`submit_listing`/`link_account_role`)، لكنها آمنة هون: `v_kpi_quality` داخلية للطاقم فقط (`security_invoker=on` + `staff_read` RLS على `listings`/`profiles` تحتها، تحقّق حي: `set local role authenticated` بحساب غير موظّف يرجّع صف واحد بكل القيم `null`)، عملية عدّ إحصائي بحت بدون منح وصول ولا تغيير حالة.
- **الدخل:** رسم نجاح من المالك يُحصّل **نقداً عبر المندوب**. الباحث مجاني دايماً. `SAKANNA50` كود خصم (القيمة والحد والصلاحية بجدول `promo_codes`، عرض فقط بالواجهة العامة — قاعدة ١٧). **الرسم مبلغ ثابت لكل نوع سكن، مش نسبة من الإيجار:** `fee_apartment`/`fee_studio`/`fee_room_shared`/`fee_bed_shared`/`fee_family` بجدول `settings`، و`fee_base` احتياطي فقط لو مفتاح النوع غايب. **`quote_listing_fee(p_kind listing_kind)` هي المصدر الوحيد لأي سعر** — تستدعيها `compute_fee_due()` (تريغر `trg_fee_due` على `owner_fees`) وواجهة `index.html` (عرض فقط عبر RPC، صفر حساب بالجافاسكربت). القيمة النهائية بعد الخصم مخزّنة حرفياً بـ`owner_fees.amount_due`، وتعديلها اليدوي الاستثنائي عبر `admin_fee_amount()` فقط. **رسم النجاح دايماً بالشيكل بغض النظر عن عملة الإعلان** — `listings.currency` (migration `20260921185049`، تُختار وقت التسجيل لـ`price`/`deposit` معاً) ما إله أي علاقة بـ`quote_listing_fee`/`owner_fees`؛ إعلان مسعّر بدينار أو دولار برسم نجاح شيكل زي أي إعلان تاني.
- **التسعير:** الرسم الحالي أرخص من قيمة الخدمة عمداً. المجال الواقعي لاحقاً أعلى، **بعد** إثبات `owner_repeat_pct` مش قبله.
- **رسم شارة الباحث (`seeker_badge_fee`):** موجود بـ`settings` وغير مفعّل. لا تبني له تتبّع بالنظام لحد ما يصير في دليل إنه الباحثين بيدفعوا فعلاً.
- **المؤسسات/NGOs:** تسعير معكوس — المؤسسة تدفع لكل غرفة والمالك ما بيدفع. `institutions.html` بس بتلتقط الطلب؛ التسعير والمتابعة **يدوية بالكامل**.
- **الفجوة التشغيلية الأهم:** بيرزيت — مناطق معرّفة بالقاعدة وطلب باحثين مؤكد، ومخزون شبه معدوم. أولوية العرض قبل أولوية الترويج.
- **قانوني:** التسجيل بوزارة الاقتصاد الوطني حسب قانون التجارة الإلكترونية رقم ٢١ لسنة ٢٠٢٥ شرط لفوترة المؤسسات — الحالة الفعلية بـ`STATUS.md`.
- **التوثيق هو المنتج.** القيمة ثقة مش حجم مخزون. كل قرار تصميم أو نص لازم يقوّي هذا، مش يخفّفه.
- **توثيقان معروضان للعامة: ميداني وفيديو** (`listings.verification` enum: `none`/`desk`/`video`/`field`، مُضافة `video` بـmigration `20260914211509` بين `desk`/`field`). **الميداني (`field`) الأقوى** — زيارة فعلية، `listing_safety` كاملة. **الفيديو (`video`) أضعف وقابل للتحايل عملياً** (تسجيل مسبق، فلترة كاميرا، مكان مؤقت مفروش لمرة واحدة) — قيمته الحقيقية مش بتقنية الفيديو نفسها، بل بالانضباط التشغيلي: **مكالمة حيّة فقط لا تسجيل مُرسَل مسبقاً، جولة كاملة متواصلة بدون قطع، إظهار مدخل المبنى ورقم الشقة/الباب، طلبات غير متوقّعة من المندوب أثناء المكالمة (زاوية أو غرض معيّن يطلبه فوراً)، وتسجيل تاريخ المكالمة واسم من أجراها** (`listings.video_verified_at` + `verification_log`/`admin_actions`). بدون هالانضباط، البادج مجرد شكل بلا مضمون. `desk` (توثيق هاتفي) يبقى الحد الأدنى للنشر أصلاً، بدون تاريخ معروض — خارج نطاق هالتمييز.

---

## خارج النطاق (لا تبنيه)

شات داخلي · بوابة دفع · حساب ضمان (escrow) · تطبيق أصلي · أي ميزة بتأخّر الإطلاق.

> **إيجار يومي/سياحي كان مستثنى، وانعكس القرار بتاريخ ٢٠٢٦-٠٩-٢٣.** التمييز الآن حقل بيانات فقط (`rental_period` على `listings` بقيم `monthly`/`weekly`/`daily`، افتراضي `monthly` لعدم كسر الإعلانات القديمة؛ `seeker_requests.rental_period_pref` مطابق لكن نفس العمود nullable = مرن/أي مدة) — بدون أي منطق تسعير أو فلترة أو صفحة مخصّصة لإيجار يومي/سياحي. لو توسّع لاحقاً (فلاتر بحث، تسعير مختلف حسب المدة، صفحة سياحية) هذا قرار منتج جديد يحتاج نقاش منفصل، مش امتداد تلقائي لهاي الإضافة.

> **الحساب اختياري وإضافي، مش شرط.** التصفّح وإضافة إعلان وتسجيل طلب بحث وطلب التواصل **تبقى شغّالة بالكامل بدون تسجيل دخول** — هذا يبقى المسار الافتراضي والمُعلن. الروابط الموقّعة (`confirm_token`/`owner_token`) تبقى شغّالة كما هي، بالتوازي. حساب `public/account.html` (Supabase Auth بريد/كلمة سر) طبقة إضافية تعطي متابعة وإشعارات فقط — لا يجبر أي مستخدم على التسجيل، وأي تعديل يجبر عليه = خطأ يُرفض.

---

## تشخيص سريع

| العرض | المعنى |
|---|---|
| `401` من Supabase | المفتاح مرفوض أو ناقص هيدر `apikey` |
| `403` من Supabase | **المفتاح سليم** — الدور ناقصه GRANT على الجدول |
| `404` من Supabase | اسم غلط، أو كاش PostgREST قديم → `notify pgrst, 'reload schema';` |
| **جدول بيرجع `[]` بدون خطأ** | **فخ الـzero-policy** — RLS مفعّل بصفر سياسات. التحقق الوحيد المعتبر: `set local role anon; select count(*) from <table>` — مش `has_table_privilege` لحاله |
| الدخول بمركز التحكم بيرجع `400` | الحساب مش Auto Confirmed بـSupabase Auth، أو Email provider مقفول من Dashboard |
| `revoke` نجح بس الصلاحية باقية | المنحة من `PUBLIC` مش من الدور. `revoke … from anon` ما بيسحب من `PUBLIC` — لازم `revoke … from PUBLIC` منفصلة. تحقق بـ`has_function_privilege` |
| إجراء باللوحة ما ظهر بالسجل | صار كـ`PATCH` مباشر مش عبر `admin_*` RPC → بينتسجّل `direct` |
| `create or replace view` بيفشل | ما بتقدر تعيد ترتيب ولا تعيد تسمية أعمدة. **الأعمدة الجديدة بتنضاف بذيل القائمة فقط.** |
| `permission denied for function X` من واجهة `security_invoker` | دالة مستخدَمة جوّا تعريف الـview نفسه بدون منح `authenticated` — شوف الدرس بقسم «من يقرأ ماذا» |
| اسم ملف migration محلي ما طابق `supabase_migrations` بعد `apply_migration` | أداة الـMCP بتسجّل نسختها الزمنية الخاصة، مش اسم الملف. **دايماً** شغّل `list_migrations` بعد التطبيق وسمّي الملف المحلي بنفس الرقم بالضبط |
| حذف من `storage.objects` بـSQL بيرفض حتى بـ`service_role` | `protect_delete` trigger مقصود. احذف عبر Storage API (`DELETE /storage/v1/object/<bucket>/<path>`) |
| `function is not unique` وقت استدعاء دالة إدارية بمعطيات مسمّاة | `create or replace function` بمعطيات إضافية (حتى لو كلها بـ`default`) بتغيّر التوقيع (argument type list) وبتخلق **overload جديد** بدل ما تستبدل القديمة. لازم `drop function if exists <old signature exact types>` صريح قبلها، وبعدين `revoke`/`grant` من جديد على التوقيع الجديد (المنح ما بينورث تلقائياً). صار مع `admin_page_save`/`admin_city_save`/`admin_area_save` وقت إضافة الحقول الإنجليزية. |
| `v_admin_*` صارت مرئية لـ`authenticated` عادي بعد إضافة عمود لها | `create or replace view` **بيصفّر خيار `security_invoker=on`** إذا ما انكتب صراحة بنفس أمر الاستبدال (مش موروث زي الأعمدة). لازم `alter view <name> set (security_invoker = on);` فوراً بعد أي `create or replace view` على واجهة كانت تحمل هالخيار، والتحقّق بـ`select reloptions from pg_class where relname=...` (لازم يطلع `{security_invoker=on}`) **وبعدين** إعادة فحص `set local role authenticated` = صفر صفوف. صار وقت إضافة عمود `has_account` لـ`v_admin_owners`/`v_admin_seekers`. |
| مستخدم يقدر يعدّل عموداً ما كان المفروض يلمسه بجدول له RLS سليمة | `grant update on <table> to authenticated` بلا قيد أعمدة يسمح بتعديل **أي** عمود بالصف اللي يملكه، حتى لو `with check` بالسياسة سليم — لأن `with check` يحرس **الصفوف** (مين يملك الصف) لا **الأعمدة** (أي حقل يتغيّر). لازم `revoke update on <table> from authenticated` ثم `grant update (<الأعمدة المسموحة فقط>) on <table> to authenticated`. صار مع `notifications`/`is_read` بتدقيق ٢٠٢٦-٠٩-٠٥. |
| تسجيل بـ`account.html` يرجع `200` ولا تصل رسالة تأكيد | الخدمة المدمجة ترفض التسليم لغير أعضاء فريق Supabase، **بصمت وبدون خطأ** — راجع `Confirm email`/`Enable custom SMTP` بلوحة `/auth/providers`/`/auth/smtp` قبل افتراض عطل بالكود. مع `Confirm email` مطفأ (الوضع الحالي)، لا رسالة أصلاً — الرد يحتوي `session` مباشرة. |
| بادئة مرجع الإعلان (`SK-`) طلعت غلط أو محتاج تتغيّر | بتتولّد من `set_listing_ref()` عبر `trg_listing_ref` (`BEFORE INSERT` على `listings`) — مش من `column_default` على `listings.ref` ولا من منطق داخل `submit_listing`. أي تغيير للبادئة = استبدال الدالة (`create or replace function set_listing_ref()`) + `alter sequence listing_ref_seq restart with <n>` بنفس الـmigration. |
| رابط `workers.dev` رجع `404` بعد إضافة Custom Domain | إضافة أي `[[routes]]` بـ`wrangler.toml` بتعطّل `workers_dev` تلقائياً على أول نشر يليها إذا ما كانت `workers_dev = true` مكتوبة صراحة بنفس الملف — مش تراكمي، بيصير مع أول `wrangler deploy` بعد إضافة الـroute. الإصلاح: ضيف `workers_dev = true` صراحة وأعد النشر. |

---

## أسلوب العمل

- اشتغل بالعربي. الكود بالإنجليزي، التعليقات والواجهة بالعربي.
- **بأول كل جلسة: اقرأ `STATUS.md`.** بأول محادثة جديدة شغّل وابعت النتيجة: `ls` · `ls public` · `Get-Content wrangler.toml` · `git log --oneline -5` · `npx supabase migration list`
- **قبل أي تعديل schema أو كتابة كود بيلمس القاعدة: استعلم الـschema الحيّ** (`information_schema.columns` للأعمدة، `pg_get_function_arguments` لتوقيعات الدوال، `pg_enum` للقيم). لا تعتمد على الذاكرة — نوع `images`، سلوك البوليان الثلاثي (`true`/`false`/`null`)، وأسماء معطيات الـRPC (`p_`) كلها خالفت التوقع سابقاً.
- **أي ادعاء عن محتوى ملف أو عن diff بيجي مع مخرجات `grep`/`git diff` الفعلية بنفس الرد.** التأكيد المجرّد («فحصت، الصف موجود») مش دليل — وقع فيه الشات وكلاود كود الاتنين.
- **عمود اسم المدينة/المنطقة هو `name_ar` مش `name`.**
- أي تعديل مباشر على القاعدة من برّا اللوحة بينتسجّل بـ`admin_actions` باسم `direct` — هذا مقصود، لا تعطّله.
- لا تعيد كتابة ملف كامل لو التعديل سطرين. الملفات الصغيرة (أقل من ١٠٠ سطر) بتنكتب كاملة بالشات وبتنلصق.
- بعد أي تعديل: commit برسالة وصفية وpush.
- **بآخر كل جلسة: حدّث «آخر جلسة» و«سجل الجلسات» بـ`STATUS.md`.** حدّث `CLAUDE.md` فقط لو تغيّرت البنية أو القواعد.
- **مستندات الإدارة (قرارات، عقود، SOPs) بمجلد `Sakan-HQ` محلي — برّا الريبو.**
