-- تراخٍ اكتُشف بتدقيق أمني: grant update on notifications to authenticated كان بلا قيد أعمدة،
-- فيقدر المستخدم يزوّر title/body/event_type لإشعاراته الخاصة (RLS self_update يمنع النقل بين الحسابات لكن لا يقيّد الأعمدة).
-- account.html يكتب فقط is_read (grep فعلي: "PATCH" body:{is_read:true}) — التقييد يطابق الاستخدام الفعلي.
revoke update on notifications from authenticated;
grant update (is_read) on notifications to authenticated;
notify pgrst, 'reload schema';
