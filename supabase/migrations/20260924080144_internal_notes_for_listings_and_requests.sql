create table internal_notes (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid references listings(id) on delete cascade,
  request_id uuid references seeker_requests(id) on delete cascade,
  body text not null,
  created_by text not null,
  created_at timestamptz not null default now(),
  constraint internal_notes_target_chk check (
    (listing_id is not null and request_id is null) or
    (listing_id is null and request_id is not null)
  )
);

create index internal_notes_listing_idx on internal_notes(listing_id, created_at desc);
create index internal_notes_request_idx on internal_notes(request_id, created_at desc);

alter table internal_notes enable row level security;
create policy staff_read on internal_notes for select using (is_staff());

grant select on internal_notes to authenticated, service_role;

create or replace function admin_add_note(p_listing_id uuid, p_request_id uuid, p_body text)
returns internal_notes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row internal_notes;
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح';
  end if;
  if p_body is null or btrim(p_body) = '' then
    raise exception 'الملاحظة فاضية';
  end if;
  if (p_listing_id is null) = (p_request_id is null) then
    raise exception 'لازم إعلان واحد أو طلب واحد بالضبط';
  end if;
  insert into internal_notes(listing_id, request_id, body, created_by)
  values (p_listing_id, p_request_id, btrim(p_body), actor_name())
  returning * into v_row;
  return v_row;
end;
$$;

revoke execute on function admin_add_note(uuid,uuid,text) from public;
grant execute on function admin_add_note(uuid,uuid,text) to authenticated, service_role;

create or replace function admin_delete_note(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (is_staff() or auth.uid() is null) then
    raise exception 'غير مصرّح';
  end if;
  delete from internal_notes where id = p_id;
end;
$$;

revoke execute on function admin_delete_note(uuid) from public;
grant execute on function admin_delete_note(uuid) to authenticated, service_role;
