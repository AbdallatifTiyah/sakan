import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/owner_repo.dart';
import '../widgets/status_timeline.dart';

String? _fmtDate(dynamic iso) {
  if (iso == null) return null;
  final d = DateTime.tryParse(iso.toString());
  if (d == null) return null;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// تتبّع حالة إعلان من بروفايل المالك — أربع مراحل حرفية (إرسال/نشر/تأكيد
/// هاتفي/توثيق ميداني) من حقول my_owner_dashboard الموجودة أصلاً، صفر منطق
/// جديد. التوثيق بالفيديو (لو موجود) بادج إضافي تحت الشريط، مش داخله —
/// قاعدة ٢٤ (نص التوثيق لازم يطابق الطريقة الفعلية بالحرف).
class ListingTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> listing;
  const ListingTrackingScreen({super.key, required this.listing});

  @override
  State<ListingTrackingScreen> createState() => _ListingTrackingScreenState();
}

class _ListingTrackingScreenState extends State<ListingTrackingScreen> {
  late Map<String, dynamic> _l = widget.listing;
  bool _requesting = false;

  Future<void> _confirmDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SRadius.md)),
        title: const Text('طلب حذف الإعلان'),
        content: const Text('بيراجع الطاقم طلبك ويحذف الإعلان نهائياً. ما بيصير حذف فوري.'),
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
      await OwnerRepo.requestListingDeletion(_l['id'] as String);
      if (!mounted) return;
      setState(() {
        _l = {..._l, 'deletion_requested_at': DateTime.now().toIso8601String()};
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
    final status = _l['status'] as String?;
    final isRejected = status == 'rejected';
    final published = _l['published_at'] != null;
    final outreach = _l['outreach_status'] as String?;
    final confirmedByPhone = outreach == 'confirmed';
    final verification = _l['verification'] as String?;
    final fieldVerified = verification == 'field';
    final videoVerified = verification == 'video';
    final deletionRequestedAt = _l['deletion_requested_at'];

    final stages = [
      const StatusStage(label: 'تم الإرسال', reached: true),
      StatusStage(label: isRejected ? 'رُفض الإعلان' : 'تم النشر', reached: published || isRejected, dateText: _fmtDate(_l['published_at'])),
      StatusStage(label: 'تم التأكيد هاتفياً', reached: confirmedByPhone),
      StatusStage(label: 'تم التوثيق ميدانياً', reached: fieldVerified, dateText: _fmtDate(_l['visit_date'])),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_l['title'] as String? ?? 'تتبّع الإعلان')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(_l['ref'] as String? ?? '', style: const TextStyle(color: SColors.mut, fontSize: 13)),
            const SizedBox(height: 20),
            StatusTimeline(stages: stages),
            if (isRejected && (_l['reject_reason'] as String?)?.isNotEmpty == true) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: SColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(SRadius.md)),
                child: Text('سبب الرفض: ${_l['reject_reason']}', style: const TextStyle(color: SColors.danger)),
              ),
              const SizedBox(height: 20),
            ],
            if (videoVerified) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: SColors.blue050, borderRadius: BorderRadius.circular(SRadius.md)),
                child: Text(
                  'موثّق بمكالمة فيديو — ${_fmtDate(_l['video_verified_at']) ?? ""}',
                  style: const TextStyle(color: SColors.blue700, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),
            ],
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
                label: _requesting ? 'جارٍ الإرسال...' : 'اطلب حذف الإعلان',
                onPressed: _requesting ? null : _confirmDeletion,
              ),
          ],
        ),
      ),
    );
  }
}
