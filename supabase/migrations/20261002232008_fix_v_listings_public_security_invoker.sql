-- v_listings_public لازم تبقى view عادية (بدون security_invoker) لأنها الواجهة
-- العامة اللي anon بيقراها مباشرة — migration 20261003150000 غلطت وحطت
-- security_invoker=on عليها بالتساوي مع v_admin_listings/v_reverse_matches
-- (الاثنتان الداخليتان صح، هاي غلط). بدون هالريسِت، anon يحتاج GRANT مباشر
-- على جدول listings (مش موجود عمداً، قاعدة ١ بـCLAUDE.md) فيرجع 401/42501.
alter view public.v_listings_public reset (security_invoker);
