import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import '../main.dart';

/// تسجيل/تحديث توكن FCM بجدول device_tokens — بس لمستخدم مسجّل دخول (نفس
/// شرط notifications نفسها). بدون طلب إذن أو تسجيل توكن لمستخدم مجهول.
class PushRepo {
  /// فشل تسجيل الإشعارات ما لازم يوقف التطبيق أبداً — صفر اتصال فعلي أثناء
  /// الاختبارات (flutter test ما بيشغّل main()/Firebase.initializeApp)،
  /// وبيئات حقيقية بدون Google Play Services ممكن ترفض FCM بهدوء.
  static Future<void> registerIfLoggedIn() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _upsertToken(token);

      FirebaseMessaging.instance.onTokenRefresh.listen(_upsertToken);
    } catch (_) {
      // تجاهل — تسجيل توكن الإشعارات اختياري، ما بيأثّر على باقي التطبيق.
    }
  }

  static Future<void> _upsertToken(String token) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase.from('device_tokens').upsert(
      {
        'account_uid': uid,
        'fcm_token': token,
        'platform': _platformName(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'fcm_token',
    );
  }

  static String _platformName() {
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }
}
