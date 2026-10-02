# سكنّا v2 — من صفحة ويب لمنتج حقيقي (ويب + Android + iOS + Push)

## السياق

سكنّا صفحة ويب واحدة (vanilla JS، بدون build) فوق Supabase (RLS + `SECURITY DEFINER` RPCs) منشورة عبر Cloudflare Worker على `sakanna.ps`. المطلوب نقلة لمنتج حقيقي: ويب أقوى، تطبيق Android على Play Store، تطبيق iOS على App Store، push حقيقي للجهاز — كل هذا بمطوّر واحد مساءً، بـ٧١ يوم حتى بوابة قرار حقيقية (`gate_rooms=100`/`gate_rentals=25`/`gate_date=2026-11-30`)، وسقف بنية تحتية $50/شهر عند الإطلاق. القاعدة (نفس مشروع Supabase، نفس الـRPCs/RLS) أصل ثابت لا يُمس بأول مرحلتين. هذا المستند نتيجة تدقيق حي كامل (مرحلة ٠) ثم اقتراح معماري — **صفر كود نُفّذ، هذا اقتراح موافَق عليه من حيث المعمارية العامة، بانتظار التنفيذ.**

**حالة الموافقة:** المعمارية (Capacitor) وترتيب المراحل العام موافَق عليهما من صاحب المشروع. هذا المستند مُعدَّل بخمس ملاحظات بعد المراجعة الأولى: (١) توضيح نطاق «الهوية البصرية تنتقل كما هي» + مرحلة تصميم صريحة لـ`index.html`، (٢) فصل Play Store عن App Store بمرحلتين وشرطين، (٣) بوابة مخزون مكتوبة لا ملاحظة، (٤) migration تحصين أمني بمرحلة ١، (٥) مقايضة cron/webhook للـpush معروضة صراحة بقرار نهائي.

---

## مرحلة ٠ — التدقيق الحي (الأدلة)

### أ) الـviews العامة (قراءة `information_schema.columns` حية)

**`v_listings_public`** (٤٦ عمود) — تعريفها الحي (`pg_get_viewdef`):
```sql
SELECT l.id, l.ref, l.title, l.description, c.name_ar AS city, c.slug AS city_slug,
  a.name_ar AS area, a.id AS area_id, l.landmark, l.kind, l.price, l.bills_included,
  l.deposit, l.gender_pol, l.furnished, l.rooms_total, l.occupants_now, l.occupants_note,
  l.available_from, l.min_stay_months, l.images, l.verification, l.published_at,
  l.expires_at, l.view_count, COALESCE(p.verification_level,0) AS owner_level,
  s.visit_date, s.door_lock, s.no_indoor_cameras, s.room_exists, s.photos_match,
  s.occupants_verified, s.exterior_lighting, s.gas_detector,
  (SELECT count(*) FROM reviews r WHERE r.listing_id=l.id AND r.is_published) AS review_count,
  (SELECT round(avg(...),1) FROM reviews r WHERE ...) AS review_avg,
  c.id AS city_id, s.private_bathroom, s.kitchen_access, s.hot_water, s.heating,
  s.internet, s.emergency_exit, s.street_access, l.features, l.video_verified_at
FROM listings l JOIN cities c ON c.id=l.city_id JOIN areas a ON a.id=l.area_id
LEFT JOIN profiles p ON p.id=l.owner_id LEFT JOIN listing_safety s ON s.listing_id=l.id
WHERE l.status='published';
```
**صفر هاتف، صفر عنوان دقيق (`exact_address` غير موجود بالـview)، صفر `owner_id` خام.** هذا view `SECURITY DEFINER` (يظهر بـ`get_advisors` كـERROR بالتصنيف الأمني العام لـSupabase — لكنه نمط مقصود موثّق بـ`CLAUDE.md`، ليس عيباً جديداً).

**`v_requests_public`** (١٦ عمود): `id, ref, budget_max, gender, kind_pref, furnished_pref, move_in_date, min_stay_months, smoker, lifestyle_tags, note, area_ids, city, created_at, occupation, seeker_level, city_id`. صفر هاتف/اسم.

### ب) كل RPC مسموح لـ`anon`/`authenticated` (فحص حي `has_function_privilege`)

**`anon` (13 دالة "عمل" قابلة للتنفيذ):** `active_promo · bump_listing_view · confirm_listing_available · owner_contact_status · owner_dashboard · quote_listing_fee · review_link_info · staff_email_for_username · submit_institution_lead · submit_listing · submit_request · submit_review`.

**تسعة functions داخلية/trigger معرَّضة لـ`anon` بلا سبب عملي** (تأكيد حي `has_function_privilege('anon', …, 'execute')=true` للكل): `audit_admin_change · compute_fee_due · force_pending_on_insert · on_contact_rented · on_listing_publish · publish_reviews_at_threshold · set_listing_ref · set_request_ref · suspend_on_serious_report`. هذه دوال trigger (تُستدعى تلقائياً بالمحفزات، لا تحتاج EXECUTE مباشر من أي دور) بقيت على منحة `PUBLIC` الافتراضية ولم تُسحب — **مخالفة صريحة لقاعدة ١١** (`revoke execute … from public` لكل دالة جديدة). معالجتها بمرحلة ١ (تحت).

**`authenticated` إضافياً (توقيعات كاملة):**
- الذاتية: `my_profile() · my_owner_dashboard() · my_seeker_dashboard() · link_account_role(p_role text, p_name text, p_phone text)`
- الإدارية (٢٢، محكومة بـ`is_staff()`/`is_admin()` داخلياً): `admin_area_save · admin_city_save · admin_contact_status · admin_delete_listing · admin_delete_owner · admin_delete_request · admin_delete_seeker · admin_fee_amount · admin_fee_promo · admin_fee_status · admin_institution_lead_status · admin_link_profile · admin_list_accounts · admin_list_notifications · admin_listing_extend · admin_listing_images · admin_listing_status · admin_listing_verification · admin_log · admin_page_save · admin_profile_block · admin_profile_level · admin_report_status · admin_request_status · admin_save_safety · admin_send_notification · admin_set_setting`

توقيع `submit_listing` الحي (`pg_get_function_arguments`):
```
p_name text, p_phone text, p_title text, p_area integer, p_price numeric, p_kind text,
p_pol text, p_furnished boolean, p_from date, p_occ text DEFAULT NULL, p_landmark text DEFAULT NULL,
p_desc text DEFAULT NULL, p_features text[] DEFAULT '{}', p_deposit numeric DEFAULT NULL,
p_bills boolean DEFAULT false, p_rooms smallint DEFAULT NULL, p_min_stay smallint DEFAULT NULL,
p_images jsonb DEFAULT '[]'
```
`sakan_match_score` (SQL/plpgsql `IMMUTABLE`، غير `SECURITY DEFINER`) — خوارزمية تسجيل حية بالكامل:
```
المنطقة·30 + الميزانية·30 (كامل تحت الميزانية، نصف حتى +15%) + نظام السكن·25 (تعارض جندري = صفر كامل)
+ النوع·10 + تاريخ الدخول·5  → سقف 100
```

### ج) الـenums وسياسات RLS

**١٤ enum** (بالضبط كما بـ`CLAUDE.md` + تأكيد حي): `listing_kind{room_shared,bed_shared,studio,apartment,family}` · `listing_status{draft,pending,published,rejected,reserved,rented,expired}` · `listing_verification{none,desk,video,field}` · `contact_status{new,forwarded,owner_responded,viewing_set,rented,dead}` · `fee_status{due,collected,waived,lost}` · `gender_policy{female,male,mixed}` · `gender_type{female,male}` · `institution_lead_status` (٥) · `institution_org_type` (٥) · `occupation_type` (٣) · `report_category` (٧) · `report_status` (٤) · `request_status` (٣) · `review_stage{day30,move_out}` · `staff_role{admin,agent}` · `user_role{seeker,owner,agent,admin}`.

**سياسات RLS الحية (٢٦ سياسة)** — كل جدول داخلي محكوم بـ`staff_read` لـ`authenticated` فقط، عدا: `areas`/`cities`/`pages` (قراءة عامة `anon+authenticated`)، `contact_requests`/`reports`/`events` (إدراج فقط `anon`)، `notifications`/`saved_listings` (`self_read`/`self_update`/`self_all` بـ`account_uid=auth.uid()`). **`staff` نفسه RLS مفعّل بصفر سياسات** (`rls_enabled_no_policy` بـ`get_advisors`) — مقصود، لا يُقرأ من العميل مباشرة أصلاً.

**فحوصات أمنية سلبية من `get_advisors` لا تستدعي إصلاحاً:** ٤٧ `SECURITY DEFINER` function قابلة للتنفيذ من `authenticated`/`anon` — هذا **هو النمط المعماري المتعمّد** (منطق العمل بالكامل بالقاعدة، رول ١٦)، وليس ثغرة.

**فحص يستدعي إصلاحاً فعلياً (أُدرج بمرحلة ١):** `auth_leaked_password_protection` معطّل (تفعيله من `/auth/providers` مجاني وفوري).

### د) حجم وتكرار الكود بـ`public/`

| ملف | أسطر | تكرار موثّق |
|---|---|---|
| `index.html` | 1454 | `tt()`, CSS tokens, fetch boilerplate |
| `admin/index.html` | 2325 | توكنز قديمة مختلفة عمداً (قرار موثّق) |
| `account.html` | 458 | `tt()`, CSS tokens, fetch boilerplate |
| `owner.html` | 384 | CSS tokens فقط (بدون `tt()` — عربي بس عمداً) |
| `institutions.html` | 256 | `tt()`, CSS tokens, fetch boilerplate |
| `page.html` | 215 | `tt()`, CSS tokens, fetch boilerplate |

**تأكيد حي (`grep`):** `const tt = (ar, en) => ...` مكرر حرفياً بـ٤ ملفات. `--blue-700:#12309B` وبقية التوكنز مكررة بـ`:root{}` منفصل بـ٥ ملفات (نفس القيم الحرفية). `SUPABASE_URL`/`SUPABASE_ANON_KEY` مكررة حرفياً بـ٧ أماكن. **صفر ملف `.css`/`.js` مشترك، صفر `package.json`، صفر `node_modules`، صفر `.github/`، صفر build tool.** `src/whatsapp.js` مُجهّز غير مستدعى من أي مكان.

### هـ) جدول «مبني / معروض / فجوة»

| القدرة | مبنية بالقاعدة؟ | معروضة حالياً؟ | الفجوة |
|---|---|---|---|
| مطابقة باحث↔إعلان (`sakan_match_score`, `v_reverse_matches`) | ✅ خوارزمية موزونة كاملة | جزئياً — تريغر أول نشر فقط + view داخلي للطاقم | لا "مطابقات لك" مستمرة للباحث |
| حفظ إعلان (`saved_listings` + `self_all` RLS) | ✅ جدول + سياسة كاملة | ❌ صفر استخدام بأي ملف `public/` | زر "حفظ" غير مبني إطلاقاً |
| إشعارات (`notifications` + ٤ محفزات) | ✅ بنية كاملة، تشتغل فعلاً | فقط جرس داخل `account.html`، صفر تسليم للجهاز | **محور الطلب بالضبط** |
| تقييمات (`reviews`) | ✅ | ✅ (`review_count`/`review_avg`) | لا فجوة |
| بحث نصي فعلي | ❌ (`pgroonga`/`pg_trgm` متاحان غير مثبَّتين) | substring بالمتصفح (`index.html:634`) | كافٍ لإعلان واحد اليوم |
| PWA / Service Worker / Push API | ❌ | ❌ | فجوة كاملة |
| تطبيق أصلي (أي منصة) | ❌ | ❌ | فجوة كاملة |

**بيانات حية:** **إعلان منشور واحد فقط بالقاعدة** (`studio/pending/none` فعلياً — ولا حتى منشور). ٤ بروفايلات، ٣ طلبات باحثين. مرحلة ما قبل الإطلاق فعلياً — هذا الرقم بالذات هو أساس بوابة التقديم للمتاجر بالأسفل، ليس تفصيلاً عابراً.

---

## الاقتراح المعماري

### البدائل الثلاثة

**١. Capacitor wrap فوق نفس الكود الحالي (المُوصى به — موافَق عليه)**
غلاف native (Android/iOS) حول نفس ملفات `public/*.html`، بعد مرحلة تصميم/UX صريحة عليها (تحت). منطق العمل والاتصال بـSupabase بلا أي تغيير. Push عبر Firebase Cloud Messaging + توصيل من القاعدة (تفاصيل الآلية بالمرحلة المخصّصة).
- **الكلفة الشهرية:** راجع الجدول أدناه (مُعاد حسابه بعد فصل بوابة App Store).
- **يكسب:** صفر إعادة كتابة UI، صفر تكرار منطق عمل، يحافظ ١٠٠٪ على SEO/OG (`worker.js` بلا أي لمسة)، أسرع مسار ممكن لمطوّر واحد مساءً.
- **يخسر:** أداء WebView أقل من native حقيقي، ومخاطرة رفض متجر آبل لتطبيق "يشبه غلاف ويب" إن لم تُضف قيمة native حقيقية — عولجت ببوابة مرحلة ٦ الصريحة تحت.
- **أين تنكسر تحت الحمل:** أول نقطة انهيار Supabase pooler عند طفرة طلبات متزامنة من حملة إعلانية (معالجتها بالـpooler الجاهز أصلاً + throttling من `settings` عند الحاجة). ثانياً: تسليم push على أجهزة Android بموفّرات بطارية عدوانية (Xiaomi/Huawei) قد يُسقط إشعارات صامتة — مخفّف باستخدام Capacitor native push plugin (عملية مستقلة حقيقية) لا web push فقط.
- **كلفة الخروج لاحقاً:** منخفضة — كود الويب سليم ومُعاد استخدامه بالكامل، المرمي فقط إعداد الغلاف/الـplugins.

**٢. React Native (Expo) — تطبيق منفصل كامل**
واجهة native حقيقية مبنية من الصفر، تتحدث لنفس RPCs. Push عبر Expo Push Service. بناء عبر EAS Build (سحابي، يشتغل من Windows بلا Mac).
- **الكلفة:** إطلاق ≈ $33–130/شهر حسب طابور EAS.
- **يكسب:** أداء وتجربة native حقيقية من اليوم الأول، أقل مخاطرة رفض متجر آبل.
- **يخسر:** واجهة كاملة ثانية (كل الشاشات، كل النماذج، رفع الصور، الـlightbox) يجب بناؤها وصيانتها بالتوازي مع الويب — أي تعديل RPC/schema مستقبلي (يحصل كل جلسة تقريباً حسب `STATUS.md`) يتطلب تنفيذه مرتين. يستهلك الـ٧١ يوم بإعادة بناء واجهة بدل جمع مخزون.
- **أين تنكسر:** ليست نقطة حمل تقنية بل سعة المطوّر الوحيد — انحراف parity بين الويب والتطبيق هو نقطة الفشل الحقيقية.
- **كلفة الخروج لاحقاً:** الأعلى بين الخيارات الثلاثة — لكن الأنسب فعلياً لو صار فريق فعلي لاحقاً.
- **مرفوض للتوقيت الحالي.**

**٣. PWA فقط (Web Push + installable) بدون متجرين**
إضافة `manifest.json` + service worker — قابل للتثبيت وWeb Push حقيقي بدون أي غلاف native.
- **الكلفة:** إطلاق ≈ $30/شهر.
- **يكسب:** الأرخص والأسرع تنفيذاً بفارق كبير، صفر مخاطرة رفض متجر.
- **يخسر:** **لا يحقق متطلبين صريحين من الطلب** — لا وجود على Play Store ولا App Store.
- **مرفوض** لأن رفض هذين الشرطين ليس قراري لأتخذه بالنيابة عن صاحب المشروع.

### توضيح نطاق «الهوية البصرية تنتقل كما هي»

هذا القيد يعني حرفياً: **التوكنز اللونية (`--blue-700`/`--blue-600`/`--amber`/`--navy`/إلخ) + الشعار SVG + الخطوط (`IBM Plex Sans Arabic`/`Archivo`) + قاعدة الزر الأساسي الكهرماني الواحد بالشاشة**. لا يعني تجميد التخطيط. **التخطيط البصري، التسلسل الهرمي للمعلومات، بنية المكوّنات (كرت الإعلان، صفحة التفاصيل، نموذج الإضافة، الفلترة)، وكثافة المعلومات كلها مفتوحة للتحسين** — وهذا بالضبط موضوع المرحلة ٢ الجديدة تحت.

### الكلفة الشهرية المُعاد حسابها (بدون Apple عند الإطلاق — راجع فصل المتجرين بالأسفل)

| المستوى | البنود | المجموع |
|---|---|---|
| **إطلاق** (بدون Apple — لسا ما تحقق شرط مرحلة ٦) | Supabase Pro $25 + Cloudflare Workers Paid $5 + FCM $0 + Google Play $25 مرة واحدة (~$0/شهر) + بناء Android عبر CI مجاني $0 | **≈ $30/شهر** |
| **نمو** (بعد تحقق بوابة App Store) | نفس البنود + Apple Developer $99/سنة (~$8.25/شهر) + CI أسرع عند الحاجة $28–95 | **≈ $63–133/شهر** |
| **توسّع** | Supabase compute add-ons $25–100+ + Workers أعلى استهلاك $20–50 + CI $95+ + Apple $8.25 | **≈ $150–300+/شهر** |

سقف الـ$50/شهر **محقَّق فعلياً عند الإطلاق** لأن رسوم Apple مؤجَّلة ببند صريح (مرحلة ٦).

---

## خطة المراحل

**المرحلة ١ — كود مشترك + تحصين أمني — ~أسبوع-١٠ أيام مسائية**
أ) استخراج `tt()`/توكنز CSS/غلاف fetch لملف `public/shared.js`+`shared.css` تستدعيه ٥ الملفات (عدا `admin/index.html` عمداً). صفر تغيير بصري بهذه الخطوة تحديداً.
ب) **Migration تحصين واحدة صغيرة:**
```sql
revoke execute on function
  audit_admin_change(), compute_fee_due(), force_pending_on_insert(),
  on_contact_rented(), on_listing_publish(), publish_reviews_at_threshold(),
  set_listing_ref(), set_request_ref(), suspend_on_serious_report()
from public;
```
(التوقيعات الدقيقة تُستخرج حية بـ`pg_get_function_identity_arguments` وقت التنفيذ — لا افتراض من الذاكرة.) هذه دوال trigger تستمر بالعمل تلقائياً (المحفزات تستدعيها بصلاحية مالكها لا صلاحية الطلب المباشر) — سحب `EXECUTE` من `PUBLIC` لا يكسر شيئاً.
ج) تفعيل `auth_leaked_password_protection` من لوحة `/auth/providers` (تعديل إعداد، ليس كوداً).
- **تحقق:** `grep -c "const tt = " public/*.html` صفر بكل ملف عدا `shared.js`؛ فحص بصري (screenshot) قبل/بعد يطابق تماماً؛ `select has_function_privilege('anon', p.oid, 'execute') from pg_proc p where proname in (...)` يرجع `false` للتسعة كلها؛ إعادة تشغيل `get_advisors(security)` يُظهر اختفاء الفحصين.

**المرحلة ٢ — تصميم/UX لِ `index.html` (مخرَج بصري ملموس) — ~٢ أسابيع مسائية**
إعادة تصميم كرت الإعلان، صفحة التفاصيل، نموذج «أضف غرفة»، وواجهة الفلترة — تحسين التسلسل البصري وبنية المكوّنات وكثافة المعلومات، **بنفس التوكنز/الشعار/الخطوط/قاعدة الزر الواحد حرفياً**. هذه مرحلة تصميم فعلية (mockup → تنفيذ)، لا إعادة هيكلة كود فقط — لا تُدمج بالمرحلة ١.
- **تحقق (بوابة بصرية):** عرض حي على خادم محلي لكل من الحالات الأربع (كرت/تفاصيل/نموذج/فلترة) بعربي وإنجليزي (RTL/LTR)، ومراجعة بصرية صريحة قبل الانتقال للمرحلة ٣ — لا نص كافٍ وحده هون.

**المرحلة ٣ — Capacitor wrap + هيكل التطبيق (بدون تقديم لأي متجر بعد) — ~٢-٣ أسابيع مسائية**
`npx cap init` + إضافة منصتي android/ios، تضمين نسخة محلية من `public/` (بعد تصميم مرحلة ٢) بالتطبيق، كل نداءات البيانات لنفس Supabase عبر الشبكة كالويب تماماً. أيقونة/splash من نفس الهوية. تحديد الميزة الـnative الثانية (غير الـpush) هون — مثلاً مشاركة نظام (`Share` plugin) أو اهتزاز تفاعلي — لازمة لبوابة مرحلة ٦.
- **تحقق:** `npx cap run android` على محاكي ينجز دورة كاملة (تصفح → إضافة غرفة → طلب تواصل) على القاعدة الحية (بيانات اختبار تُحذف بعدها)؛ `npx cap run ios` على Simulator (يحتاج وصول Mac/CI — لا يحتاج عضوية Apple Developer المدفوعة بهذه المرحلة).

**المرحلة ٤ — Play Store فقط (اختبار داخلي → إنتاج) — ~أسبوع + وقت مراجعة**
**بوابة مكتوبة قبل البدء (لا ملاحظة):** لا تقديم قبل التحقّق الحي `select count(*) from listings where status='published'` يرجع رقماً يعكس نشاطاً سوقياً حقيقياً — لا الإعلان الاختباري الوحيد المرصود بمرحلة ٠. العتبة الدقيقة (كم إعلاناً بالضبط) قرار صاحب المشروع وقت الوصول لهذه المرحلة، لكن الفحص نفسه إلزامي وموثَّق كخطوة أولى بالمرحلة، لا افتراض.
- **تحقق:** الاستعلام أعلاه ينفَّذ ونتيجته تُسجَّل قبل الضغط على "تقديم للمراجعة"؛ رابط Play Store يرجع حالة "منشور" لا "قيد المراجعة".

**المرحلة ٥ — أنبوب Push الحقيقي — ~أسبوع-أسبوعين مسائية**
Migration جديدة (بعد الـparity فقط): جدول `push_tokens(account_uid, platform, token, created_at)` + سياسة `self_all` (نفس نمط `saved_listings`) + RPC `register_push_token(p_platform text, p_token text)` (`SECURITY DEFINER`، الفاعل `auth.uid()` حصراً، بلا `p_actor` — مطابق لقاعدة ١٦) + عمود `notifications.pushed_at` (nullable).

**مقايضة التوصيل — cron مقابل Database Webhook (معروضة صراحة، القرار أدناه):**

| | Cloudflare Worker Cron (كل ٢ دقيقة) | Supabase Database Webhook |
|---|---|---|
| أقصى تأخير | حتى ~دقيقتين + ثوانٍ إرسال FCM | شبه فوري (ثوانٍ) — غير متزامن (async)، لا يوقف transaction الإدراج نفسه |
| أين يعيش المنطق | بالكامل بالـWorker الموجود أصلاً (سحب/pull) | القاعدة تستدعي (دفع/push) نقطة جديدة بنفس الـWorker (`/internal/push-relay`) عبر `pg_net` تحت غطاء ميزة Supabase الجاهزة |
| الكلفة المعمارية | صفر اعتماد جديد، يبقي القاعدة "قراءة فقط" تجاه العالم الخارجي | القاعدة تصبح مصدر نداء HTTP خارجي (ولو عبر ميزة مُدارة لا كود يدوي) — يحتاج سرّاً مشتركاً (`shared secret`) بهيدر الطلب يتحقق منه الـWorker، وإعادة محاولة تلقائية تديرها Supabase عند فشل الطلب |
| التوافق مع قرار سابق | متوافق ١٠٠٪ مع "القاعدة = RPC+RLS فقط" | يخالف حرفياً لكن ليس روحاً — الميزة مُدارة من المنصة نفسها، لا سيرفر إضافي يديره المطوّر |

**القرار النهائي: Database Webhook.** السبب: كامل قيمة "push حقيقي" بالطلب الأصلي هي الفورية — إشعار "طلب تواصل جديد" يصل بعد دقيقتين لا يشعر المستخدم بأنه "حقيقي" فعلاً. الميزة async (لا تحجب transaction الإدراج، وSupabase تدير إعادة المحاولة تلقائياً) تجعل الكلفة المعمارية أقل مما تبدو — لا "خدمة جديدة" بل ميزة مُدارة تستدعي نقطة واحدة جديدة بنفس الـWorker المنشور أصلاً.
- **تحقق:** `select * from push_tokens` يورّي صف حقيقي بعد تسجيل جهاز اختبار؛ إدراج صف بـ`contact_requests` يطلق push فعلي على الجهاز خلال ثوانٍ (لا دقائق)؛ `pushed_at` يتختم؛ فشل متعمّد لنقطة `/internal/push-relay` (إيقافها مؤقتاً) يُظهر إعادة محاولة تلقائية من لوحة Supabase Webhooks بدون فقدان الحدث.

**المرحلة ٦ — App Store — مشروطة بشرطين معاً**
**بوابة مكتوبة:** (أ) `select count(*) from listings where status='published'` ≥ **٣٠** إعلاناً حقيقياً، (ب) ميزتان native حقيقيتان شغّالتان فعلياً على جهاز test (push من مرحلة ٥ + الميزة الثانية من مرحلة ٣). **لا تُدفع رسوم Apple Developer ($99/سنة) قبل تحقق الشرطين معاً** — السبب: تغليف صفحة بإعلان واحد (أو حتى ببضع عشرات دون ميزة native حقيقية) رفض شبه مؤكد تحت Guideline 4.2، والرفض المتكرر يُعلّم الحساب نفسه لا يؤخّره فقط.
- **تحقق:** كلا الشرطين مُسجَّلين (رقم الإعلانات + لقطة/تسجيل لكل ميزة native شغّالة) قبل أي دفعة لأبل؛ بعدها TestFlight → مراجعة → رابط App Store يرجع "منشور فعلياً".

ملفات `.well-known/assetlinks.json`/`apple-app-site-association` (لفتح روابط `sakanna.ps/?l=REF` المُشاركة بالواتساب مباشرة بالتطبيق) تُضاف مع مرحلة ٣/٤ (خفيفتان، لا تعتمدان على عضوية Apple المدفوعة).

**المرحلة ٧ (بعد بوابة القرار، اختياري) — سد الفجوات المكتشفة بمرحلة ٠**
تفعيل `saved_listings` (زر حفظ)، وتحويل `sakan_match_score`/`v_reverse_matches` لقناة "مطابقات جديدة" مستمرة للباحث عبر نفس أنبوب push من المرحلة ٥ — صفر تغيير schema إضافي.

**خطة التراجع:** الويب لا "cutover" له فعلياً — نفس `sakanna.ps`/`worker.js`؛ أي تراجع هو `wrangler deploy` لنسخة سابقة كالمعتاد. إصدار تطبيق معطوب لا يصل لمستخدم حقيقي أصلاً طالما لم تُرقَّ من "اختبار داخلي" لـ"إنتاج" بالمتجر. فشل الـwebhook (مرحلة ٥) لا يفقد الحدث — Supabase تُعيد المحاولة تلقائياً، والسجل بـ`notifications`/`pushed_at` يبقى مصدر الحقيقة القابل للتدقيق يدوياً.

---

## أعلى ٥ مخاطر

1. **رفض App Store كـ"غلاف ويب بلا قيمة native"** (Guideline 4.2). *تخفيف:* أصبح مُدمَجاً ببوابة مرحلة ٦ نفسها (لا تقديم أصلاً قبل ٣٠ إعلاناً + ميزتين native شغّالتين فعلياً) — لا مجرد نصيحة، شرط بنيوي يمنع التقديم المبكر.
2. **Database Webhook (الجزء الجديد الوحيد فعلياً بالقاعدة) بلا مراقبة كافية** — فشل صامت محتمل (سرّ منتهي، نقطة `/internal/push-relay` معطوبة). *تخفيف:* تسجيل كل محاولة إرسال بنفس نمط `admin_actions`/`events` الموجود، مراجعة يدوية بالأسابيع الأولى، الاعتماد على إعادة المحاولة التلقائية من Supabase كطبقة أمان أولى.
3. **تسجيل بدون تأكيد بريد** (بند مفتوح موثّق بـ`STATUS.md`) يعني هوية `account_uid` غير موثوقة عند ربط توكن جهاز — خطر موروث لا ينتجه هذا الاقتراح، يستحق الإشارة قبل تفعيل push على نطاق واسع.
4. **بناء iOS يحتاج Mac** — عنق زجاجة تشغيلي حقيقي، لكن مؤجَّل الأثر الفعلي حتى مرحلة ٦ (بعد تحقق البوابة)، لا ضغط فوري بالأسابيع الأولى. *تخفيف:* Codemagic free tier لمرحلة ٣ (Simulator فقط، بلا عضوية مدفوعة)، تأجير Mac سحابي مؤقت فقط عند التقديم الفعلي بمرحلة ٦.
5. **إغراء توسيع النطاق** (تفعيل `saved_listings`/المطابقة المستمرة أثناء بناء التطبيق) يلتهم الـ٧١ يوم. *تخفيف:* مرحلة ٧ صراحة بعد البوابة، لا أثناء المراحل ١-٦.

## قرارات اتخذتها بنفسي

1. **Capacitor لا React Native** — السرعة وإعادة استخدام كل الكود الحالي أهم من جودة native المثالية بهذا الأفق الزمني.
2. **Database Webhook لا Cron polling للـpush** (مُعدَّل عن المسودة الأولى بعد عرض المقايضة صراحةً) — الفورية جوهر قيمة "push حقيقي"، والطابع async غير الحاجب لـtransaction الإدراج يجعل الكلفة المعمارية مقبولة رغم أنها تخالف حرفياً (لا روحاً) مبدأ "القاعدة بلا نداء خارجي".
3. **FCM ناقل push وحيد** (حتى لأجهزة آبل عبره) — بائع واحد، مجاني، مدعوم من Capacitor وWeb Push معاً.
4. **إضافة schema معزولة بمرحلة ٥ فقط** (`push_tokens` + `notifications.pushed_at`) — "صفر تغيير schema" حرفياً مستحيل مع push حقيقي؛ التزمت بروح القيد (لا تعديل على منطق/جداول قائمة) بدل حرفيته الكاملة.
5. **Supabase Pro من اليوم الأول لا Free tier** — تفادي الإيقاف التلقائي بعد ٧ أيام خمول أثناء حملة إعلانية فعلية.
6. **تضمين نسخة محلية من الأصول الثابتة بالتطبيق** — إقلاع فوري، بينما كل البيانات الحيّة تمر بنفس مسار anon+RPC كالويب تماماً.
7. **مرحلة تصميم منفصلة (٢) قبل التغليف** — الطلب الأصلي لم يفصل "تحسين وظيفي" عن "تحسين بصري"؛ التصميم البصري الفعلي (لا إعادة هيكلة كود) يستحق مرحلة قائمة بذاتها بمخرَج ملموس وبوابة مراجعة بصرية، بدل أن يذوب داخل مرحلة تقنية.
8. **بوابتا متجر منفصلتان بشرطين مختلفي الصرامة** (Play Store: بوابة نوعية "مخزون حقيقي"؛ App Store: بوابة كمية "٣٠ إعلاناً + ميزتان native") — الطلب حدَّد رقماً لآبل فقط؛ لم أخترع رقماً مماثلاً لجوجل حيث لم يُطلب، وتركت العتبة الدقيقة هناك لصاحب المشروع مع إبقاء الفحص نفسه إلزامياً.

## ما لا أنصح به

- **React Native/Expo الآن** — يستهلك الـ٧١ يوم بإعادة بناء واجهة كاملة بدل جمع مخزون؛ خيار صحيح لاحقاً لو صار فريق.
- **PWA فقط بدون متجرين** — يفشل شرطين صريحين بالطلب؛ رفضهما ليس قراراً لي.
- **دمج مرحلتي التصميم والتغليف بخطوة واحدة** — يخاطر بإعادة تصميم متسرّعة تحت ضغط "لازم نطلع تطبيق"، بينما التصميم يستحق حكماً بصرياً مستقلاً قبل تجميده داخل بناء native.
- **سيرفر Node/API منفصل "لتسهيل push"** — ينتهك مباشرة قاعدة منع أي server component بينوصله العميل، ويضيف خدمة كاملة يديرها مطوّر واحد لوحده مقابل لا شيء لا يقدر عليه Database Webhook + نقطة واحدة على الـWorker الموجود أصلاً.
- **بحث نص كامل (pgroonga/Algolia/Meilisearch)** — إعلان واحد بالقاعدة حالياً؛ استثمار سابق لأوانه.
- **دفع رسوم Apple قبل تحقق بوابة مرحلة ٦** — رفض متكرر مسبق يُعلّم حساب المطوّر نفسه لدى آبل، ضرر أبعد أثراً من تأخير أسبوعين.
