-- الحقل الجديد: كود الخصم اللي المالك بيدخله وقت التسجيل (بدل ما يبقى الطاقم يدخله وقت التحصيل فقط)
alter table public.listings add column promo_code text;

-- دالة عامة للتحقق من كود الخصم وعرض الرسم قبل وبعد الخصم، قبل إرسال الفورم
create or replace function public.quote_promo_discount(p_code text, p_kind listing_kind)
returns table(code text, discount_pct smallint, fee_before numeric, fee_after numeric)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_code text := nullif(upper(trim(p_code)), '');
  pc record;
  v_fee numeric;
begin
  if v_code is null then
    raise exception 'اكتب كود الخصم أولاً';
  end if;

  select * into pc from promo_codes where code = v_code;
  if not found then
    raise exception 'كود الخصم غير موجود';
  end if;
  if not pc.is_active then
    raise exception 'كود الخصم غير مفعّل';
  end if;
  if pc.valid_until is not null and pc.valid_until < current_date then
    raise exception 'كود الخصم منتهي الصلاحية';
  end if;
  if pc.max_uses is not null and pc.used_count >= pc.max_uses then
    raise exception 'كود الخصم وصل الحد الأقصى للاستخدام';
  end if;

  v_fee := quote_listing_fee(p_kind);

  return query
    select pc.code, pc.discount_pct, v_fee, round(v_fee * (100 - pc.discount_pct) / 100.0, 2);
end
$function$;

revoke all on function public.quote_promo_discount(text, listing_kind) from public;
grant execute on function public.quote_promo_discount(text, listing_kind) to anon, authenticated;

-- submit_listing: إضافة p_promo_code بذيل التوقيع — لازم drop صريح، وإلا create or replace بيخلق overload جديد
drop function if exists public.submit_listing(text, text, text, integer, numeric, text, text, boolean, date, text, text, text, text[], numeric, smallint, smallint, jsonb, text, boolean, boolean, boolean);

create or replace function public.submit_listing(
  p_name text, p_phone text, p_title text, p_area integer, p_price numeric, p_kind text, p_pol text,
  p_furnished boolean, p_from date, p_occ text default null, p_landmark text default null, p_desc text default null,
  p_features text[] default '{}'::text[], p_deposit numeric default null, p_rooms smallint default null, p_min_stay smallint default null,
  p_images jsonb default '[]'::jsonb, p_currency text default 'ILS', p_bills_water boolean default false,
  p_bills_electricity boolean default false, p_bills_internet boolean default false, p_promo_code text default null
)
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_owner uuid; v_ref text; v_city int; v_images jsonb; v_bills_included boolean;
  v_promo text; pc record;
begin
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' then
    raise exception 'الاسم والرقم مطلوبان';
  end if;

  select city_id into v_city from areas where id = p_area and is_active;
  if v_city is null then raise exception 'منطقة غير صحيحة'; end if;

  v_bills_included := coalesce(p_bills_water,false) and coalesce(p_bills_electricity,false) and coalesce(p_bills_internet,false);

  v_promo := nullif(upper(trim(p_promo_code)), '');
  if v_promo is not null then
    select * into pc from promo_codes where code = v_promo;
    if not found then
      raise exception 'كود الخصم غير موجود';
    end if;
    if not pc.is_active then
      raise exception 'كود الخصم غير مفعّل';
    end if;
    if pc.valid_until is not null and pc.valid_until < current_date then
      raise exception 'كود الخصم منتهي الصلاحية';
    end if;
    if pc.max_uses is not null and pc.used_count >= pc.max_uses then
      raise exception 'كود الخصم وصل الحد الأقصى للاستخدام';
    end if;
  end if;

  insert into profiles (role, first_name, phone, city_id)
  values ('owner', trim(p_name), trim(p_phone), v_city)
  returning id into v_owner;

  select coalesce(jsonb_agg(v), '[]'::jsonb) into v_images
    from (
      select v from jsonb_array_elements_text(coalesce(p_images, '[]'::jsonb)) v limit 6
    ) t;

  insert into listings (owner_id, city_id, area_id, title, description, price, currency,
                        kind, gender_pol, furnished, available_from,
                        occupants_note, landmark, features, deposit,
                        bills_included, bills_water, bills_electricity, bills_internet,
                        rooms_total, min_stay_months, images, promo_code)
  values (v_owner, v_city, p_area, trim(p_title), nullif(trim(coalesce(p_desc,'')),''),
          p_price, coalesce(nullif(p_currency,''),'ILS')::currency_code,
          p_kind::listing_kind, p_pol::gender_policy, coalesce(p_furnished,true),
          p_from, nullif(trim(coalesce(p_occ,'')),''), nullif(trim(coalesce(p_landmark,'')),''),
          coalesce(p_features,'{}'), p_deposit,
          v_bills_included, coalesce(p_bills_water,false), coalesce(p_bills_electricity,false), coalesce(p_bills_internet,false),
          p_rooms, p_min_stay, v_images, v_promo)
  returning ref into v_ref;

  insert into events (event_type, source, actor_role, meta)
  values ('listing_created','user','owner', jsonb_build_object('ref', v_ref));

  return v_ref;
end
$function$;

revoke all on function public.submit_listing(text, text, text, integer, numeric, text, text, boolean, date, text, text, text, text[], numeric, smallint, smallint, jsonb, text, boolean, boolean, boolean, text) from public;
grant execute on function public.submit_listing(text, text, text, integer, numeric, text, text, boolean, date, text, text, text, text[], numeric, smallint, smallint, jsonb, text, boolean, boolean, boolean, text) to anon, authenticated;

-- on_contact_rented: نقل كود الخصم المُدخَل وقت التسجيل تلقائياً لصف owner_fees الجديد
-- (الطاقم يقدر يبدّله لاحقاً عبر admin_fee_promo كما كان)
create or replace function public.on_contact_rented()
returns trigger
language plpgsql
as $function$
begin
  if new.status = 'rented' and old.status is distinct from 'rented' then
    new.outcome_at := now();
    update listings set status = 'rented' where id = new.listing_id;
    insert into owner_fees (listing_id, contact_request_id, promo_code)
    select new.listing_id, new.id, l.promo_code
    from listings l where l.id = new.listing_id
    on conflict do nothing;
  end if;
  return new;
end
$function$;
