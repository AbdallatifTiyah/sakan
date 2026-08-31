# سكن (Sakan) — دليل المشروع

منصة تأجير غرف وسكن مشترك موثّق في رام الله والبيرة وبيرزيت.
واجهة عربية RTL. باك إند Supabase. نشر على Cloudflare Workers.

**آخر تحديث: ٣١ آب ٢٠٢٦ — conv11 (نظام المستخدمين: Supabase Auth + حارس الأدوار بالدوال الإدارية + شيل Basic Auth + سكن عائلي)**

---

## حالة المشروع الآن

| البند | الحالة |
|---|---|
| قاعدة البيانات | ✅ ١٧ جدول · ١٤ واجهة · ٢٢ migration (Frankfurt) |
| فخ الـzero-policy على `cities`/`areas` | ✅ **انحلّ** — كان `anon` بيقرأ صفر صفوف بصمت |
| الرفض التلقائي بسبب الكاميرا | ✅ **انشال** — كان `default false` + مشغّل = رفض أي زيارة الخانة فيها مش متأشّرة |
| نشر طلبات الباحثين | ✅ **انحلّ** — ما كان في أي RPC تغيّر `seeker_requests.status` |
| منح `EXECUTE` من `PUBLIC` | ✅ مسكّرة — متحقّقة بـ`has_function_privilege` |
| الموقع العام | ✅ منشور على `sakan.abdallatif-tiyah.workers.dev` |
| صفحات المحتوى | ✅ `page.html` + جدول `pages` + محرر باللوحة |
| عدّاد المشاهدات | ✅ `bump_listing_view` — كان عمود ميت |
| حماية `/admin` | ✅ Supabase Auth (شاشة دخول إيميل/كلمة سر) + حارس `is_staff()`/`is_admin()` جوّا كل دالة إدارية. Basic Auth انشال. |
| **مفتاح `service_role` بالمتصفح** | ✅ **انحلّ** — الدخول بالمفتاح العام (`anon`) فقط، الصلاحية الفعلية من جدول `staff` |
| رفع الصور | ❌ `listings.images` فاضي دايماً — أكبر فجوة منتَج |
| وصول التقييمات للمستأجر | ❌ الجدول موجود، ما في طريق يوصله |
| النطاق `sakan.ps` | ❌ بيد أبواللطيف — خارج نطاق مساعدة Claude |
| البيانات | إعلان منشور واحد · إعلان `pending` · ٤ طلبات باحثين `pending` · ٦ ملفات |

---

## البنية

| ملف | الوصف |
|---|---|
| `public/index.html` | الموقع العام — ٨٨٣ سطر، صفحة واحدة، بدون build ولا npm |
| `public/page.html` | سياسة الخصوصية والشروط — بتقرأ من جدول `pages` |
| `public/admin/index.html` | مركز التحكم — ١٧٦٢ سطر، منشور على `/admin`، دخول عبر Supabase Auth |
| `src/worker.js` | بيمرّر لـ`ASSETS` ويضيف `X-Robots-Tag: noindex` على `/admin` (١٦ سطر، بدون Basic Auth) |
| `wrangler.toml` | `main` + `binding = "ASSETS"` + `run_worker_first = true` |
| `supabase/migrations/` | ٢٢ ملف — لازم يطابقوا `supabase_migrations` بالحرف |

**Supabase**
- ref: `yckteijitcqjtedoyoyv` (eu-central-1، Postgres 17.6)
- URL: `https://yckteijitcqjtedoyoyv.supabase.co`
- anon key عام ومسموح يظهر بالكود. `service_role` **ممنوع** يظهر بأي ملف — وما عاد يُلصق يدوياً بمركز التحكم أصلاً.
- نظامين مفاتيح: JWT قديم (`eyJ...`) وجديد (`sb_publishable_...` / `sb_secret_...`). أي كود بيتعامل مع مفتاح لازم يقبل الشكلين.

**الجداول (١٧)**
`admin_actions` · `areas` · `cities` · `contact_requests` · `events` · `listing_safety` ·
`listings` · `owner_fees` · `pages` · `profiles` · `promo_codes` · `reports` ·
`reviews` · `seeker_requests` · `settings` · `staff` · `verification_log`

**الأنواع (enums) الإضافية**
`staff_role` (`admin` · `agent`)

**الـmigrations المسجّلة (٢٢ — بالترتيب)**
```
20260828161300_remote_schema
20260828203602_restore_service_role_grants
20260828222908_revoke_rls_auto_enable
20260829012706_close_public_grants_leftovers
20260829012742_admin_settings_and_audit
20260829012755_wire_business_rules_to_settings
20260829012826_admin_views
20260829012858_admin_action_rpcs
20260829120000_revoke_public_execute_grants
20260829140000_remove_seed_data
20260829150000_seed_reference_data
20260830202558_seeker_requests_admin_and_taxonomy
20260830202631_safety_extras_and_bed_kind
20260830222020_public_forms_v2_features_and_params
20260830224250_fix_cities_areas_zero_policy_trap
20260830224807_admin_listings_view_new_safety_cols
20260831151147_pages_and_view_counter
20260831151305_seed_privacy_and_terms_pages
20260831170825_staff_auth_foundation
20260831170837_admin_views_security_invoker
20260831173555_add_family_listing_kind
20260831180000_admin_rpc_role_guard
```

> migrations conv9 مسجّلة بطوابع `2026082901…` فبتسبق `…120000` بالترتيب.
> الترتيب سليم وظيفياً (كل واحدة بتعتمد بس على `remote_schema`).
> **لا تعيد ترقيمها** — الريبو لازم يطابق `supabase_migrations` بالحرف.

---

## من يقرأ ماذا

**`anon` — الموقع العام**

| نوع | الأسماء |
|---|---|
| قراءة | `v_listings_public` · `v_requests_public` · `cities` · `areas` · `pages` |
| كتابة (insert فقط) | `contact_requests` · `reports` · `events` |
| دوال | `submit_listing` · `submit_request` · `confirm_listing_available` · `bump_listing_view` |

**`authenticated` (بشرط `is_staff()`/`is_admin()`) + `service_role` — مركز التحكم فقط**

الواجهات الداخلية (فيها أرقام هواتف — **ممنوع منح `anon` عليها إطلاقاً**)، صارت
`security_invoker = on` ومنحصرة بـ`authenticated`/`service_role`، والحماية الفعلية
سياسة `staff_read` (تتحقق من `is_staff()`) على الجداول تحتها:
`v_admin_listings` · `v_admin_owners` · `v_admin_seekers` · `v_admin_requests` ·
`v_admin_reports` · `v_admin_pipeline` · `v_admin_fees` · `v_admin_activity` ·
`v_kpi_daily` · `v_kpi_core` · `v_kpi_quality` · `v_reverse_matches`

الدوال الإدارية (١٦) — كل وحدة فيها حارس `if not (is_staff() or auth.uid() is null) then raise exception`
(أربعة منها بـ`is_admin()`: `admin_profile_block` · `admin_set_setting` · `admin_page_save` · `admin_report_status`)،
ومنحصرة بـ`authenticated, service_role` (`anon` ممنوعة):
`admin_listing_status` · `admin_listing_verification` · `admin_listing_extend` ·
`admin_request_status` · `admin_profile_level` · `admin_profile_block` ·
`admin_report_status` · `admin_fee_status` · `admin_fee_promo` ·
`admin_contact_status` · `admin_save_safety` · `admin_city_save` ·
`admin_area_save` · `admin_page_save` · `admin_set_setting` · `admin_log`

> `auth.uid() is null` (استدعاء من `service_role` أو SQL مباشر) بيعدّي الحارس —
> مسموح لطوارئ القاعدة، مش للاستخدام العادي.

**Cloudflare**
- Worker: `sakan` → `sakan.abdallatif-tiyah.workers.dev`
- أسرار `ADMIN_USER`/`ADMIN_PASS` (Basic Auth القديم) ما عاد الـWorker يستخدمها — الحماية صارت بالقاعدة. تركهن بالسر ما بيضرّ، ما فيهن استخدام فعلي.
- النشر يدوي: `npx wrangler deploy`. **ما في CI/CD.**

---

## قواعد حاكمة — ممنوع كسرها

1. **الخصوصية:** أرقام الهواتف، العناوين الدقيقة، وجهة العمل **ما بتظهر أبداً** بأي واجهة عامة.
2. الموقع العام بيقرأ من `v_listings_public` و`v_requests_public` و`cities` و`areas` و`pages` **فقط**.
3. `v_admin_*` و`v_reverse_matches` و`v_kpi_*` أدوات داخلية. ممنوع منح `anon` صلاحية عليها إطلاقاً.
4. أي تعديل schema بيصير **كملف migration بالريبو + ينطبّق على القاعدة**. الاتنين مع بعض. **ممنوع SQL Editor.**
5. **ممنوع كتابة أي مفتاح سري بأي ملف بالريبو.** الدخول لمركز التحكم بإيميل/كلمة سر عبر Supabase Auth؛ `access_token`/`refresh_token` بينحفظوا بـ`sessionStorage` فقط، وما في لصق `service_role` إطلاقاً.
6. `/admin` بيوصله أي حدا (`200` + شاشة دخول) — الحماية الفعلية صارت بالقاعدة: حارس `is_staff()`/`is_admin()` جوّا كل دالة إدارية + `security_invoker` على الواجهات. أي تعديل على `worker.js` بيتبعه فحص: `/admin` = `200` (شاشة الدخول)، الجذر = `200`.
7. **أي سكربت تأمين بيسحب صلاحيات لازم يستثني `service_role` صراحةً.**
8. **`robots.txt` ما بيذكر `/admin` إطلاقاً.** الحماية = شاشة دخول Supabase Auth + `X-Robots-Tag: noindex` (مش `robots.txt`).
9. المنصة **مش** أداة مراقبة. صفحة طمأنة الأهل بتوصف السكن، مش بتتبّع الساكن.
10. بدون dependencies جديدة. vanilla JS.
11. **أي `function` جديدة:** `revoke execute … from public;` ثم `grant execute … to` الأدوار المقصودة صراحةً. التحقق الوحيد المعتبر: `has_function_privilege('anon','<sig>','execute') = false`.
12. **القيم التجارية بتنقرأ من `settings`، مش مكتوبة بالكود.** لا ترجّعها لأرقام ثابتة.
13. **المدن والمناطق بتنقرأ من القاعدة، مش من مصفوفة بالجافاسكربت.** (كانت مثبّتة يدوياً بسبب فخ الـzero-policy — انحلّ.)
14. **بند الكاميرا ملاحظة مندوب، مش ضمانة.** الحماية الحقيقية = بلاغ `category='camera'` بيشغّل `suspend_on_serious_report`.
15. **دور المندوب بمركز التحكم حاجز تشغيلي مش أمني.** أي حدا معه مفتاح الخدمة بيقدر يعمل كل شي.
16. **الأدوار من القاعدة (`staff`) مش من الواجهة.** `p_actor` النصي انشال من كل الدوال الإدارية — الفاعل بييجي حصراً من `auth.uid()` عبر `actor_name()`/`is_staff()`/`is_admin()`. الواجهة ما بتقرر الدور ولا بتوقّع بالسجل.

---

## مركز التحكم — الأقسام (١٥)

| القسم | المدير | المندوب |
|---|---|---|
| لوحة القيادة (KPI + بوابة القرار + قائمة اليوم) | ✅ | ✅ |
| بانتظار المراجعة | ✅ | ✅ |
| **طلبات الباحثين** | ✅ | ✅ |
| البلاغات | ✅ | ❌ |
| مسار التأجير | ✅ | ✅ |
| كل الإعلانات | ✅ | ✅ |
| التوثيق | ✅ | ✅ |
| المطابقة العكسية | ✅ | ✅ |
| الملّاك | ✅ | ✅ (بدون إيقاف حساب) |
| الباحثون | ✅ | ❌ |
| الرسوم | ✅ | ✅ (تحصيل فقط) |
| نشاط المنصة | ✅ | ❌ |
| سجل الإجراءات | ✅ | ❌ |
| الإعدادات (+ المدن والمناطق) | ✅ | ❌ |
| **صفحات المحتوى** | ✅ | ❌ |

كل إجراء بينتسجّل بـ`admin_actions` باسم الفاعل — من `staff` عبر `auth.uid()` إجبارياً، مش نص بيكتبه المستخدم. أي تعديل مباشر على القاعدة من برّا اللوحة بينتسجّل باسم `direct`.

---

## الإعدادات الحيّة (`settings`)

| المفتاح | القيمة | المعنى |
|---|---|---|
| `fee_base` | 200 | رسم النجاح من المالك (شيكل) |
| `listing_expiry_days` | 21 | صلاحية الإعلان بعد النشر |
| `expiring_soon_days` | 3 | تنبيه قرب الانتهاء |
| `review_publish_threshold` | 3 | أقل عدد تقييمات قبل النشر |
| `gate_rooms` | 100 | بوابة القرار — غرف موثّقة |
| `gate_rentals` | 25 | بوابة القرار — تأجيرات مؤكدة |
| `gate_date` | 2026-11-30 | بوابة القرار — التاريخ |
| `seeker_badge_fee` | 30 | رسم شارة الباحث (غير مفعّل) |
| `seekers_free_launch` | true | الباحث مجاني بفترة الإطلاق |

---

## تشخيص سريع

| العرض | المعنى |
|---|---|
| `401` من Supabase | المفتاح مرفوض أو ناقص هيدر `apikey` |
| `403` من Supabase | **المفتاح سليم** — الدور ناقصه GRANT على الجدول |
| `404` من Supabase | اسم غلط، أو كاش PostgREST قديم → `notify pgrst, 'reload schema';` |
| **جدول بيرجع `[]` بدون خطأ** | **فخ الـzero-policy** — RLS مفعّل بصفر سياسات. تحقق: `set local role anon; select …` |
| الدخول بمركز التحكم بيرجع `400` | الحساب مش Auto Confirmed بـSupabase Auth، أو Email provider مقفول من Dashboard |
| `revoke` نجح بس الصلاحية باقية | المنحة من `PUBLIC` مش من الدور. تحقق بـ`has_function_privilege`. |
| إجراء باللوحة ما ظهر بالسجل | صار كـ`PATCH` مباشر مش عبر `admin_*` RPC → بينتسجّل `direct` |
| `create or replace view` بيفشل | ما بتقدر تعيد ترتيب ولا تعيد تسمية أعمدة. **الأعمدة الجديدة بتنضاف بذيل القائمة فقط.** |

---

## السياق التجاري

- **الموسمية:** ذروة آب–تشرين أول (الآن)، ذروة أصغر شباط. السرعة أهم من الكمال.
- **بوابة القرار:** ١٠٠ غرفة موثّقة و٢٥ تأجير مؤكد قبل ٣٠ تشرين ثاني ٢٠٢٦.
- **مؤشر PMF الأساسي:** نسبة إعادة الإدراج من المالك خلال ٦٠ يوم (`v_kpi_quality.owner_repeat_pct`).
- **الدخل:** رسم نجاح ٢٠٠ ₪ من المالك يُحصّل نقداً عبر المندوب. الباحث مجاني. `SAKAN50` (٥٠٪ · ٥٠ استخدام · حتى ٣١/١٢/٢٠٢٦).
- **التسعير:** ٢٠٠ أرخص من قيمة الخدمة. المجال الواقعي لاحقاً ٣٥٠–٤٠٠ بعد إثبات `owner_repeat_pct`. **لا تنزّل الرسم أبداً** — الخصم بكود، مش بتغيير السعر.
- **المؤسسات/NGOs:** تسعير معكوس — المؤسسة تدفع ٣٠٠–٥٠٠ لكل غرفة والمالك ما بيدفع. **يدوي، لا تبني شاشة قبل ٣ طلبات حقيقية.**
- **قانوني:** التسجيل بوزارة الاقتصاد الوطني حسب قانون التجارة الإلكترونية رقم ٢١ لسنة ٢٠٢٥ — **لسا ما خلص**، وبدونه ما في فوترة للمؤسسات.

---

## خارج النطاق (لا تبنيه)

شات داخلي · بوابة دفع · حساب ضمان (escrow) · تطبيق أصلي · إيجار يومي/سياحي · أي ميزة بتأخّر الإطلاق.

> **تعديل ٣١ آب:** «تسجيل دخول للمالك والباحث» كان خارج النطاق. أبواللطيف بده يضيفه.
> البديل الموصى فيه: **رابط موقّع بدون كلمة سر** (زي `confirm_token`) — بيعطي ٩٠٪ من الفايدة
> بدون خسارة نموذج «بدون تسجيل» اللي هو ميزة تنافسية.

---

## مهام مفتوحة — بترتيب الأولوية

**قبل النزول للميدان**
- [ ] **رفع الصور** — Supabase Storage. `listings.images` فاضي دايماً والكروت بتعرض إيموجي.
- [ ] **رابط التقييم** — زر باللوحة يولّد رابط موقّع للمستأجر (واتساب/نسخ)، ويشتغل كمان لمستأجرين ما استأجروا عبر المنصة.
- [ ] **مشاركة الإعلان** — `?l=SK-123` + صورة OG. الواتساب أهم قناة توزيع بفلسطين.
- [ ] **البحث النصي** بالعنوان والوصف.
- [ ] `robots.txt` + `sitemap.xml`.
- [ ] **حفظ مسودة الإعلان محلياً** — النموذج طويل.
- [ ] **حساب المندوب** — لسا بدّه `link_staff(email, name, 'agent')` بعد ما يتعمل حسابه من Dashboard (Auto Confirm).

**بعد أول ٢٠ إعلان**
- [ ] صفحة «كيف بشتغل سكن» — قابلة للتعديل من `pages`
- [ ] تصدير CSV/Excel من اللوحة
- [ ] تنبيهات المندوب (إعلانات قربت تنتهي)
- [ ] رابط المالك الموقّع — يشوف إعلاناته وطلبات التواصل

**بعد بوابة القرار**
- [ ] عربي/إنجليزي · شاشات المؤسسات · إشعارات واتساب Business API
- [ ] ربط النطاق `sakan.ps` — أبواللطيف

---

## أسلوب العمل

- اشتغل بالعربي. الكود بالإنجليزي، التعليقات والواجهة بالعربي.
- قبل أي تعديل schema: اقرأ آخر migration أولاً.
- بعد أي تعديل: commit برسالة وصفية وpush.
- لا تعيد كتابة ملف كامل لو التعديل سطرين.
- الملفات الصغيرة (أقل من ١٠٠ سطر) بتنكتب كاملة بالشات وبتنلصق.
- **بأول أي محادثة جديدة، شغّل وابعت النتيجة:**
  `ls` · `ls public` · `Get-Content wrangler.toml` · `git log --oneline -5` · `npx supabase migration list`
- **بعد أي تغيير بالبنية: حدّث هذا الملف بالريبو.**
- **مستندات الإدارة (قرارات، عقود، SOPs) بمجلد `Sakan-HQ` محلي — برّا الريبو.**
