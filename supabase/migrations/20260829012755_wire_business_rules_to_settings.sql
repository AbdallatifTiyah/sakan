-- نفس القواعد التجارية بالضبط — بس القيم صارت تُقرأ من جدول settings بدل ما تكون مكتوبة بالكود
-- الافتراضيات مطابقة للسلوك الحالي: ٢٠٠ شيكل · ٢١ يوم · ٣ تقييمات

alter table public.owner_fees alter column amount_base drop default;
alter table public.owner_fees alter column amount_base drop not null;

create or replace function public.compute_fee_due() returns trigger
language plpgsql as $$
declare pct smallint := 0;
begin
  if new.amount_base is null then
    new.amount_base := setting_num('fee_base', 200);
  end if;
  if new.promo_code is not null then
    select discount_pct into pct from promo_codes
     where code = new.promo_code and is_active
       and (valid_until is null or valid_until >= current_date)
       and (max_uses is null or used_count < max_uses);
    pct := coalesce(pct, 0);
  end if;
  new.amount_due := round(new.amount_base * (100 - pct) / 100.0, 2);
  return new;
end $$;

create or replace function public.on_contact_rented() returns trigger
language plpgsql as $$
begin
  if new.status = 'rented' and old.status is distinct from 'rented' then
    new.outcome_at := now();
    update listings set status = 'rented' where id = new.listing_id;
    insert into owner_fees (listing_id, contact_request_id)
    values (new.listing_id, new.id)
    on conflict do nothing;
  end if;
  return new;
end $$;

create or replace function public.on_listing_publish() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  if new.status = 'published' and (old.status is distinct from 'published') then
    new.published_at      := coalesce(new.published_at, now());
    new.last_confirmed_at := now();
    new.expires_at        := now() + (setting_num('listing_expiry_days', 21) || ' days')::interval;
  end if;
  if new.status = 'rented' and old.status is distinct from 'rented' then
    new.rented_at := now();
  end if;
  return new;
end $$;

create or replace function public.publish_reviews_at_threshold() returns trigger
language plpgsql as $$
begin
  if (select count(*) from reviews where listing_id = new.listing_id)
     >= setting_num('review_publish_threshold', 3) then
    update reviews set is_published = true where listing_id = new.listing_id;
  end if;
  return new;
end $$;
