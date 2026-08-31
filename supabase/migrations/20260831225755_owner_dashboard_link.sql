-- رابط المالك الموقّع — نفس نمط confirm_token/review_token، بس على مستوى المالك
-- مش الإعلان: توكن واحد بيوريه كل إعلاناته وكل طلبات التواصل عليها، بدون تسجيل دخول.

alter table public.profiles
  add column if not exists owner_token uuid not null default gen_random_uuid();

create unique index if not exists profiles_owner_token_key
  on public.profiles using btree (owner_token);

comment on column public.profiles.owner_token is
  'رمز سري لرابط لوحة المالك اللي المندوب بيشاركه (واتساب) — بيوريه إعلاناته وطلبات التواصل عليها بدون تسجيل دخول.';

-- الأعمدة الجديدة بذيل القائمة فقط — نفس تعريف v_admin_owners الأصلي بالضبط + owner_token.
create or replace view public.v_admin_owners as
select
  p.id, p.first_name, p.full_name, p.phone, p.verification_level, p.is_blocked,
  p.created_at, p.city_id, c.name_ar as city,
  (select count(*) from listings l where l.owner_id = p.id) as listings_total,
  (select count(*) from listings l where l.owner_id = p.id and l.status = 'published') as listings_published,
  (select count(*) from listings l where l.owner_id = p.id and l.status = 'pending')   as listings_pending,
  (select count(*) from listings l where l.owner_id = p.id and l.status = 'rented')    as listings_rented,
  (select max(l.created_at) from listings l where l.owner_id = p.id) as last_listing_at,
  (select coalesce(sum(f.amount_due),0) from owner_fees f join listings l on l.id = f.listing_id
     where l.owner_id = p.id and f.status = 'due') as fees_due,
  (select coalesce(sum(f.amount_due),0) from owner_fees f join listings l on l.id = f.listing_id
     where l.owner_id = p.id and f.status = 'collected') as fees_collected,
  (select count(*) from reports r join listings l on l.id = r.listing_id where l.owner_id = p.id) as reports_total,
  p.owner_token
from profiles p
left join cities c on c.id = p.city_id
where p.role = 'owner';

alter view public.v_admin_owners set (security_invoker = on);
revoke all on public.v_admin_owners from anon;
grant select on public.v_admin_owners to authenticated, service_role;

-- ═══ لوحة المالك: إعلاناته + طلبات التواصل عليها، بدون تسجيل دخول ═══
-- سبب جمعهن بدالة وحدة بدل view عام: القيمة بتختلف حسب الفاعل (owner_id)
-- المطلوب بالتوكن، مش عمود ثابت — ونفس منطق submit_listing بالتحقق أول شي.
create or replace function public.owner_dashboard(p_owner_id uuid, p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare v_name text;
begin
  select first_name into v_name from profiles
   where id = p_owner_id and owner_token = p_token and role = 'owner';

  if v_name is null then
    raise exception 'رابط غير صالح';
  end if;

  return jsonb_build_object(
    'owner_name', v_name,
    'listings', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', l.id, 'ref', l.ref, 'title', l.title, 'status', l.status,
        'verification', l.verification, 'price', l.price,
        'city', c.name_ar, 'area', a.name_ar,
        'published_at', l.published_at, 'expires_at', l.expires_at,
        'days_left', case when l.expires_at is null then null
                          else l.expires_at::date - current_date end,
        'view_count', l.view_count, 'reject_reason', l.reject_reason,
        'confirm_token', l.confirm_token
      ) order by l.created_at desc), '[]'::jsonb)
      from listings l
      join cities c on c.id = l.city_id
      join areas  a on a.id = l.area_id
      where l.owner_id = p_owner_id
    ),
    'requests', (
      -- رقم الباحث ما بيظهر إلا بعد ما المندوب يحوّل الطلب فعلياً —
      -- نفس البوابة اللي شغّالة يدوياً هلأ، بس معروضة ذاتياً للمالك.
      select coalesce(jsonb_agg(jsonb_build_object(
        'listing_ref', l.ref, 'listing_title', l.title,
        'seeker_name', cr.seeker_name,
        'seeker_phone', case when cr.status <> 'new' then cr.seeker_phone else null end,
        'status', cr.status, 'created_at', cr.created_at
      ) order by cr.created_at desc), '[]'::jsonb)
      from contact_requests cr
      join listings l on l.id = cr.listing_id
      where l.owner_id = p_owner_id
    )
  );
end $$;

revoke execute on function public.owner_dashboard(uuid, uuid) from public;
grant  execute on function public.owner_dashboard(uuid, uuid) to anon, authenticated, service_role;

notify pgrst, 'reload schema';
