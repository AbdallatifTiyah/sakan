-- ═══════════════════════════════════════════════════════════
-- رفع الصور — Supabase Storage
-- السبب: listings.images فاضي دايماً، ما كان في طريق يوصل صورة
-- لإعلان. الرفع بيصير من متصفح المالك مباشرة (قبل submit_listing)
-- عشان نقدر نمرّر روابط الصور لدالة النشر بنفس الاستدعاء.
-- الإعلان نفسه بيضل pending لحد ما المندوب يراجعه — فمو محتاجين
-- إشراف إضافي على الصور، المراجعة العادية كافية.
-- ═══════════════════════════════════════════════════════════

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('listing-images', 'listing-images', true, 5242880,
        array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists listing_images_public_read on storage.objects;
create policy listing_images_public_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'listing-images');

-- رفع فقط، بدون تعديل أو حذف — المالك ما بيقدر يمسح صورة رفعها
-- غيره ولا يستبدلها. أي ضبط لاحق بيصير من مركز التحكم.
drop policy if exists listing_images_public_upload on storage.objects;
create policy listing_images_public_upload on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'listing-images');

-- ═══════════════════════════════════════════════════════════
-- submit_listing: إضافة p_images (سقف ٦ صور، تجاهل صامت لأي
-- إشي زيادة بدل ما نرفض الإعلان كامل)
-- ═══════════════════════════════════════════════════════════

drop function if exists submit_listing(
  text, text, text, integer, numeric, text, text, boolean, date,
  text, text, text, text[], numeric, boolean, smallint, smallint
);

create or replace function public.submit_listing(
  p_name text, p_phone text, p_title text, p_area integer, p_price numeric,
  p_kind text, p_pol text, p_furnished boolean, p_from date,
  p_occ text default null, p_landmark text default null, p_desc text default null,
  p_features text[] default '{}', p_deposit numeric default null,
  p_bills boolean default false, p_rooms smallint default null,
  p_min_stay smallint default null, p_images jsonb default '[]'::jsonb
) returns text
language plpgsql security definer set search_path = public as $$
declare v_owner uuid; v_ref text; v_city int; v_images jsonb;
begin
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_phone),'')='' then
    raise exception 'الاسم والرقم مطلوبان';
  end if;

  select city_id into v_city from areas where id = p_area and is_active;
  if v_city is null then raise exception 'منطقة غير صحيحة'; end if;

  select id into v_owner from profiles
   where phone = trim(p_phone) and role = 'owner' limit 1;

  if v_owner is null then
    insert into profiles (role, first_name, phone, city_id)
    values ('owner', trim(p_name), trim(p_phone), v_city)
    returning id into v_owner;
  end if;

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
end $$;

revoke execute on function submit_listing(
  text, text, text, integer, numeric, text, text, boolean, date,
  text, text, text, text[], numeric, boolean, smallint, smallint, jsonb
) from public;
grant execute on function submit_listing(
  text, text, text, integer, numeric, text, text, boolean, date,
  text, text, text, text[], numeric, boolean, smallint, smallint, jsonb
) to anon, authenticated, service_role;

notify pgrst, 'reload schema';
