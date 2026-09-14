-- إصلاح ثغرة انتحال: submit_listing كانت تربط الإعلان الجديد بأي profile
-- مالك موجود بمطابقة رقم الهاتف وحده (بدون أي تحقّق OTP)، فأي حدا يعرف رقم
-- مالك حقيقي يقدر ينشر إعلاناً منسوباً لبروفايله. نفس المبدأ اللي انطبّق على
-- link_account_role (إلغاء الربط التلقائي بمطابقة الهاتف) — كل استدعاء
-- بينشئ صف profiles جديد دايماً، بدون أي lookup بالهاتف. الدمج اليدوي
-- لصفوف مكررة (نفس الهاتف، أكثر من صف) يبقى قراراً بشري صريح للطاقم،
-- خارج نطاق هالدالة.
create or replace function public.submit_listing(
  p_name text, p_phone text, p_title text, p_area integer, p_price numeric,
  p_kind text, p_pol text, p_furnished boolean, p_from date,
  p_occ text default null, p_landmark text default null, p_desc text default null,
  p_features text[] default '{}', p_deposit numeric default null,
  p_bills boolean default false, p_rooms smallint default null,
  p_min_stay smallint default null, p_images jsonb default '[]'
)
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_owner uuid; v_ref text; v_city int; v_images jsonb;
begin
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' then
    raise exception 'الاسم والرقم مطلوبان';
  end if;

  select city_id into v_city from areas where id = p_area and is_active;
  if v_city is null then raise exception 'منطقة غير صحيحة'; end if;

  insert into profiles (role, first_name, phone, city_id)
  values ('owner', trim(p_name), trim(p_phone), v_city)
  returning id into v_owner;

  select coalesce(jsonb_agg(v), '[]'::jsonb) into v_images
    from (
      select v from jsonb_array_elements_text(coalesce(p_images, '[]'::jsonb)) v limit 6
    ) t;

  insert into listings (owner_id, city_id, area_id, title, description, price,
                        kind, gender_pol, furnished, available_from,
                        occupants_note, landmark, features, deposit,
                        bills_included, rooms_total, min_stay_months, images)
  values (v_owner, v_city, p_area, trim(p_title), nullif(trim(coalesce(p_desc,'')),''),
          p_price, p_kind::listing_kind, p_pol::gender_policy, coalesce(p_furnished,true),
          p_from, nullif(trim(coalesce(p_occ,'')),''), nullif(trim(coalesce(p_landmark,'')),''),
          coalesce(p_features,'{}'), p_deposit, coalesce(p_bills,false), p_rooms, p_min_stay,
          v_images)
  returning ref into v_ref;

  insert into events (event_type, source, actor_role, meta)
  values ('listing_created','user','owner', jsonb_build_object('ref', v_ref));

  return v_ref;
end $function$;
