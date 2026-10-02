import 'package:flutter/material.dart';
import '../theme.dart';
import '../mock_data.dart';
import '../features.dart';
import '../widgets/mock_photo.dart';
import '../widgets/verification_ribbon.dart';
import '../widgets/approx_radius_badge.dart';

class ListingDetailScreen extends StatelessWidget {
  const ListingDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final listing = mockListingDetail;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: SColors.blue050,
            expandedHeight: 260,
            leading: _CircleIconButton(icon: Icons.arrow_forward, onTap: () => Navigator.pop(context)),
            actions: [
              _CircleIconButton(icon: Icons.share_outlined, onTap: () {}),
              const SizedBox(width: 8),
              _CircleIconButton(icon: Icons.favorite_border, onTap: () {}),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  const MockPhoto(),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(SRadius.pill),
                      ),
                      // Directionality صريحة: "1 / 2" سلسلة أرقام ضعيفة الاتجاه،
                      // والفقرة المحيطة RTL بتعكس ترتيبها البصري بدون هالإجبار.
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '1 / ${listing.images.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: SColors.navy, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${listing.price} ${listing.currencySymbol} / شهر',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SColors.blue700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: SColors.mut),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${listing.area}، ${listing.city}'
                          '${listing.landmark != null ? " — ${listing.landmark}" : ""}',
                          style: const TextStyle(color: SColors.mut),
                        ),
                      ),
                      const ApproxRadiusBadge(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (listing.verification != SVerification.none)
                    VerificationRibbon(
                      level: listing.verification,
                      date: listing.verifiedDate,
                      playEntranceAnimation: true,
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _StatBox(icon: Icons.bed_outlined, label: 'الغرف', value: '${listing.rooms}'),
                      const SizedBox(width: 12),
                      _StatBox(
                        icon: Icons.checkroom_outlined,
                        label: 'الفرش',
                        value: listing.furnished ? 'مفروشة' : 'غير مفروشة',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('الفواتير', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: SColors.navy)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _BillChip(label: 'ماء', included: listing.billsWater),
                      _BillChip(label: 'كهرباء', included: listing.billsElectricity),
                      _BillChip(label: 'إنترنت', included: listing.billsInternet),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('المواصفات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: SColors.navy)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: listing.features
                        .map((f) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: SColors.blue050,
                                borderRadius: BorderRadius.circular(SRadius.sm),
                                border: Border.all(color: SColors.line),
                              ),
                              child: Text(featureLabel(f), style: const TextStyle(fontSize: 13, color: SColors.navy)),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SPrimaryButton(
            label: 'أرسل طلب التواصل',
            icon: Icons.chat_bubble_outline,
            onPressed: () {},
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: CircleAvatar(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        child: IconButton(icon: Icon(icon, size: 20, color: SColors.navy), onPressed: onTap),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatBox({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SColors.card,
          borderRadius: BorderRadius.circular(SRadius.md),
          border: Border.all(color: SColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: SColors.blue600, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
            Text(label, style: const TextStyle(color: SColors.mut, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _BillChip extends StatelessWidget {
  final String label;
  final bool included;
  const _BillChip({required this.label, required this.included});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: included ? SColors.ok.withValues(alpha: 0.1) : SColors.blue050,
        borderRadius: BorderRadius.circular(SRadius.sm),
        border: Border.all(color: included ? SColors.ok.withValues(alpha: 0.4) : SColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            included ? Icons.check_circle : Icons.cancel_outlined,
            size: 16,
            color: included ? SColors.ok : SColors.mut,
          ),
          const SizedBox(width: 6),
          Text(
            included ? '$label شامل' : '$label غير شامل',
            style: TextStyle(fontSize: 13, color: included ? SColors.ok : SColors.mut),
          ),
        ],
      ),
    );
  }
}
