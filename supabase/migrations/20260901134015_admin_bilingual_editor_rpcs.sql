create or replace function public.admin_city_save(
  p_id int, p_name text, p_slug text, p_active boolean default true,
  p_name_en text default null, p_actor text default null
) returns int language plpgsql security definer set search_path = public as $$
declare v_id int;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  if p_id is null then
    insert into cities(name_ar, slug, is_active, name_en) values (p_name, p_slug, p_active, nullif(btrim(p_name_en),''))
    returning id into v_id;
  else
    update cities set name_ar = p_name, slug = p_slug, is_active = p_active,
                       name_en = nullif(btrim(p_name_en),'')
     where id = p_id returning id into v_id;
  end if;
  insert into admin_actions(actor, action, subject_type, subject_ref, to_state)
  values (coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), 'city_save', 'city', p_name, p_active::text);
  return v_id;
end $$;

create or replace function public.admin_area_save(
  p_id int, p_city int, p_name text, p_slug text,
  p_sort int default 100, p_active boolean default true,
  p_name_en text default null, p_actor text default null
) returns int language plpgsql security definer set search_path = public as $$
declare v_id int;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);
  if p_id is null then
    insert into areas(city_id, name_ar, slug, sort_order, is_active, name_en)
    values (p_city, p_name, p_slug, coalesce(p_sort,100), p_active, nullif(btrim(p_name_en),''))
    returning id into v_id;
  else
    update areas set city_id = p_city, name_ar = p_name, slug = p_slug,
                     sort_order = coalesce(p_sort,100), is_active = p_active,
                     name_en = nullif(btrim(p_name_en),'')
     where id = p_id returning id into v_id;
  end if;
  insert into admin_actions(actor, action, subject_type, subject_ref, to_state)
  values (coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), 'area_save', 'area', p_name, p_active::text);
  return v_id;
end $$;

create or replace function public.admin_page_save(
  p_key text, p_title text, p_body text,
  p_published boolean default true,
  p_title_en text default null, p_body_en text default null,
  p_actor text default null
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not (is_admin() or auth.uid() is null) then
    raise exception 'غير مصرّح' using errcode = '42501';
  end if;
  if coalesce(btrim(p_body),'') = '' then raise exception 'النص فاضي'; end if;
  perform set_config('app.actor', coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), true);

  insert into pages(key, title_ar, body_md, is_published, title_en, body_en, updated_at, updated_by)
  values (p_key, p_title, p_body, coalesce(p_published,true),
          nullif(btrim(p_title_en),''), nullif(btrim(p_body_en),''),
          now(), coalesce(nullif(actor_name(),'service'), p_actor, 'admin'))
  on conflict (key) do update set
    title_ar = excluded.title_ar,
    body_md  = excluded.body_md,
    is_published = excluded.is_published,
    title_en = excluded.title_en,
    body_en  = excluded.body_en,
    updated_at = now(),
    updated_by = excluded.updated_by;

  insert into admin_actions(actor, action, subject_type, subject_ref, reason)
  values (coalesce(nullif(actor_name(),'service'), p_actor, 'admin'), 'page_save', 'page', p_key, null);
end $$;
