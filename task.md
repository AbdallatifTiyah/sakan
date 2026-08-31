# task.md — الدفعة ١: نظام المستخدمين

> اقرأ `CLAUDE.md` بجذر الريبو قبل ما تبدأ. القواعد الحاكمة فيه ملزِمة.
> **الهدف الوحيد لهاي الدفعة:** شيل مفتاح `service_role` من متصفح المندوب.
> **لا تشتغل على أي بند تاني** (الصور، التقييم، البحث، المشاركة…). دفعات جاية.

---

## الوضع الحالي — انقرا منيح

**انعمل مسبقاً وانطبّق على القاعدة** (migrations `20260831170825` و`20260831170837` موجودات بالريبو):

- نوع `staff_role` (`admin` · `agent`)
- جدول `staff` (`id` → `auth.users` · `email` · `name` · `role` · `is_active`)
- دوال: `is_staff()` · `is_admin()` · `actor_name()` · `link_staff(email,name,role)`
- سياسة `staff_read` على ١٦ جدول أساسي + `grant select … to authenticated`
- الـ١٢ واجهة إدارية صارت `security_invoker = on`، انسحبت من `anon`، وانمنحت لـ`authenticated`

**متحقّق منه فعلياً:**

| الفحص | النتيجة |
|---|---|
| مستخدم مسجّل مش من الطاقم يقرأ `v_admin_listings` | صفر صفوف |
| `anon` على `v_admin_*` و`v_kpi_*` و`staff` | `false` |
| `service_role` على الواجهات الإدارية | شغّال (٢ إعلان · ٤ طلبات) |
| الموقع العام لـ`anon` | شغّال (١ إعلان · ٢ مدينة · ١٣ منطقة · ٢ صفحة) |

**حساب المدير مربوط أصلاً** — صف واحد بجدول `staff`، دور `admin`،
والفحص تم بتقمّص هويته: `is_admin() = true`، وبيشوف الواجهات الإدارية.
حساب المندوب بينضاف لاحقاً بـ`link_staff(email, name, 'agent')`.

**الناقص — وهو شغلك:**

1. حارس دور جوّا الـ١٦ دالة إدارية + منحها لـ`authenticated`
2. شاشة دخول بمركز التحكم بدل لصق `service_role`
3. شيل Basic Auth من الـWorker

---

## مهمة ١ — حارس الدور بالدوال الإدارية

**ملف migration جديد** بـ`supabase/migrations/`.

الأجسام الأصلية للدوال موجودة بـ`supabase/migrations/20260829012858_admin_action_rpcs.sql`
وبالـmigrations الأحدث. **اقرأهن أولاً** ولا تخترع أجسام جديدة.

### الدوال الستّعش

`admin_listing_status` · `admin_listing_verification` · `admin_listing_extend` ·
`admin_request_status` · `admin_profile_level` · `admin_profile_block` ·
`admin_report_status` · `admin_fee_status` · `admin_fee_promo` ·
`admin_contact_status` · `admin_save_safety` · `admin_city_save` ·
`admin_area_save` · `admin_page_save` · `admin_set_setting` · `admin_log`

### المطلوب لكل وحدة

**أ) ضيف الحارس كأول سطر بالجسم:**

```sql
if not (is_staff() or auth.uid() is null) then
  raise exception 'غير مصرّح' using errcode = '42501';
end if;
```

> `auth.uid() is null` معناها الاستدعاء جاي من `service_role` أو من SQL مباشر —
> بنسمح فيه عشان ما ينكسر مركز التحكم الحالي خلال الانتقال، وعشان تضل
> تقدر تصلح من الـSQL وقت الطوارئ.

**ب) الدوال الأربعة التالية للمدير فقط** — استخدم `is_admin()` بدل `is_staff()`:

`admin_profile_block` · `admin_set_setting` · `admin_page_save` · `admin_report_status`

**ج) بدّل `p_actor`:** خلّي البارامتر موجود للتوافق، بس **لا تستخدم قيمته**.
كل مكان فيه `coalesce(p_actor,'admin')` بدّله بـ:

```sql
coalesce(nullif(actor_name(),'service'), p_actor, 'admin')
```

> هيك المستخدم المسجّل بينوقّع باسمه من `staff` إجبارياً، ولما الاستدعاء
> من `service_role` بيرجع للسلوك القديم. **هاي بتسكّر ثغرة إنه المندوب
> بيقدر يكتب اسم المدير بالسجل.**

**د) المنح — لكل دالة، بالترتيب:**

```sql
revoke execute on function <name>(<sig>) from public;
revoke execute on function <name>(<sig>) from anon;
grant  execute on function <name>(<sig>) to authenticated, service_role;
```

⚠️ **`<sig>` لازم يكون التوقيع الكامل بالأنواع.** خد التواقيع من:

```sql
select p.proname, pg_get_function_identity_arguments(p.oid)
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname like 'admin\_%';
```

**هـ) بآخر الملف:** `notify pgrst, 'reload schema';`

### فحص القبول

```sql
-- انتظر: anon = false لكل الستّعش
select p.proname,
       has_function_privilege('anon', p.oid, 'execute')          as anon,
       has_function_privilege('authenticated', p.oid, 'execute') as auth,
       has_function_privilege('service_role', p.oid, 'execute')  as svc
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname like 'admin\_%'
order by 1;
```

```sql
-- انتظر: exception 'غير مصرّح'
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
select admin_set_setting('fee_base', '999'::jsonb, 'هاكر');
```

---

## مهمة ٢ — شاشة دخول بمركز التحكم

**الملف:** `public/admin/index.html` (١٧٠٩ سطر · صفحة وحدة · vanilla JS · بدون dependencies)

### الوضع الحالي

- `#gate` فيه ثلاث حقول: مفتاح (`#gk`) · اسم (`#gn`) · دور (`#gr`)
- `enter()` بتتحقق إنه المفتاح `sb_secret_…` أو `eyJ…`، بتجرّب `get("/settings…")`،
  وبتحفظ بـ`sessionStorage`
- `S = { key, actor, role, view, page, cache, filters }`
- `hdr()` بتبني `apikey` و`Authorization: Bearer ` + `S.key`
- كل استدعاء بيمرّر `p_actor: S.actor`

### المطلوب

**أ) بدّل الشاشة** لإيميل + كلمة سر. شيل حقل المفتاح وحقل الاسم وقائمة الدور — كلهن بيجوا من القاعدة هلأ.

**ب) الدخول** عبر Supabase Auth بالمفتاح العام (`anon`، وهو مسموح يظهر بالكود):

```js
const r = await fetch(SUPABASE_URL + "/auth/v1/token?grant_type=password", {
  method: "POST",
  headers: { apikey: SUPABASE_ANON_KEY, "Content-Type": "application/json" },
  body: JSON.stringify({ email, password })
});
// { access_token, refresh_token, expires_in, user }
```

**ج) بعد الدخول** اقرأ الهوية:

```js
const me = await rpc("actor_name");   // الاسم
const adm = await rpc("is_admin");    // true/false
S.actor = me;
S.role  = adm ? "admin" : "agent";
```

> **لا تقرأ الدور من حقل بالواجهة ولا من `sessionStorage`.** لازم ييجي من
> القاعدة كل مرة. المستخدم بيقدر يعدّل `sessionStorage` من DevTools.

**د) `hdr()`** تستخدم `access_token` بدل مفتاح الخدمة:

```js
{ apikey: SUPABASE_ANON_KEY, Authorization: "Bearer " + S.token }
```

**هـ) تجديد التوكن.** صلاحيته ساعة، والمندوب بيضل باللوحة أطول.
خزّن `refresh_token`، وجدّد قبل الانتهاء بـ٦٠ ثانية:

```
POST /auth/v1/token?grant_type=refresh_token
```

لو فشل التجديد → `logout()` ورجّعه لشاشة الدخول برسالة واضحة.

**و) `logout()`** يستدعي `POST /auth/v1/logout` ويمسح `sessionStorage`.

**ز) شيل `p_actor` من كل استدعاء `rpc(...)`.** القاعدة بتحدده لحالها هلأ.

**ح) `S.key` بينشال كلياً.** ما بيضل ولا إشارة لـ`service_role` بالملف.

### فحص القبول

- بحث بالملف عن `service_role` و`sb_secret` → **صفر نتائج**
- بحث عن `p_actor` → **صفر نتائج**
- `node --check` على الجافاسكربت المستخرج → نظيف
- دخول بإيميل مندوب → أقسام «البلاغات» و«الباحثون» و«نشاط المنصة»
  و«سجل الإجراءات» و«الإعدادات» و«صفحات المحتوى» **ما بتظهر بالقائمة**
- أي إجراء → بينتسجّل بـ`admin_actions` **باسم المندوب من `staff`**، مش باسم مكتوب يدوياً

---

## مهمة ٣ — شيل Basic Auth من الـWorker

**بعد ما تخلص مهمة ٢ وتتأكد إنها شغالة. مش قبل.**

`src/worker.js` (١٥ سطر تقريباً) بيحرس `/admin` بـBasic Auth. ما عاد له لزوم:
الحماية الحقيقية صارت بالقاعدة، وBasic Auth بيصير طبقة كلمة سر ثانية مزعجة.

- شيل حارس Basic Auth
- **خلّي `X-Robots-Tag: noindex` على `/admin`**
- **لا تذكر `/admin` بـ`robots.txt`** (القاعدة ٨ بـ`CLAUDE.md`)
- بعد النشر: `/admin` = **200** وبيعرض شاشة الدخول (مش 401)

> لو مهمة ٢ ما زبطت، **لا تعمل مهمة ٣**. Basic Auth بيضل خط الدفاع الوحيد.

---

## بعد ما تخلص الثلاثة

**١. حدّث `CLAUDE.md`:**

- جدول الحالة: `service_role` بالمتصفح → ✅ انحلّ · حماية `/admin` → Supabase Auth
- الجداول: ١٦ → ١٧ (ضيف `staff`)
- الأنواع: ضيف `staff_role`
- قسم «من يقرأ ماذا»: الواجهات الإدارية صارت `authenticated` + `is_staff()`
- ضيف قاعدة حاكمة جديدة:
  **١٦. الأدوار من القاعدة (`staff`) مش من الواجهة. `p_actor` النصي انشال — الفاعل بييجي من `auth.uid()`.**
- شيل «نظام المستخدمين» من المهام المفتوحة
- حدّث قائمة الـmigrations

**٢. commit و push** برسالة وصفية.

**٣. `npx supabase migration list`** — عدد الملفات لازم يساوي المسجّلين.

**٤. `npx wrangler deploy`** ثم افحص:

| العنوان | المتوقع |
|---|---|
| `/` | 200 + الإعلانات |
| `/page.html?p=privacy` | 200 |
| `/admin` | 200 + شاشة دخول |

---

## مهمة ٤ — نوع السكن العائلي (صغيرة، بس لا تنساها)

النوع `family` انضاف لـenum `listing_kind` بالقاعدة
(migration `20260831173555`). الترتيب صار:

```
room_shared · bed_shared · studio · apartment · family
```

**بينقصه تسمية بالواجهتين — سطر واحد بكل ملف:**

`public/index.html` — ثابت `KIND` و`ICON`:

```js
const KIND = {room_shared:"غرفة بسكن مشترك", bed_shared:"سرير بغرفة مشتركة",
              studio:"استوديو", apartment:"شقة", family:"سكن عائلي"};
const ICON = {room_shared:"🛏", bed_shared:"🛌", studio:"🏠",
              apartment:"🏢", family:"👨‍👩‍👧"};
```

`public/admin/index.html` — ثابت `L_KIND`:

```js
const L_KIND = {room_shared:"غرفة بسكن مشترك", bed_shared:"سرير بغرفة مشتركة",
                studio:"ستوديو", apartment:"شقة", family:"سكن عائلي"};
```

> استثناء وحيد على قاعدة «لا تلمس `public/index.html` بهاي الدفعة» —
> سطر واحد فقط، ولا إشي تاني بالملف.

---

## ممنوع بهاي الدفعة

- ❌ لا تلمس `public/index.html` ولا `public/page.html`
- ❌ لا تعدّل `v_listings_public` ولا `v_requests_public`
- ❌ لا تضيف dependencies ولا build step
- ❌ لا تعيد ترقيم migrations موجودة
- ❌ لا تكتب أي مفتاح سري بأي ملف
- ❌ لا تبدأ برفع الصور ولا رابط التقييم ولا البحث — دفعات جاية

## لو وقفت

- **`create or replace view` بيفشل:** الأعمدة الجديدة بتنضاف بذيل القائمة فقط
- **جدول بيرجع `[]` بدون خطأ:** فخ الـzero-policy → `set local role anon; select …`
- **`revoke` نجح بس الصلاحية باقية:** المنحة من `PUBLIC` → `has_function_privilege`
- **`404` من Supabase:** كاش PostgREST → `notify pgrst, 'reload schema';`
- **الدخول بيرجع `400`:** الحساب مش Auto Confirmed، أو Email provider مقفول
