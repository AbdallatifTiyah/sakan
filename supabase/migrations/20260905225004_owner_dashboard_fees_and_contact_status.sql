-- (أ) owner_dashboard: إضافة مفتاح fees — رسوم إعلانات هذا المالك بحالة due/collected فقط.
-- تعديل جسم فقط، نفس التوقيع ونفس نوع الإرجاع بالضبط — بدون drop ولا إعادة منح.
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
        'status', cr.status, 'created_at', cr.created_at,
        'id', cr.id
      ) order by cr.created_at desc), '[]'::jsonb)
      from contact_requests cr
      join listings l on l.id = cr.listing_id
      where l.owner_id = p_owner_id
    ),
    'fees', (
      -- بس due/collected — ممنوع waived/lost وممنوع amount_base/promo_code/collected_by.
      select coalesce(jsonb_agg(jsonb_build_object(
        'amount_due', f.amount_due,
        'status', f.status,
        'listing_ref', l.ref,
        'collected_at', f.collected_at
      ) order by f.created_at desc), '[]'::jsonb)
      from owner_fees f
      join listings l on l.id = f.listing_id
      where l.owner_id = p_owner_id
        and f.status in ('due', 'collected')
    )
  );
end $$;

-- (ب) owner_contact_status — تغيير حالة طلب تواصل من طرف المالك نفسه، بتوكنه الموقّع.
-- بيسمح فقط بـ owner_responded / viewing_set / dead. rented/forwarded/new مرفوضة دايماً
-- (rented حدث فوترة بيخلق صف owner_fees عبر on_contact_rented — يضل بيد الطاقم حصراً).
create or replace function public.owner_contact_status(
  p_owner_id uuid, p_token uuid, p_contact_id uuid, p_status contact_status
)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  v_owner record;
  v_listing_id uuid;
begin
  select id, is_blocked into v_owner
    from profiles
   where id = p_owner_id and owner_token = p_token and role = 'owner';

  if v_owner.id is null then
    raise exception 'رابط غير صالح';
  end if;

  select cr.listing_id into v_listing_id
    from contact_requests cr
    join listings l on l.id = cr.listing_id
   where cr.id = p_contact_id and l.owner_id = p_owner_id;

  if v_listing_id is null then
    raise exception 'الطلب غير موجود لهذا المالك';
  end if;

  if v_owner.is_blocked then
    raise exception 'الحساب موقوف';
  end if;

  if p_status not in ('owner_responded', 'viewing_set', 'dead') then
    raise exception 'حالة غير مسموحة لهذا الإجراء';
  end if;

  update contact_requests set status = p_status where id = p_contact_id;

  insert into events (event_type, source, actor_role, listing_id, meta)
  values ('contact_status_owner_updated', 'user', 'owner', v_listing_id,
          jsonb_build_object('contact_id', p_contact_id, 'status', p_status));
end $$;

revoke execute on function public.owner_contact_status(uuid, uuid, uuid, contact_status) from public;
grant  execute on function public.owner_contact_status(uuid, uuid, uuid, contact_status) to anon, authenticated, service_role;

notify pgrst, 'reload schema';
