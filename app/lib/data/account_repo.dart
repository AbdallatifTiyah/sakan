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
