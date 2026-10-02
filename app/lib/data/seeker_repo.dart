import '../main.dart';

/// استدعاء submit_request() حرفياً — صفر منطق عمل بالتطبيق.
class SeekerRepo {
  /// طلبات الباحثين المنشورة — نفس v_requests_public المستخدمة بالموقع، قراءة
  /// عامة بمفتاح anon (قاعدة ٢). تُستخدم بشاشة "الباحثين" لعرض الطلب الفعلي.
  static Future<List<Map<String, dynamic>>> fetchPublicRequests() async {
    final rows = await supabase.from('v_requests_public').select().order('created_at', ascending: false).limit(30);
    return (rows as List).map((r) => (r as Map).cast<String, dynamic>()).toList();
  }

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
    List<int> neighborhoods = const [],
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
      'p_neighborhoods': neighborhoods,
    });
    return ref as String;
  }

  /// طلب حذف — يراجعه الطاقم، ما بيحذف فوراً (الحذف الفعلي عبر مركز التحكم).
  static Future<void> requestDeletion(String requestId) async {
    await supabase.rpc('my_request_seeker_deletion', params: {'p_request_id': requestId});
  }
}
