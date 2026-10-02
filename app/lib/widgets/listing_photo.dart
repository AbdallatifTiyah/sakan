import 'package:flutter/material.dart';
import '../theme.dart';

/// صورة إعلان حقيقية (رابط Supabase Storage) — بديل شكلي هادئ لو الرابط
/// غايب أو فشل التحميل، بدل أيقونة كسر صورة افتراضية مخيفة.
class ListingPhoto extends StatelessWidget {
  final String? url;
  final double? height;
  final BorderRadius? radius;
  const ListingPhoto({super.key, required this.url, this.height, this.radius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.zero,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: url == null || url!.isEmpty
            ? const _Placeholder()
            : Image.network(
                url!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const _Placeholder(loading: true);
                },
                errorBuilder: (context, error, stack) => const _Placeholder(),
              ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final bool loading;
  const _Placeholder({this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [SColors.blue100, Color(0xFFD9E2FF)],
        ),
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: SColors.blue500),
              )
            : const Icon(Icons.home_rounded, size: 40, color: SColors.blue500),
      ),
    );
  }
}
