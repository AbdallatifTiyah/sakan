import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/seeker_repo.dart';
import '../widgets/status_timeline.dart';

/// تتبّع حالة طلب بحث من بروفايل الباحث — ثلاث مراحل (ما في توثيق ميداني
/// لطلب باحث، بعكس الإعلان). من حقول my_seeker_dashboard الموجودة أصلاً.
class RequestTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> request;
  const RequestTrackingScreen({super.key, required this.request});

  @override
  State<RequestTrackingScreen> createState() => _RequestTrackingScreenState();
}

class _RequestTrackingScreenState extends State<RequestTrackingScreen> {
  late Map<String, dynamic> _r = widget.request;
  bool _requesting = false;

  Future<void> _confirmDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SRadius.md)),
        title: const Text('طلب حذف طلب البحث'),
        content: const Text('بيراجع الطاقم طلبك ويحذفه نهائياً. ما بيصير حذف فوري.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('أرسل الطلب', style: TextStyle(color: SColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _requesting = true);
    try {
      await SeekerRepo.requestDeletion(_r['id'] as String);
      if (!mounted) return;
      setState(() {
        _r = {..._r, 'deletion_requested_at': DateTime.now().toIso8601String()};
        _requesting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _requesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _r['status'] as String?;
    final outreach = _r['outreach_status'] as String?;
    final stages = [
      const StatusStage(label: 'تم الإرسال', reached: true),
      StatusStage(label: 'تم النشر', reached: status == 'published' || status == 'closed'),
      StatusStage(label: 'تم التأكيد هاتفياً', reached: outreach == 'confirmed'),
    ];
    final deletionRequestedAt = _r['deletion_requested_at'];

    return Scaffold(
      appBar: AppBar(title: const Text('تتبّع طلب البحث')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(_r['ref'] as String? ?? '', style: const TextStyle(color: SColors.mut, fontSize: 13)),
            const SizedBox(height: 20),
            StatusTimeline(stages: stages),
            const Divider(),
            const SizedBox(height: 16),
            if (deletionRequestedAt != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: SColors.blue050, borderRadius: BorderRadius.circular(SRadius.md)),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded, color: SColors.blue600, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('طلب الحذف قيد المراجعة من الطاقم.', style: TextStyle(color: SColors.navy))),
                  ],
                ),
              )
            else
              SSecondaryButton(
                label: _requesting ? 'جارٍ الإرسال...' : 'اطلب حذف الطلب',
                onPressed: _requesting ? null : _confirmDeletion,
              ),
          ],
        ),
      ),
    );
  }
}
