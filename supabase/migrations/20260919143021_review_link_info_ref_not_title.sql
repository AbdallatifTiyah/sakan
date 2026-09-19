-- الخصوصية: عنوان الإعلان ما عاد يظهر بأي واجهة عامة، وصفحة رابط التقييم استثناء
-- كانت منسية. نفس اسم العمود (title) بالتوقيع — بس القيمة صارت الرمز (ref).
create or replace function public.review_link_info(p_ref text, p_token uuid)
returns table(title text, city text, area text)
language sql
security definer
set search_path to 'public', 'pg_temp'
as $$
  select l.ref, c.name_ar, a.name_ar
  from listings l
  join cities c on c.id = l.city_id
  join areas  a on a.id = l.area_id
  where l.ref = p_ref and l.review_token = p_token;
$$;
