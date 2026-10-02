import 'package:flutter/material.dart';
import '../theme.dart';

enum SVerification { none, desk, video, field }

/// نفس منطق verifBadge() بـindex.html (قاعدة ٢٤) — دالة وحدة، لا تكرار.
/// none/desk: بدون شريط إطلاقاً. video/field: نص + تاريخ إلزاميان.
class VerificationRibbon extends StatefulWidget {
  final SVerification level;
  final DateTime? date;
  final bool playEntranceAnimation;

  const VerificationRibbon({
    super.key,
    required this.level,
    required this.date,
    this.playEntranceAnimation = false,
  });

  @override
  State<VerificationRibbon> createState() => _VerificationRibbonState();
}

class _VerificationRibbonState extends State<VerificationRibbon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    // WidgetsBinding.platformDispatcher بدل MediaQuery.of(context) لأن initState()
    // بيصير قبل أول build — استدعاء MediaQuery.of هون بيرمي خطأ "called before initState completed".
    final reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (widget.playEntranceAnimation && !reduceMotion) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _c.forward());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    const months = [
      'كانون ثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران',
      'تموز', 'آب', 'أيلول', 'تشرين أول', 'تشرين ثاني', 'كانون أول',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.level == SVerification.none) {
      return const SizedBox.shrink();
    }
    final isField = widget.level == SVerification.field;
    final isDesk = widget.level == SVerification.desk;
    // نص desk طبق الأصل عن VER.desk بـindex.html — شارة قديمة بلا تاريخ لصفوف
    // تاريخية فقط (صفر صفوف desk حالياً بالقاعدة الحية، تحقّق ٢٠٢٦-١٠-٠٢).
    final label = isField
        ? 'موثّق بزيارة ميدانية'
        : isDesk
            ? '✓ موثّق هاتفياً'
            : 'موثّق بمكالمة فيديو';
    final dateStr = !isDesk && widget.date != null ? ' — ${_formatDate(widget.date!)}' : '';

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isField ? SColors.amber : Colors.transparent,
        border: isField ? null : Border.all(color: SColors.blue600, width: 1.5),
        borderRadius: BorderRadius.circular(SRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isField
                ? Icons.check_circle
                : isDesk
                    ? Icons.phone_outlined
                    : Icons.play_circle_outline,
            size: 18,
            color: isField ? SColors.amberInk : SColors.blue600,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label$dateStr',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isField ? SColors.amberInk : SColors.blue600,
              ),
            ),
          ),
        ],
      ),
    );

    if (!widget.playEntranceAnimation) return content;

    return ClipRRect(
      borderRadius: BorderRadius.circular(SRadius.sm),
      child: Stack(
        children: [
          content,
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                return FractionallySizedBox(
                  alignment: Alignment((_c.value * 4) - 2, 0),
                  widthFactor: 0.35,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.45),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
