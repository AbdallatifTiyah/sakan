import '../widgets/verification_ribbon.dart';

/// نموذج يطابق أعمدة v_listings_public الحية (استعلام حي بتاريخ ٢٠٢٦-١٠-٠٢،
/// ٥١ عمود) — القراءة العامة الوحيدة المسموحة (قاعدة ٢).
class Listing {
  final String id, ref, title;
  final String? description, landmark, occupantsNote;
  final String city, citySlug, area;
  final int? areaId, cityId;
  final String? neighborhood;
  final int? neighborhoodId;
  final String kind; // listing_kind: room_shared/bed_shared/studio/apartment/family
  final num price;
  final String currency;
  final bool billsIncluded, billsWater, billsElectricity, billsInternet;
  final num? deposit;
  final String genderPol; // gender_policy: female/male/mixed
  final bool furnished;
  final int? roomsTotal, occupantsNow;
  final DateTime? availableFrom;
  final int? minStayMonths;
  final List<String> images;
  final List<String> features;
  final SVerification verification;
  final DateTime? visitDate; // لتوثيق field
  final DateTime? videoVerifiedAt; // لتوثيق video
  final String? videoUrl;
  final String rentalPeriod; // monthly/weekly/daily
  final int viewCount;
  final num? reviewAvg;
  final int reviewCount;
  final bool? doorLock, noIndoorCameras;

  const Listing({
    required this.id,
    required this.ref,
    required this.title,
    this.description,
    this.landmark,
    this.occupantsNote,
    required this.city,
    required this.citySlug,
    required this.area,
    this.areaId,
    this.cityId,
    this.neighborhood,
    this.neighborhoodId,
    required this.kind,
    required this.price,
    required this.currency,
    required this.billsIncluded,
    required this.billsWater,
    required this.billsElectricity,
    required this.billsInternet,
    this.deposit,
    required this.genderPol,
    required this.furnished,
    this.roomsTotal,
    this.occupantsNow,
    this.availableFrom,
    this.minStayMonths,
    required this.images,
    required this.features,
    required this.verification,
    this.visitDate,
    this.videoVerifiedAt,
    this.videoUrl,
    required this.rentalPeriod,
    required this.viewCount,
    this.reviewAvg,
    required this.reviewCount,
    this.doorLock,
    this.noIndoorCameras,
  });

  factory Listing.fromJson(Map<String, dynamic> j) {
    SVerification parseVerification(String? v) => switch (v) {
          'field' => SVerification.field,
          'video' => SVerification.video,
          'desk' => SVerification.desk,
          _ => SVerification.none,
        };

    DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v as String);

    List<String> parseImages(dynamic v) {
      if (v == null) return const [];
      return (v as List).map((e) => e.toString()).toList();
    }

    List<String> parseFeatures(dynamic v) {
      if (v == null) return const [];
      return (v as List).map((e) => e.toString()).toList();
    }

    return Listing(
      id: j['id'] as String,
      ref: j['ref'] as String,
      title: j['title'] as String,
      description: j['description'] as String?,
      landmark: j['landmark'] as String?,
      occupantsNote: j['occupants_note'] as String?,
      city: j['city'] as String? ?? '',
      citySlug: j['city_slug'] as String? ?? '',
      area: j['area'] as String? ?? '',
      areaId: j['area_id'] as int?,
      cityId: j['city_id'] as int?,
      neighborhood: j['neighborhood'] as String?,
      neighborhoodId: j['neighborhood_id'] as int?,
      kind: j['kind'] as String? ?? 'apartment',
      price: j['price'] as num? ?? 0,
      currency: j['currency'] as String? ?? 'ILS',
      billsIncluded: j['bills_included'] as bool? ?? false,
      billsWater: j['bills_water'] as bool? ?? false,
      billsElectricity: j['bills_electricity'] as bool? ?? false,
      billsInternet: j['bills_internet'] as bool? ?? false,
      deposit: j['deposit'] as num?,
      genderPol: j['gender_pol'] as String? ?? 'mixed',
      furnished: j['furnished'] as bool? ?? false,
      roomsTotal: j['rooms_total'] as int?,
      occupantsNow: j['occupants_now'] as int?,
      availableFrom: parseDate(j['available_from']),
      minStayMonths: j['min_stay_months'] as int?,
      images: parseImages(j['images']),
      features: parseFeatures(j['features']),
      verification: parseVerification(j['verification'] as String?),
      visitDate: parseDate(j['visit_date']),
      videoVerifiedAt: parseDate(j['video_verified_at']),
      videoUrl: j['video_url'] as String?,
      rentalPeriod: j['rental_period'] as String? ?? 'monthly',
      viewCount: j['view_count'] as int? ?? 0,
      reviewAvg: j['review_avg'] as num?,
      reviewCount: (j['review_count'] as num?)?.toInt() ?? 0,
      doorLock: j['door_lock'] as bool?,
      noIndoorCameras: j['no_indoor_cameras'] as bool?,
    );
  }

  String get currencySymbol => switch (currency) {
        'JOD' => 'د.أ',
        'USD' => '\$',
        _ => 'شيكل',
      };

  String get rentalPeriodLabel => switch (rentalPeriod) {
        'weekly' => 'أسبوع',
        'daily' => 'يوم',
        _ => 'شهر',
      };

  /// نفس منطق dt(x.visit_date)/dt(x.video_verified_at) بـverifBadge() —
  /// desk بدون تاريخ عمداً (شارة قديمة، قاعدة ٢٤).
  DateTime? get verifiedAt => switch (verification) {
        SVerification.field => visitDate,
        SVerification.video => videoVerifiedAt,
        _ => null,
      };
}
