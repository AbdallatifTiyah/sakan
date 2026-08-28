-- Reference data: cities and areas. Not test data — the site is
-- unusable without these. Idempotent so it is safe on an existing db.

insert into public.cities (id, name_ar, slug, is_active) values
  (1, 'رام الله والبيرة', 'ramallah',  true),
  (2, 'بيرزيت',           'birzeit',   true),
  (3, 'نابلس',            'nablus',    false),
  (4, 'بيت لحم',          'bethlehem', false),
  (5, 'الخليل',           'hebron',    false)
on conflict (id) do update
  set name_ar = excluded.name_ar,
      slug      = excluded.slug,
      is_active = excluded.is_active;

insert into public.areas (id, city_id, name_ar, slug, sort_order) values
  ( 1, 1, 'الماصيون',                 'masyoun',           10),
  ( 2, 1, 'الطيرة',                   'tireh',             20),
  ( 3, 1, 'أم الشرايط',               'um-al-sharayet',    30),
  ( 4, 1, 'عين مصباح',                'ein-misbah',        40),
  ( 5, 1, 'البالوع',                  'baloa',             50),
  ( 6, 1, 'بيتونيا',                  'beitunia',          60),
  ( 7, 1, 'الإرسال',                  'irsal',             70),
  ( 8, 1, 'رام الله التحتا',          'downtown',          80),
  ( 9, 1, 'البيرة — المنطقة الصناعية', 'bireh-industrial',  90),
  (10, 1, 'سردا',                     'surda',            100),
  (11, 2, 'وسط بيرزيت',               'birzeit-center',    10),
  (12, 2, 'قرب الجامعة',              'near-campus',       20),
  (13, 2, 'أبو قش',                   'abu-qash',          30)
on conflict (id) do update
  set city_id    = excluded.city_id,
      name_ar    = excluded.name_ar,
      slug       = excluded.slug,
      sort_order = excluded.sort_order;

-- Explicit ids were inserted, so the sequences must be advanced
-- or the next auto-generated id collides with an existing row.
select setval('cities_id_seq', (select max(id) from public.cities));
select setval('areas_id_seq',  (select max(id) from public.areas));
