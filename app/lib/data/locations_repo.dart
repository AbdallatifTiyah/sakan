import '../main.dart';

class SCity {
  final int id;
  final String nameAr, slug;
  const SCity({required this.id, required this.nameAr, required this.slug});

  factory SCity.fromJson(Map<String, dynamic> j) =>
      SCity(id: j['id'] as int, nameAr: j['name_ar'] as String, slug: j['slug'] as String);
}

class SArea {
  final int id, cityId;
  final String nameAr, slug;
  const SArea({required this.id, required this.cityId, required this.nameAr, required this.slug});

  factory SArea.fromJson(Map<String, dynamic> j) => SArea(
        id: j['id'] as int,
        cityId: j['city_id'] as int,
        nameAr: j['name_ar'] as String,
        slug: j['slug'] as String,
      );
}

/// الحي (الموقع) — طبقة ثالثة اختيارية تحت المنطقة.
class SNeighborhood {
  final int id, areaId;
  final String nameAr, slug;
  const SNeighborhood({required this.id, required this.areaId, required this.nameAr, required this.slug});

  factory SNeighborhood.fromJson(Map<String, dynamic> j) => SNeighborhood(
        id: j['id'] as int,
        areaId: j['area_id'] as int,
        nameAr: j['name_ar'] as String,
        slug: j['slug'] as String,
      );
}

/// قاعدة ١٣: المدن والمناطق والأحياء من القاعدة، مش من مصفوفة جافاسكربت/دارت ثابتة.
class LocationsRepo {
  static Future<List<SCity>> fetchCities() async {
    final rows = await supabase.from('cities').select().eq('is_active', true).order('id');
    return (rows as List).map((r) => SCity.fromJson(r as Map<String, dynamic>)).toList();
  }

  static Future<List<SArea>> fetchAreas(int cityId) async {
    final rows = await supabase
        .from('areas')
        .select()
        .eq('city_id', cityId)
        .eq('is_active', true)
        .order('sort_order');
    return (rows as List).map((r) => SArea.fromJson(r as Map<String, dynamic>)).toList();
  }

  static Future<List<SNeighborhood>> fetchNeighborhoods(int areaId) async {
    final rows = await supabase
        .from('neighborhoods')
        .select()
        .eq('area_id', areaId)
        .eq('is_active', true)
        .order('sort_order');
    return (rows as List).map((r) => SNeighborhood.fromJson(r as Map<String, dynamic>)).toList();
  }
}
