import 'package:flutter/material.dart';
import '../theme.dart';

class StatusStage {
  final String label;
  final bool reached;
  final String? dateText;
  const StatusStage({required this.label, required this.reached, this.dateText});
}

/// شريط تتبّع عمودي — مرحلة فوق مرحلة، كل وحدة محقَّقة (أزرق) أو لسا
/// بالانتظار (رمادي). يعرض حالة إعلان أو طلب باحث فعلية من القاعدة، صفر
/// منطق جديد — القيم جاهزة من my_owner_dashboard/my_seeker_dashboard.
class StatusTimeline extends StatelessWidget {
  final List<StatusStage> stages;
  const StatusTimeline({super.key, required this.stages});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stages.length; i++) _StageRow(stage: stages[i], isLast: i == stages.length - 1),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  final StatusStage stage;
  final bool isLast;
  const _StageRow({required this.stage, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = stage.reached ? SColors.blue600 : SColors.line;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stage.reached ? SColors.blue600 : Colors.white,
                  border: Border.all(color: color, width: 2),
                ),
                child: stage.reached
                    ? const Icon(Icons.check, size: 10, color: Colors.white)
                    : null,
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: color)),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stage.label,
                  style: TextStyle(
                    fontWeight: stage.reached ? FontWeight.bold : FontWeight.w500,
                    color: stage.reached ? SColors.navy : SColors.mut,
                  ),
                ),
                if (stage.dateText != null) ...[
                  const SizedBox(height: 2),
                  Text(stage.dateText!, style: const TextStyle(color: SColors.mut, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
