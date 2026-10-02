create or replace function public.my_seeker_dashboard()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); v_seeker uuid;
begin
  if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
  select id into v_seeker from profiles where account_uid = v_uid and role = 'seeker';
  if v_seeker is null then
    return jsonb_build_object('requests','[]'::jsonb,'saved','[]'::jsonb);
  end if;

  return jsonb_build_object(
    'requests', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'ref', r.ref, 'status', r.status, 'city', c.name_ar,
        'budget_max', r.budget_max, 'created_at', r.created_at,
        'expires_at', r.expires_at
      ) order by r.created_at desc), '[]'::jsonb)
      from seeker_requests r join cities c on c.id=r.city_id
      where r.seeker_id = v_seeker
    ),
    'saved', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'ref', v.ref, 'title', v.title, 'city', v.city, 'area', v.area, 'neighborhood', v.neighborhood,
        'price', v.price, 'currency', v.currency, 'status', case when v.id is null then 'removed' else 'active' end
      ) order by s.created_at desc), '[]'::jsonb)
      from saved_listings s
      left join v_listings_public v on v.id = s.listing_id
      where s.account_uid = v_uid
    )
  );
end $function$;
