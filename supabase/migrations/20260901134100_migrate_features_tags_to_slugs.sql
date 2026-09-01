-- مواصفات الغرفة (listings.features) وصفات الباحث (seeker_requests.lifestyle_tags)
-- كانت مخزّنة كنص عربي حرفي (نفس نص العرض). بدّلناها لـslugs إنجليزية ثابتة
-- عشان تسمية العرض تصير عربي/إنجليزي حسب اللغة بدل ما تضل عربي دايماً.
update public.listings set features = (
  select array_agg(
    case elem
      when 'واي فاي' then 'wifi'
      when 'مطبخ' then 'kitchen'
      when 'حمام خاص' then 'private_bathroom'
      when 'غسالة' then 'washer'
      when 'تدفئة' then 'heating'
      when 'مكيّف' then 'ac'
      when 'ماء ساخن' then 'hot_water'
      when 'بلكونة' then 'balcony'
      when 'موقف سيارة' then 'parking'
      when 'مصعد' then 'elevator'
      when 'قريب مواصلات' then 'near_transport'
      when 'مسموح الطبخ' then 'cooking_allowed'
      when 'مدخل مستقل' then 'private_entrance'
      when 'قفل على باب الغرفة' then 'room_lock'
      else elem
    end)
  from unnest(features) as elem
) where features <> '{}';

update public.seeker_requests set lifestyle_tags = (
  select array_agg(
    case elem
      when 'هادئ/ة' then 'quiet'
      when 'غير مدخّن/ة' then 'non_smoker'
      when 'بشتغل من البيت' then 'wfh'
      when 'دوام جامعي' then 'university_hours'
      when 'بحب النظام' then 'tidy'
      when 'ملتزم/ة دينياً' then 'religious'
      when 'ما بستقبل ضيوف' then 'no_guests'
      when 'صاحي/ة بكير' then 'early_riser'
      else elem
    end)
  from unnest(lifestyle_tags) as elem
) where lifestyle_tags <> '{}';
