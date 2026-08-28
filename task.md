أنشئ admin.html من الصفر بجذر المشروع (مش داخل public).
صفحة واحدة، vanilla JS، RTL عربي، بدون أي dependencies خارجية.

الأمان — قاعدة لا تُخالف:
لا تكتب مفتاح service_role بالكود إطلاقاً.
اعمل حقل إدخال بأعلى الصفحة يلصق فيه المستخدم المفتاح،
واحفظه بـ sessionStorage فقط (بينمسح لما يسكّر التبويب).
لو المفتاح فاضي، اعرض الحقل وما تنادِ أي API.

Supabase URL: https://yckteijitcqjtedoyoyv.supabase.co

المحتوى:
1) جدول الإعلانات من listings بالأعمدة:
   ref, title, status, verification, expires_at, confirm_token
   وبكل صف زر "نسخ رابط التأكيد" بينسخ للحافظة:
   https://sakan.abdallatif-tiyah.workers.dev/?c=<ref>&t=<confirm_token>

2) جدول طلبات التواصل من contact_requests بالأعمدة:
   created_at, seeker_name, seeker_phone, status
   مع ref الإعلان المرتبط.

3) أزرار تغيير حالة الإعلان: published / rejected / rented

تأكد إنه admin.html مذكور بالـ.gitignore قبل ما تخلص.
لا تعمل commit لملف admin.html نفسه.