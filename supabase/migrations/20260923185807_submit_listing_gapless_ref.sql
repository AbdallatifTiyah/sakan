create or replace function public.submit_listing(p_name text, p_phone text, p_title text, p_area integer, p_price numeric, p_kind text, p_pol text, p_furnished boolean, p_from date, p_occ text DEFAULT NULL::text, p_landmark text DEFAULT NULL::text, p_desc text DEFAULT NULL::text, p_features text[] DEFAULT '{}'::text[], p_deposit numeric DEFAULT NULL::numeric, p_rooms smallint DEFAULT NULL::smallint, p_min_stay smallint DEFAULT NULL::smallint, p_images jsonb DEFAULT '[]'::jsonb, p_currency text DEFAULT 'ILS'::text, p_bills_water boolean DEFAULT false, p_bills_electricity boolean DEFAULT false, p_bills_internet boolean DEFAULT false, p_promo_code text DEFAULT NULL::text, p_rental_period text DEFAULT 'monthly'::text, p_video_url text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_owner uuid; v_ref text; v_city int; v_images jsonb; v_bills_included boolean;
  v_promo text; pc record; v_listing_id uuid;
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
      select v from jsonb_array_elements_text(coalesce(p_images, '[]'::jsonb)) v limit 10
    ) t;

  -- ref يتسجّل بقيمة مؤقتة فريدة هون عمداً (تتجاوز trg_listing_ref لأنها مش null)،
  -- وتتحول لرقم SK- الفعلي بآخر سطر بالدالة — بعد ما نضمن نجاح كل شي غيره.
  -- الهدف: nextval() ما ينستهلك إلا لما يكون النجاح شبه مؤكد، فما تصير فجوات
  -- بالتسلسل بسبب محاولات فشلت بمنتصف الدالة (فحص قيد، خطأ إدخال، إلخ).
  insert into listings (owner_id, city_id, area_id, title, description, price, currency,
                        kind, gender_pol, furnished, available_from,
                        occupants_note, landmark, features, deposit,
                        bills_included, bills_water, bills_electricity, bills_internet,
                        rooms_total, min_stay_months, images, promo_code, rental_period, video_url,
                        ref)
  values (v_owner, v_city, p_area, trim(p_title), nullif(trim(coalesce(p_desc,'')),''),
          p_price, coalesce(nullif(p_currency,''),'ILS')::currency_code,
          p_kind::listing_kind, p_pol::gender_policy, coalesce(p_furnished,true),
          p_from, nullif(trim(coalesce(p_occ,'')),''), nullif(trim(coalesce(p_landmark,'')),''),
          coalesce(p_features,'{}'), p_deposit,
          v_bills_included, coalesce(p_bills_water,false), coalesce(p_bills_electricity,false), coalesce(p_bills_internet,false),
          p_rooms, p_min_stay, v_images, v_promo, coalesce(nullif(p_rental_period,''),'monthly')::rental_period,
          nullif(trim(coalesce(p_video_url,'')),''),
          'PENDING-' || gen_random_uuid()::text)
  returning id into v_listing_id;

  insert into events (event_type, source, actor_role, meta)
  values ('listing_created','user','owner', jsonb_build_object('listing_id', v_listing_id));

  update listings set ref = 'SK-' || nextval('listing_ref_seq')::text
  where id = v_listing_id
  returning ref into v_ref;

  return v_ref;
end
$function$;
