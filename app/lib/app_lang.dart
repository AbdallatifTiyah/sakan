import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// بنية اللغة — بند ١١ (مرحلة ٢): مفتاح الاختيار والحفظ المحلي جاهزان الآن،
/// الترجمة الكاملة لكل شاشات التطبيق مؤجّلة لجلسة لاحقة (قرار أبواللطيف).
/// الشاشات الجديدة هالجلسة (الإعدادات/الباحثين/الشريط السفلي) ثنائية اللغة
/// فعلياً عبر [tt] — إثبات إن التبديل شغّال، مش مجرد زر بلا أثر.
enum AppLang { ar, en }

const _prefsKey = 'sakanna_app_lang';

class AppLangController extends ValueNotifier<AppLang> {
  AppLangController() : super(AppLang.ar) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved == 'en') value = AppLang.en;
    } catch (_) {
      // التخزين المحلي اختياري — فشل القراءة ما بيعطّل التطبيق (نفس مبدأ
      // التسامح مع فشل التخزين المحلي بـindex.html).
    }
  }

  Future<void> setLang(AppLang lang) async {
    value = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, lang == AppLang.en ? 'en' : 'ar');
    } catch (_) {
      // تجاهل — نفس سبب try/catch بـ_load().
    }
  }
}

final sAppLang = AppLangController();

/// نفس مبدأ tt(ar, en) بـindex.html حرفياً — نص جنب نص وقت الاستخدام، بدون
/// قاموس مركزي. يُستخدم فقط بالشاشات المُترجمة فعلياً هالجلسة.
String tt(String ar, String en) => sAppLang.value == AppLang.en ? en : ar;
