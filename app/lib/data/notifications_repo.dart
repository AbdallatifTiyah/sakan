import '../main.dart';

/// قراءة/تعليم الإشعارات مباشرة عبر REST بجلسة المستخدم — مقصود ومطابق
/// للقاعدة الموثّقة (notifications محمية بالكامل بـRLS self_read/self_update
/// بلا أي منطق عمل، فمسار REST المباشر سليم عمداً، بعكس بقية العمليات
/// اللي تمرّ حصراً عبر RPC).
class NotificationsRepo {
  static bool get isLoggedIn => supabase.auth.currentSession != null;

  static Future<List<Map<String, dynamic>>> fetch({int limit = 50}) async {
    if (!isLoggedIn) return [];
    final rows = await supabase
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => (r as Map).cast<String, dynamic>()).toList();
  }

  static Future<void> markRead(String id) async {
    await supabase.from('notifications').update({'is_read': true}).eq('id', id);
  }

  static Future<int> unreadCount() async {
    if (!isLoggedIn) return 0;
    final rows = await supabase.from('notifications').select('id').eq('is_read', false);
    return (rows as List).length;
  }
}
