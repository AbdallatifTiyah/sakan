import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'supabase_config.dart';
import 'data/push_repo.dart';
import 'screens/home_screen.dart';

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
    return MaterialApp(
      title: 'سكنّا',
      debugShowCheckedModeBanner: false,
      theme: buildSakannaTheme(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}
