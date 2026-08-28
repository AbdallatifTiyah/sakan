-- سحب سكربت التأمين صلاحيات service_role بالغلط مع anon.
-- service_role دور إداري داخلي، بيتجاوز RLS، ولازم يملك كل شي.
-- هذا لا يمس anon ولا authenticated.

grant select, insert, update, delete on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;

alter default privileges in schema public
  grant select, insert, update, delete on tables to service_role;
alter default privileges in schema public
  grant usage, select on sequences to service_role;
alter default privileges in schema public
  grant execute on functions to service_role;
