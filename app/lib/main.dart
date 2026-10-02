import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme.dart';
import 'supabase_config.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: sSupabaseUrl, publishableKey: sSupabaseAnonKey);
  runApp(const SakannaApp());
}

final supabase = Supabase.instance.client;

class SakannaApp extends StatelessWidget {
  const SakannaApp({super.key});

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
