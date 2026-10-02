import 'package:flutter/material.dart';
import '../theme.dart';

/// العنصر المميّز لسكنّا — دوائر متّحدة المركز بجانب الموقع، بدل أي دبوس دقيق.
/// يحوّل قاعدة ١٩ (ممنوع موقع دقيق) لعنصر ثقة مرئي بدل قيد مخفي. شوف DESIGN.md.
class ApproxRadiusBadge extends StatelessWidget {
  final bool compact;
  const ApproxRadiusBadge({super.key, this.compact = false});

  void _showExplainer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SRadius.lg)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ConcentricIcon(size: 40, color: SColors.blue600),
            const SizedBox(height: 16),
            const Text(
              'نطاق تقريبي ٣٠٠-٥٠٠م',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SColors.navy),
            ),
            const SizedBox(height: 8),
            const Text(
              'العنوان الدقيق بيعطيه المندوب وقت ترتيب الزيارة — لحماية خصوصية الساكن الحالي.',
              style: TextStyle(fontSize: 15, color: SColors.mut, height: 1.6),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showExplainer(context),
      borderRadius: BorderRadius.circular(SRadius.pill),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
        decoration: BoxDecoration(
          color: SColors.blue100,
          borderRadius: BorderRadius.circular(SRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ConcentricIcon(size: compact ? 14 : 16, color: SColors.blue600),
            const SizedBox(width: 5),
            Text(
              'ضمن ٣٠٠-٥٠٠م',
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: SColors.blue700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConcentricIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _ConcentricIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ConcentricPainter(color)),
    );
  }
}

class _ConcentricPainter extends CustomPainter {
  final Color color;
  _ConcentricPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintRing = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09;
    final paintDot = Paint()..color = color;

    canvas.drawCircle(center, size.width * 0.46, paintRing);
    canvas.drawCircle(center, size.width * 0.28, paintRing);
    canvas.drawCircle(center, size.width * 0.12, paintDot);
  }

  @override
  bool shouldRepaint(covariant _ConcentricPainter oldDelegate) => oldDelegate.color != color;
}
