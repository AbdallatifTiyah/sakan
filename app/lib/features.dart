/// نفس قائمة FEATURES بـpublic/index.html حرفياً (slug/ar/en) — مصدر واحد للتسميات.
/// التحديث هون لازم يرافقه نفس التحديث بـindex.html (وبالعكس).
class SFeature {
  final String slug, ar, en;
  const SFeature(this.slug, this.ar, this.en);
}

const sFeatures = <SFeature>[
  SFeature('wifi', 'واي فاي', 'WiFi'),
  SFeature('kitchen', 'مطبخ', 'Kitchen access'),
  SFeature('private_bathroom', 'حمام خاص', 'Private bathroom'),
  SFeature('washer', 'غسالة', 'Washing machine'),
  SFeature('heating', 'تدفئة', 'Heating'),
  SFeature('ac', 'مكيّف', 'Air conditioning'),
  SFeature('hot_water_electric', 'بويلر كهرباء', 'Electric boiler'),
  SFeature('hot_water_solar', 'حمام شمسي', 'Solar heater'),
  SFeature('balcony', 'بلكونة', 'Balcony'),
  SFeature('parking', 'موقف سيارة', 'Parking'),
  SFeature('elevator', 'مصعد', 'Elevator'),
  SFeature('near_transport', 'قرب وسائل المواصلات', 'Near public transport'),
  SFeature('private_entrance', 'مدخل مستقل', 'Private entrance'),
  SFeature('room_lock', 'قفل على باب الغرفة', 'Lock on room door'),
  SFeature('family_friendly', 'مناسبة للعائلات', 'Family-friendly'),
];

String featureLabel(String slug) {
  for (final f in sFeatures) {
    if (f.slug == slug) return f.ar;
  }
  return slug;
}
