insert into settings (key, value, label_ar, kind) values
  ('fee_apartment', '500', 'رسم نجاح الشقة الكاملة (شيكل)', 'number'),
  ('fee_studio', '300', 'رسم نجاح الاستوديو (شيكل)', 'number'),
  ('fee_room_shared', '100', 'رسم نجاح الغرفة المشتركة (شيكل)', 'number'),
  ('fee_bed_shared', '100', 'رسم نجاح السرير المشترك (شيكل)', 'number'),
  ('fee_family', '500', 'رسم نجاح السكن العائلي (شيكل)', 'number')
on conflict (key) do nothing;
