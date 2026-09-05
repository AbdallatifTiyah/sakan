-- create or replace view يصفّر خيار security_invoker إذا ما انكتب صراحة بنفس الأمر —
-- لازم إعادة تفعيله فوراً بعد أي "create or replace view" على أي view فيه هالخيار.
alter view v_admin_owners set (security_invoker = on);
alter view v_admin_seekers set (security_invoker = on);
