# تشخيص سريع

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
| `permission denied for function X` من واجهة `security_invoker` | دالة مستخدَمة جوّا تعريف الـview نفسه بدون منح `authenticated` — شوف الدرس بقسم «من يقرأ ماذا» بـCLAUDE.md. |
| اسم ملف الـmigration المحلي ما بطابق `supabase_migrations` بعد `apply_migration` | أداة الـMCP بتسجّل نسختها الزمنية الخاصة، مش اسم الملف اللي أعطيته. **دايماً** شغّل `list_migrations` بعد التطبيق وسمّي الملف المحلي بنفس الرقم بالضبط. |
| حذف من `storage.objects` بـSQL مباشر بيرفض حتى بـ`service_role` | `protect_delete` trigger مقصود. احذف عبر Storage API (`DELETE /storage/v1/object/<bucket>/<path>`) بمفتاح عنده صلاحية `delete` على الـbucket. |
| `function is not unique` وقت استدعاء دالة إدارية بمعطيات مسمّاة | `create or replace function` بمعطيات إضافية (حتى لو كلها بـ`default`) بتغيّر التوقيع (argument type list) وبتخلق **overload جديد** بدل ما تستبدل القديمة. لازم `drop function if exists <old signature exact types>` صريح قبلها، وبعدين `revoke`/`grant` من جديد على التوقيع الجديد (المنح ما بينورث تلقائياً). صار مع `admin_page_save`/`admin_city_save`/`admin_area_save` وقت إضافة الحقول الإنجليزية. |
