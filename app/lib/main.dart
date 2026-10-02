import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'supabase_config.dart';
import 'app_lang.dart';
import 'data/push_repo.dart';
import 'screens/root_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(url: sSupabaseUrl, publishableKey: sSupabaseAnonKey);
  runApp(const SakannaApp());
}

final supabase = Supabase.instance.client;

class SakannaApp extends StatefulWidget {
  const SakannaApp({super.key});

  @override
  State<SakannaApp> createState() => _SakannaAppState();
}

class _SakannaAppState extends State<SakannaApp> {
  @override
  void initState() {
    super.initState();
    // تسجيل فوري لو في جلسة محفوظة أصلاً، وعند كل دخول/تسجيل جديد. بدون try
    // هون، اختبار الواجهة (flutter test) بيفشل لأنه ما بيشغّل main()/Supabase.initialize.
    try {
      PushRepo.registerIfLoggedIn();
      supabase.auth.onAuthStateChange.listen((event) {
        if (event.event == AuthChangeEvent.signedIn) {
          PushRepo.registerIfLoggedIn();
        }
      });
    } catch (_) {
      // تجاهل — نفس سبب try/catch بـPushRepo.registerIfLoggedIn().
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: sAppLang,
      builder: (context, lang, _) {
        return MaterialApp(
          title: 'سكنّا',
          debugShowCheckedModeBanner: false,
          theme: buildSakannaTheme(),
          // locale بس — يبدّل نصوص الودجت الجاهزة (منتقي التاريخ، إلخ) فقط.
          // الاتجاه (Directionality تحت) يبقى RTL ثابت بغض النظر عن اللغة:
          // معظم شاشات التطبيق لسا عربي غير مترجم (قرار مؤجّل، بند ١١)، وعكس
          // اتجاه الصفحة كاملة فوق محتوى عربي غير مترجم يكسرها بصرياً —
          // بعكس الموقع (index.html) اللي كل نصه مترجم فعلاً فيصح عكس اتجاهه.
          locale: Locale(lang == AppLang.en ? 'en' : 'ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          home: const RootShell(),
        );
      },
    );
  }
}
