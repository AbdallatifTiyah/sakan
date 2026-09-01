alter table public.pages  add column if not exists title_en text;
alter table public.pages  add column if not exists body_en  text;
alter table public.cities add column if not exists name_en  text;
alter table public.areas  add column if not exists name_en  text;
