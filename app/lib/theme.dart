import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// توكنز سكنّا — نسخة طبق الأصل من CLAUDE.md (محور مقفول بالبريف، لا اجتهاد هون).
class SColors {
  static const blue700 = Color(0xFF12309B);
  static const blue600 = Color(0xFF1E45D6);
  static const blue500 = Color(0xFF3A63F0);
  static const blue100 = Color(0xFFE4EAFF);
  static const blue050 = Color(0xFFF2F5FF);
  static const amber = Color(0xFFF5A524);
  static const amberInk = Color(0xFF9A5B00);
  static const navy = Color(0xFF080F2E);
  static const mut = Color(0xFF6B748F);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE1E6F5);
  static const ok = Color(0xFF12A150);
  static const warn = Color(0xFFC2410C);
  static const danger = Color(0xFFDC2626);
}

class SRadius {
  static const sm = 8.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const pill = 999.0;
}

/// ظل واحد معتمد بكل الواجهة — بدون تكديس أو تدرّج.
final sShadow = [
  BoxShadow(
    color: SColors.navy.withValues(alpha: 0.10),
    blurRadius: 30,
    offset: const Offset(0, 10),
  ),
];

ThemeData buildSakannaTheme() {
  final base = GoogleFonts.ibmPlexSansArabicTextTheme();
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: SColors.blue050,
    colorScheme: ColorScheme.fromSeed(
      seedColor: SColors.blue600,
      primary: SColors.blue600,
      secondary: SColors.amber,
      error: SColors.danger,
      surface: SColors.card,
    ),
    textTheme: base.apply(
      bodyColor: SColors.navy,
      displayColor: SColors.navy,
    ),
    fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
    appBarTheme: const AppBarTheme(
      backgroundColor: SColors.blue050,
      foregroundColor: SColors.navy,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: SColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SRadius.md),
        side: const BorderSide(color: SColors.line),
      ),
    ),
    dividerTheme: const DividerThemeData(color: SColors.line, thickness: 1),
  );
}

/// زر أساسي كهرماني — واحد بكل شاشة (قاعدة الزر الكهرماني بـCLAUDE.md).
class SPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const SPrimaryButton({super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: SColors.amber,
          foregroundColor: SColors.navy,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SRadius.sm),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/// زر ثانوي أزرق — لأي إجراء إضافي بنفس الشاشة.
class SSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const SSecondaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: SColors.blue600,
          side: const BorderSide(color: SColors.blue600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SRadius.sm),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
