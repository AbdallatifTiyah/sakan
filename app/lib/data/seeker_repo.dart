import '../main.dart';

/// استدعاء submit_request() حرفياً — صفر منطق عمل بالتطبيق.
class SeekerRepo {
  static Future<String> submitRequest({
    required String name,
    required String phone,
    String? gender,
    required String occupation,
    required num budget,
    required List<int> areas,
    required DateTime moveIn,
    List<String> tags = const [],
    String? note,
    int? city,
    String? kind,
    bool? furnished,
    int? minStayMonths,
    required bool smoker,
    String? rentalPeriodPref,
    int? roomsPref,
  }) async {
    final ref = await supabase.rpc('submit_request', params: {
      'p_name': name,
      'p_phone': phone,
      'p_gender': gender,
      'p_occupation': occupation,
      'p_budget': budget,
      'p_areas': areas,
      'p_move_in': moveIn.toIso8601String().split('T').first,
      'p_tags': tags,
      'p_note': note,
      'p_city': city,
      'p_kind': kind,
      'p_furnished': furnished,
      'p_min_stay': minStayMonths,
      'p_smoker': smoker,
      'p_rental_period_pref': rentalPeriodPref,
      'p_rooms_pref': roomsPref,
    });
    return ref as String;
  }
}
