import '../main.dart';
import '../models/listing.dart';

/// طبقة وصول البيانات الوحيدة لـv_listings_public وcontact_requests — صفر
/// منطق عمل هون (قاعدة ١١ بـCLAUDE.md: كل منطق عبر RPC/views موجودة أصلاً).
class ListingsRepo {
  static Future<List<Listing>> fetchListings({
    String? citySlug,
    String? search,
    int limit = 30,
  }) async {
    var query = supabase.from('v_listings_public').select();
    if (citySlug != null) {
      query = query.eq('city_slug', citySlug);
    }
    if (search != null && search.trim().isNotEmpty) {
      query = query.or('title.ilike.%$search%,area.ilike.%$search%,landmark.ilike.%$search%');
    }
    final rows = await query.order('published_at', ascending: false).limit(limit);
    return (rows as List).map((r) => Listing.fromJson(r as Map<String, dynamic>)).toList();
  }

  static Future<Listing?> fetchListingById(String id) async {
    final row = await supabase.from('v_listings_public').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return Listing.fromJson(row);
  }

  static Future<void> bumpView(String id) async {
    await supabase.rpc('bump_listing_view', params: {'p_id': id});
  }

  static Future<void> submitContactRequest({
    required String listingId,
    required String name,
    required String phone,
  }) async {
    await supabase.from('contact_requests').insert({
      'listing_id': listingId,
      'seeker_name': name,
      'seeker_phone': phone,
    });
  }
}
