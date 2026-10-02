import 'widgets/verification_ribbon.dart';

/// بيانات تجريبية فقط — صفر اتصال بالقاعدة. الأسماء والهياكل تطابق أعمدة
/// v_listings_public الحقيقية (استعلام حي بتاريخ ٢٠٢٦-١٠-٠٢) لتسهيل الربط لاحقاً.
class MockListing {
  final String ref;
  final String title;
  final String city;
  final String area;
  final int price;
  final String currency;
  final int rooms;
  final bool furnished;
  final bool billsWater, billsElectricity, billsInternet;
  final SVerification verification;
  final DateTime? verifiedDate;
  final List<String> images;
  final List<String> features;
  final String? landmark;

  const MockListing({
    required this.ref,
    required this.title,
    required this.city,
    required this.area,
    required this.price,
    this.currency = 'ILS',
    required this.rooms,
    required this.furnished,
    this.billsWater = false,
    this.billsElectricity = false,
    this.billsInternet = false,
    required this.verification,
    this.verifiedDate,
    required this.images,
    this.features = const [],
    this.landmark,
  });

  String get currencySymbol => switch (currency) {
        'JOD' => 'د.أ',
        'USD' => '\$',
        _ => 'شيكل',
      };
}

final mockListings = <MockListing>[
  MockListing(
    ref: 'SK-1042',
    title: 'شقة عائلية واسعة قرب حي الطيرة',
    city: 'رام الله',
    area: 'الطيرة',
    price: 2500,
    rooms: 3,
    furnished: true,
    billsWater: true,
    billsElectricity: false,
    billsInternet: true,
    verification: SVerification.field,
    images: ['assets/mock/listing1.jpg'],
    features: ['family_friendly', 'parking', 'balcony'],
    landmark: 'قرب مدارس الطيرة',
  ),
  MockListing(
    ref: 'SK-1038',
    title: 'شقة مفروشة بالكامل بإطلالة هادئة',
    city: 'البيرة',
    area: 'البالوع',
    price: 3200,
    rooms: 2,
    furnished: true,
    billsWater: true,
    billsElectricity: true,
    billsInternet: true,
    verification: SVerification.video,
    verifiedDate: DateTime(2026, 9, 15),
    images: ['assets/mock/listing2.jpg'],
    features: ['family_friendly', 'elevator', 'ac'],
  ),
  MockListing(
    ref: 'SK-1051',
    title: 'شقة قريبة من جامعة بيرزيت',
    city: 'بيرزيت',
    area: 'وسط البلد',
    price: 1800,
    rooms: 2,
    furnished: false,
    billsWater: false,
    billsElectricity: false,
    billsInternet: false,
    verification: SVerification.none,
    images: ['assets/mock/listing3.jpg'],
    features: ['near_transport'],
  ),
];

final mockListingDetail = MockListing(
  ref: 'SK-1042',
  title: 'شقة عائلية واسعة قرب حي الطيرة',
  city: 'رام الله',
  area: 'الطيرة',
  price: 2500,
  rooms: 3,
  furnished: true,
  billsWater: true,
  billsElectricity: false,
  billsInternet: true,
  verification: SVerification.field,
  verifiedDate: DateTime(2026, 9, 13),
  images: const ['assets/mock/listing1.jpg', 'assets/mock/listing1b.jpg'],
  features: const ['family_friendly', 'parking', 'balcony', 'heating', 'private_entrance'],
  landmark: 'قرب مدارس الطيرة',
);
