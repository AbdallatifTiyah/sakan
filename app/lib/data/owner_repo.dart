import '../main.dart';

class FeeQuote {
  final num feeBefore;
  final num feeAfter;
  final int discountPct;
  const FeeQuote({required this.feeBefore, required this.feeAfter, required this.discountPct});
}

/// RPCs مسار "أضف شقتك" — صفر حساب رسوم بالتطبيق (قاعدة ٢٠، نفس مبدأ index.html).
class OwnerRepo {
  static Future<num> quoteListingFee(String kind) async {
    final res = await supabase.rpc('quote_listing_fee', params: {'p_kind': kind});
    return res as num;
  }

  /// يرمي استثناء برسالة القاعدة الحرفية لو الكود غلط/منتهي (نفس فحوصات
  /// admin_fee_promo — قاعدة ١٧). ممنوع أي نص "صفر" ثابت بالواجهة.
  static Future<FeeQuote> quotePromoDiscount(String code, String kind) async {
    final rows = await supabase.rpc('quote_promo_discount', params: {'p_code': code, 'p_kind': kind});
    final row = (rows as List).first as Map<String, dynamic>;
    return FeeQuote(
      feeBefore: row['fee_before'] as num,
      feeAfter: row['fee_after'] as num,
      discountPct: row['discount_pct'] as int,
    );
  }

  static Future<String> submitListing({
    required String name,
    required String phone,
    required String title,
    required int area,
    required num price,
    required String kind,
    required List<String> genderPols,
    required bool furnished,
    required DateTime availableFrom,
    String? occupantsNote,
    String? landmark,
    String? description,
    required List<String> features,
    num? deposit,
    int? rooms,
    int? minStayMonths,
    required List<String> images,
    required String currency,
    required bool billsWater,
    required bool billsElectricity,
    required bool billsInternet,
    String? promoCode,
    required String rentalPeriod,
    int? neighborhood,
  }) async {
    final ref = await supabase.rpc('submit_listing', params: {
      'p_name': name,
      'p_phone': phone,
      'p_title': title,
      'p_area': area,
      'p_price': price,
      'p_kind': kind,
      'p_pol': genderPols,
      'p_furnished': furnished,
      'p_from': availableFrom.toIso8601String().split('T').first,
      'p_occ': occupantsNote,
      'p_landmark': landmark,
      'p_desc': description,
      'p_features': features,
      'p_deposit': deposit,
      'p_rooms': rooms,
      'p_min_stay': minStayMonths,
      'p_images': images,
      'p_currency': currency,
      'p_bills_water': billsWater,
      'p_bills_electricity': billsElectricity,
      'p_bills_internet': billsInternet,
      'p_promo_code': promoCode,
      'p_rental_period': rentalPeriod,
      'p_neighborhood': neighborhood,
    });
    return ref as String;
  }

  /// طلب حذف — يراجعه الطاقم، ما بيحذف فوراً (الحذف الفعلي عبر مركز التحكم).
  static Future<void> requestListingDeletion(String listingId) async {
    await supabase.rpc('my_request_listing_deletion', params: {'p_listing_id': listingId});
  }
}
