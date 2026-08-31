-- إصلاح: علامات اتجاه خفية (RLM/LRM وشبيهاتها) بتنحقن أحياناً حوالين
-- نص لاتيني (زي اليوزرنيم) لما تتكتب جوّا صفحة RTL أو من كيبورد عربي/موبايل.
-- btrim() ما بيشيلها لأنها مش مسافات — فصار البحث عن اليوزرنيم يفشل بصمت.
create or replace function staff_email_for_username(p_username text) returns text
language sql stable security definer set search_path = public as $$
  select email from staff
   where lower(username) = lower(regexp_replace(
           btrim(p_username),
           '[' || chr(8203) || chr(8204) || chr(8205) || chr(8206) || chr(8207) ||
                  chr(8234) || chr(8235) || chr(8236) || chr(8237) || chr(8238) ||
                  chr(8294) || chr(8295) || chr(8296) || chr(8297) || chr(65279) || ']',
           '', 'g'))
     and is_active
   limit 1;
$$;

revoke execute on function staff_email_for_username(text) from public;
grant  execute on function staff_email_for_username(text) to anon, authenticated, service_role;

notify pgrst, 'reload schema';
