-- create or replace function مع قائمة معطيات مختلفة (إضافة p_name_en/p_title_en/p_body_en)
-- بينشئ overload جديد بدل ما يستبدل القديم — لازم drop صريح للتوقيع القديم
-- وإلا بيصير استدعاء بمعطيات مسمّاة غامض (function is not unique) بين النسختين.
drop function if exists public.admin_city_save(int, text, text, boolean, text);
drop function if exists public.admin_area_save(int, int, text, text, int, boolean, text);
drop function if exists public.admin_page_save(text, text, text, boolean, text);

revoke all on function public.admin_city_save(int, text, text, boolean, text, text) from public;
grant execute on function public.admin_city_save(int, text, text, boolean, text, text) to authenticated, service_role;

revoke all on function public.admin_area_save(int, int, text, text, int, boolean, text, text) from public;
grant execute on function public.admin_area_save(int, int, text, text, int, boolean, text, text) to authenticated, service_role;

revoke all on function public.admin_page_save(text, text, text, boolean, text, text, text) from public;
grant execute on function public.admin_page_save(text, text, text, boolean, text, text, text) to authenticated, service_role;
