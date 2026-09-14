-- سكنّا: بادئة مرجع الإعلان MW- ← SK-

create or replace function public.set_listing_ref()
 returns trigger
 language plpgsql
as $function$
begin
  if new.ref is null then
    new.ref := 'SK-' || nextval('listing_ref_seq')::text;
  end if;
  return new;
end $function$;

alter sequence public.listing_ref_seq restart with 1001;
