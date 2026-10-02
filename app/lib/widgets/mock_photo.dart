import 'package:flutter/material.dart';
import '../theme.dart';

/// بديل بصري لصورة حقيقية بمرحلة الشاشات التجريبية — صفر اتصال بالقاعدة
/// أو الشبكة بهالمرحلة. بيوضع مكان Image.network(images[i]) لاحقاً حرفياً.
class MockPhoto extends StatelessWidget {
  final double? height;
  final BorderRadius? radius;
  const MockPhoto({super.key, this.height, this.radius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.zero,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [SColors.blue100, Color(0xFFD9E2FF)],
          ),
        ),
        child: const Center(
          child: Icon(Icons.home_rounded, size: 40, color: SColors.blue500),
        ),
      ),
    );
  }
}
