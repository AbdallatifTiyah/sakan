import 'package:flutter/material.dart';
import '../theme.dart';
import '../app_lang.dart';
import 'account_screen.dart';

/// شاشة الإعدادات — وجهة ثالثة بالشريط السفلي (بند ١٣). تضم خيار اللغة
/// (بند ١١: البنية والحفظ المحلي الآن، ترجمة باقي شاشات التطبيق لجلسة
/// لاحقة بقرار أبواللطيف) والدخول لـ"حسابي".
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: sAppLang,
      builder: (context, lang, _) {
        return Scaffold(
          appBar: AppBar(title: Text(tt('الإعدادات', 'Settings'))),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionLabel(tt('اللغة', 'Language')),
                Container(
                  decoration: BoxDecoration(
                    color: SColors.card,
                    borderRadius: BorderRadius.circular(SRadius.md),
                    border: Border.all(color: SColors.line),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _LangOption(
                          label: 'العربية',
                          selected: lang == AppLang.ar,
                          onTap: () => sAppLang.setLang(AppLang.ar),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LangOption(
                          label: 'English',
                          selected: lang == AppLang.en,
                          onTap: () => sAppLang.setLang(AppLang.en),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    tt(
                      'الإعدادات الجديدة ثنائية اللغة. بقية شاشات التطبيق لسا عربي فقط — الترجمة الكاملة قريباً.',
                      'New screens like this one support both languages. The rest of the app is still Arabic-only — full translation is coming.',
                    ),
                    style: const TextStyle(color: SColors.mut, fontSize: 12, height: 1.6),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionLabel(tt('الحساب', 'Account')),
                _SettingsTile(
                  icon: Icons.account_circle_outlined,
                  title: tt('حسابي', 'My account'),
                  subtitle: tt('تسجيل الدخول، إعلاناتي، طلباتي، إشعاراتي', 'Sign in, my listings, my requests, my notifications'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
                ),
                const SizedBox(height: 24),
                _SectionLabel(tt('عن التطبيق', 'About')),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: tt('سكنّا', 'Sakanna'),
                  subtitle: tt(
                    'منصة تأجير غرف وسكن مشترك موثّق في رام الله والبيرة وبيرزيت.',
                    'A verified room and shared-housing rental platform in Ramallah, Al-Bireh and Birzeit.',
                  ),
                  onTap: null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: SColors.navy, fontSize: 14)),
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SRadius.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? SColors.blue600 : SColors.blue050,
          borderRadius: BorderRadius.circular(SRadius.sm),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : SColors.navy,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SColors.card,
      borderRadius: BorderRadius.circular(SRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(SRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SRadius.md),
            border: Border.all(color: SColors.line),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: SColors.blue050, borderRadius: BorderRadius.circular(SRadius.sm)),
                child: Icon(icon, color: SColors.blue600, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: SColors.mut, fontSize: 12, height: 1.5)),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_left, color: SColors.mut, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
