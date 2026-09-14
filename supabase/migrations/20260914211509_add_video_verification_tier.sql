-- طبقة توثيق ثانية أضعف من الزيارة الميدانية: مكالمة فيديو حيّة.
-- listings.verification enum جاهز أصلاً لهيك (none/desk/field) — أضيفت
-- قيمة 'video' بينهما (none < desk < video < field) بدل تغيير نوع العمود
-- بالكامل. لا يوجد أي مكان بالقاعدة يقارن هالـenum بعدم مساواة (> أو <)،
-- كله مطابقة حرفية (= 'field') أو تمرير كنص — فإدراج قيمة بالمنتصف آمن.
--
-- تحذير دائم: PostgreSQL ما بيسمح بحذف قيمة enum لاحقاً. 'video' اسم
-- نهائي فعلياً.
--
-- video_verified_at عمود جديد على listings — التوثيق الميداني عنده
-- تاريخه أصلاً (listing_safety.visit_date)، والمكالمة المرئية ما إلها
-- مكان طبيعي بجدول listing_safety (هذا جدول فحص فعلي/فيزيائي بالمكان —
-- قفل، كاميرات، إلخ — لا ينطبق على مكالمة عن بعد).
--
-- ALTER TYPE ... ADD VALUE ما بينقدر يُستخدم بنفس الترانزاكشن اللي
-- أضافه — هالملف ما بيشير لـ'video' بأي جملة SQL نصّية، بس إضافة العمود
-- (بلا علاقة بقيمة الـenum) آمنة بنفس الترانزاكشن. تحديث
-- admin_listing_verification() ليستخدم 'video' صار بميغريشن منفصل تالٍ
-- (احتياط إضافي حتى لو المقارنة عنده على النص الخام p_level مش على الـenum).
alter type listing_verification add value 'video' after 'desk';

alter table listings add column video_verified_at date;
