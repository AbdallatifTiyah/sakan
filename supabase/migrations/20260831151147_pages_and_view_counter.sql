-- ═══════════════════════════════════════════════════════════
-- ١) صفحات المحتوى (سياسة الخصوصية والشروط) — قابلة للتعديل
--    من مركز التحكم بدون إعادة نشر الموقع
-- ═══════════════════════════════════════════════════════════
create table if not exists pages (
  key         text primary key,
  title_ar    text not null,
  body_md     text not null,
  is_published boolean not null default true,
  updated_at  timestamptz not null default now(),
  updated_by  text
);

alter table pages enable row level security;

drop policy if exists public_read_pages on pages;
create policy public_read_pages on pages
  for select to anon, authenticated
  using (is_published);

grant select on pages to anon, authenticated;
grant all    on pages to service_role;

create or replace function admin_page_save(
  p_key text, p_title text, p_body text,
  p_published boolean default true, p_actor text default null
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(btrim(p_body),'') = '' then raise exception 'النص فاضي'; end if;
  perform set_config('app.actor', coalesce(p_actor,'admin'), true);

  insert into pages(key, title_ar, body_md, is_published, updated_at, updated_by)
  values (p_key, p_title, p_body, coalesce(p_published,true), now(), coalesce(p_actor,'admin'))
  on conflict (key) do update set
    title_ar = excluded.title_ar,
    body_md  = excluded.body_md,
    is_published = excluded.is_published,
    updated_at = now(),
    updated_by = excluded.updated_by;

  insert into admin_actions(actor, action, subject_type, subject_ref, reason)
  values (coalesce(p_actor,'admin'), 'page_save', 'page', p_key, null);
end $$;

revoke execute on function admin_page_save(text,text,text,boolean,text) from public;
revoke execute on function admin_page_save(text,text,text,boolean,text) from anon;
revoke execute on function admin_page_save(text,text,text,boolean,text) from authenticated;
grant  execute on function admin_page_save(text,text,text,boolean,text) to service_role;


-- ═══════════════════════════════════════════════════════════
-- ٢) عدّاد المشاهدات — كان عمود ميت (صفر دايماً، ما في
--    إشي بيزيده). صار عنده دالة، والزيادة محصورة بالإعلانات
--    المنشورة عشان ما ينستخدم لسبر وجود إعلانات مخفية.
-- ═══════════════════════════════════════════════════════════
create or replace function bump_listing_view(p_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  update listings
     set view_count = coalesce(view_count, 0) + 1
   where id = p_id
     and status = 'published'::listing_status;
end $$;

revoke execute on function bump_listing_view(uuid) from public;
grant  execute on function bump_listing_view(uuid) to anon, authenticated, service_role;
