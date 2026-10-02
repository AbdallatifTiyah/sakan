import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class AccountRepo {
  static Future<void> signUp(String email, String password) async {
    await supabase.auth.signUp(email: email, password: password);
  }

  static Future<void> signIn(String email, String password) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() => supabase.auth.signOut();

  static Session? get session => supabase.auth.currentSession;

  static Future<List<dynamic>> myProfile() async {
    final res = await supabase.rpc('my_profile');
    return res as List<dynamic>;
  }

  static bool get isLoggedIn => supabase.auth.currentSession != null;

  /// بروفايل مسجَّل بصفة [role] على الحساب الحالي، أو null لو ما في. يُستخدم
  /// لتفادي سؤال المستخدم عن اسمه ورقمه من جديد وهو مسجّل دخول أصلاً
  /// (قاعدة "الحساب اختياري وإضافي" — صفر طلب تسجيل، بس ما لازم نكرر سؤال
  /// معلومات موجودة أصلاً بالحساب).
  static Future<Map<String, dynamic>?> findProfile(String role) async {
    if (!isLoggedIn) return null;
    final profiles = await myProfile();
    for (final p in profiles) {
      if (p is Map && p['role'] == role) return p.cast<String, dynamic>();
    }
    return null;
  }

  static Future<void> linkRole({
    required String role,
    required String name,
    required String phone,
  }) async {
    await supabase.rpc('link_account_role', params: {
      'p_role': role,
      'p_name': name,
      'p_phone': phone,
    });
  }

  static Future<Map<String, dynamic>> ownerDashboard() async {
    final res = await supabase.rpc('my_owner_dashboard');
    return res as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> seekerDashboard() async {
    final res = await supabase.rpc('my_seeker_dashboard');
    return res as Map<String, dynamic>;
  }

  /// حذف الحساب بالكامل عبر Edge Function — إلزامي لـApple. service_role
  /// يضل بأسرار Supabase، ما بيطلع للتطبيق أبداً (قاعدة ٥).
  static Future<void> deleteAccount() async {
    final response = await supabase.functions.invoke('delete-account');
    if (response.status != 200) {
      final error = (response.data is Map) ? response.data['error'] : null;
      throw Exception(error ?? 'تعذّر حذف الحساب');
    }
  }
}
