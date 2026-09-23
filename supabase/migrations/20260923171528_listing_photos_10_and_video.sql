-- سكنّا: رفع سقف صور الإعلان من ٦ إلى ١٠ + السماح برفع فيديو واحد (حتى ٥٠ م.ب)

alter table listings add column video_url text null;

-- ═══ bucket فيديوهات الإعلانات — نفس نمط listing-images ═══
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('listing-videos', 'listing-videos', true, 52428800,
        array['video/mp4','video/webm','video/quicktime'])
on conflict (id) do update set
  public = true,
  file_size_limit = 52428800,
  allowed_mime_types = array['video/mp4','video/webm','video/quicktime'];

drop policy if exists listing_videos_public_read on storage.objects;
create policy listing_videos_public_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'listing-videos');

drop policy if exists listing_videos_public_upload on storage.objects;
create policy listing_videos_public_upload on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'listing-videos');

drop policy if exists listing_videos_staff_delete on storage.objects;
create policy listing_videos_staff_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'listing-videos' and is_staff());

-- ═══ submit_listing: سقف الصور ٦ ← ١٠ + p_video_url ═══
drop function if exists public.submit_listing(text, text, text, integer, numeric, text, text, boolean, date, text, text, text, text[], numeric, smallint, smallint, jsonb, text, boolean, boolean, boolean, text, text);

create or replace function public.submit_listing(p_name text, p_phone text, p_title text, p_area integer, p_price numeric, p_kind text, p_pol text, p_furnished boolean, p_from date, p_occ text default NULL::text, p_landmark text default NULL::text, p_desc text default NULL::text, p_features text[] default '{}'::text[], p_deposit numeric default NULL::numeric, p_rooms smallint default NULL::smallint, p_min_stay smallint default NULL::smallint, p_images jsonb default '[]'::jsonb, p_currency text default 'ILS'::text, p_bills_water boolean default false, p_bills_electricity boolean default false, p_bills_internet boolean default false, p_promo_code text default NULL::text, p_rental_period text default 'monthly'::text, p_video_url text default NULL::text)
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
      select v from jsonb_array_elements_text(coalesce(p_images, '[]'::jsonb)) v limit 10
    ) t;

  insert into listings (owner_id, city_id, area_id, title, description, price, currency,
                        kind, gender_pol, furnished, available_from,
                        occupants_note, landmark, features, deposit,
                        bills_included, bills_water, bills_electricity, bills_internet,
                        rooms_total, min_stay_months, images, promo_code, rental_period, video_url)
  values (v_owner, v_city, p_area, trim(p_title), nullif(trim(coalesce(p_desc,'')),''),
          p_price, coalesce(nullif(p_currency,''),'ILS')::currency_code,
          p_kind::listing_kind, p_pol::gender_policy, coalesce(p_furnished,true),
          p_from, nullif(trim(coalesce(p_occ,'')),''), nullif(trim(coalesce(p_landmark,'')),''),
          coalesce(p_features,'{}'), p_deposit,
          v_bills_included, coalesce(p_bills_water,false), coalesce(p_bills_electricity,false), coalesce(p_bills_internet,false),
          p_rooms, p_min_stay, v_images, v_promo, coalesce(nullif(p_rental_period,''),'monthly')::rental_period,
          nullif(trim(coalesce(p_video_url,'')),''))
  returning ref into v_ref;

  insert into events (event_type, source, actor_role, meta)
  values ('listing_created','user','owner', jsonb_build_object('ref', v_ref));

  return v_ref;
end
$function$;

revoke all on function public.submit_listing(text, text, text, integer, numeric, text, text, boolean, date, text, text, text, text[], numeric, smallint, smallint, jsonb, text, boolean, boolean, boolean, text, text, text) from public;
grant execute on function public.submit_listing(text, text, text, integer, numeric, text, text, boolean, date, text, text, text, text[], numeric, smallint, smallint, jsonb, text, boolean, boolean, boolean, text, text, text) to anon, authenticated, service_role;

-- ═══ admin_listing_images: إضافة p_video_url (إدارة الفيديو مع الصور بنفس النداء) ═══
drop function if exists public.admin_listing_images(uuid, jsonb);

create or replace function public.admin_listing_images(p_id uuid, p_images jsonb, p_video_url text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), 'admin'), true);

  update listings set images = coalesce(p_images, '[]'::jsonb),
    video_url = nullif(trim(coalesce(p_video_url,'')),''),
    updated_at = now()
   where id = p_id;

  insert into admin_actions(actor, action, subject_type, subject_id)
  values (coalesce(nullif(actor_name(),'service'), 'admin'), 'listing_images', 'listing', p_id);
end $$;

revoke execute on function admin_listing_images(uuid, jsonb, text) from public;
grant  execute on function admin_listing_images(uuid, jsonb, text) to authenticated, service_role;

-- ═══ الواجهتان: إضافة video_url بذيل القائمة ═══
create or replace view public.v_listings_public as
 select l.id,
    l.ref,
    l.title,
    l.description,
    c.name_ar as city,
    c.slug as city_slug,
    a.name_ar as area,
    a.id as area_id,
    l.landmark,
    l.kind,
    l.price,
    l.bills_included,
    l.deposit,
    l.gender_pol,
    l.furnished,
    l.rooms_total,
    l.occupants_now,
    l.occupants_note,
    l.available_from,
    l.min_stay_months,
    l.images,
    l.verification,
    l.published_at,
    l.expires_at,
    l.view_count,
    coalesce((p.verification_level)::integer, 0) as owner_level,
    s.visit_date,
    s.door_lock,
    s.no_indoor_cameras,
    s.room_exists,
    s.photos_match,
    s.occupants_verified,
    s.exterior_lighting,
    s.gas_detector,
    ( select count(*) as count
           from reviews r
          where ((r.listing_id = l.id) and r.is_published)) as review_count,
    ( select round(avg((((((r.r_maintenance + r.r_quiet) + r.r_accuracy) + r.r_safety_night))::numeric / 4.0)), 1) as round
           from reviews r
          where ((r.listing_id = l.id) and r.is_published)) as review_avg,
    c.id as city_id,
    s.private_bathroom,
    s.kitchen_access,
    s.heating,
    s.internet,
    s.emergency_exit,
    s.street_access,
    l.features,
    l.video_verified_at,
    l.currency,
    l.bills_water,
    l.bills_electricity,
    l.bills_internet,
    l.rental_period,
    l.video_url
   from ((((listings l
     join cities c on ((c.id = l.city_id)))
     join areas a on ((a.id = l.area_id)))
     left join profiles p on ((p.id = l.owner_id)))
     left join listing_safety s on ((s.listing_id = l.id)))
  where (l.status = 'published'::listing_status);

create or replace view public.v_admin_listings as
 select l.id,
    l.ref,
    l.title,
    l.description,
    l.kind,
    l.status,
    l.verification,
    l.price,
    l.deposit,
    l.bills_included,
    l.gender_pol,
    l.furnished,
    l.rooms_total,
    l.occupants_now,
    l.occupants_note,
    l.available_from,
    l.min_stay_months,
    l.landmark,
    l.exact_address,
    l.images,
    l.reject_reason,
    l.published_at,
    l.expires_at,
    l.last_confirmed_at,
    l.rented_at,
    l.created_at,
    l.updated_at,
    l.view_count,
    l.confirm_token,
    l.city_id,
    c.name_ar as city,
    l.area_id,
    a.name_ar as area,
    p.id as owner_id,
    p.first_name as owner_name,
    p.phone as owner_phone,
    p.verification_level as owner_level,
    p.is_blocked as owner_blocked,
    s.visit_date,
    s.room_exists,
    s.photos_match,
    s.door_lock,
    s.no_indoor_cameras,
    s.occupants_verified,
    s.exterior_lighting,
    s.gas_detector,
    s.notes as safety_notes,
    ( select count(*) as count
           from contact_requests cr
          where (cr.listing_id = l.id)) as contacts,
    ( select count(*) as count
           from contact_requests cr
          where ((cr.listing_id = l.id) and (cr.status = 'rented'::contact_status))) as rentals,
    ( select count(*) as count
           from reports r
          where ((r.listing_id = l.id) and (r.status = 'open'::report_status))) as open_reports,
    ( select count(*) as count
           from reviews rv
          where (rv.listing_id = l.id)) as reviews_count,
        case
            when (l.expires_at is null) then null::integer
            else ((l.expires_at)::date - current_date)
        end as days_left,
    s.private_bathroom,
    s.kitchen_access,
    s.heating,
    s.internet,
    s.emergency_exit,
    s.street_access,
    s.owner_met,
    l.features,
    l.review_token,
    l.video_verified_at,
    l.currency,
    l.bills_water,
    l.bills_electricity,
    l.bills_internet,
    l.rental_period,
    l.video_url
   from ((((listings l
     join cities c on ((c.id = l.city_id)))
     join areas a on ((a.id = l.area_id)))
     left join profiles p on ((p.id = l.owner_id)))
     left join listing_safety s on ((s.listing_id = l.id)));
alter view public.v_admin_listings set (security_invoker = on);
