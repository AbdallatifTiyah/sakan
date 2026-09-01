-- بادئة رقم الإعلان SK- → MW- (سكن → موضع). ما في format check constraint على listings.ref
-- (تأكّدنا: القيد الوحيد عليها UNIQUE)، وما في أي دالة تانية أو كود واجهة بيقارن/يفلتر
-- بالنص 'SK-' حرفياً (تأكّدنا عبر information_schema.routines وgrep على public/ وsrc/).
-- نفس نمط الترقيم بالضبط — نفس الـsequence (listing_ref_seq)، نفس عدد الخانات.

create or replace function public.set_listing_ref()
  RETURNS trigger
  LANGUAGE plpgsql
AS $function$
begin
  if new.ref is null then
    new.ref := 'MW-' || nextval('listing_ref_seq')::text;
  end if;
  return new;
end $function$;

-- backfill الصفوف الموجودة (٣ إعلانات منشورة: SK-1002, SK-1003, SK-1006) — نفس الرقم، بادئة جديدة فقط.
update public.listings
set ref = 'MW-' || substring(ref from 4)
where ref like 'SK-%';
