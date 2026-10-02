-- طبقة ثالثة (حي/الموقع) تحت المنطقة + تحويل بيرزيت من مدينة لمنطقة ضمن رام الله والبيرة

create table public.neighborhoods (
  id serial primary key,
  area_id integer not null references public.areas(id),
  name_ar text not null,
  name_en text,
  slug text not null,
  sort_order integer not null default 100,
  is_active boolean not null default true
);

alter table public.neighborhoods enable row level security;

create policy public_read_neighborhoods on public.neighborhoods
  for select to anon, authenticated
  using (
    is_active
    and exists (
      select 1 from public.areas a join public.cities c on c.id = a.city_id
      where a.id = neighborhoods.area_id and a.is_active and c.is_active
    )
  );

create policy staff_read on public.neighborhoods
  for select to authenticated using (public.is_staff());

revoke all on public.neighborhoods from public;
grant select on public.neighborhoods to anon, authenticated;
grant select, insert, update, delete on public.neighborhoods to service_role;
grant usage, select on sequence public.neighborhoods_id_seq to service_role;

alter table public.listings
  add column neighborhood_id integer references public.neighborhoods(id);

alter table public.seeker_requests
  add column neighborhood_ids integer[] not null default '{}';

-- بيرزيت: من مدينة لمنطقة ضمن "رام الله والبيرة"، ومناطقها الثلاث القديمة تصير أحياء تحتها
do $$
declare
  v_birzeit_area_id integer;
begin
  insert into public.areas (city_id, name_ar, name_en, slug, sort_order, is_active)
  values (1, 'بيرزيت', 'Birzeit', 'birzeit', 110, true)
  returning id into v_birzeit_area_id;

  insert into public.neighborhoods (id, area_id, name_ar, name_en, slug, sort_order, is_active)
  select id, v_birzeit_area_id, name_ar, name_en, slug, sort_order, is_active
  from public.areas
  where id in (11, 12, 13);

  perform setval('public.neighborhoods_id_seq', (select max(id) from public.neighborhoods));

  update public.listings
     set neighborhood_id = area_id,
         area_id = v_birzeit_area_id,
         city_id = 1
   where city_id = 2;

  update public.seeker_requests
     set neighborhood_ids = area_ids,
         area_ids = array[v_birzeit_area_id],
         city_id = 1
   where city_id = 2;

  update public.profiles set city_id = 1 where city_id = 2;
  update public.institution_leads set city_id = 1 where city_id = 2;

  delete from public.areas where id in (11, 12, 13);
  delete from public.cities where id = 2;
end $$;
