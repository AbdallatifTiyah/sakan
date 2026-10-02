import 'package:flutter/material.dart';
import '../theme.dart';
import '../mock_data.dart';
import '../widgets/mock_photo.dart';
import '../widgets/verification_ribbon.dart';
import '../widgets/approx_radius_badge.dart';
import 'listing_detail_screen.dart';
import 'add_listing_step1_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCity = 'الكل';
  final _cities = const ['الكل', 'رام الله', 'البيرة', 'بيرزيت'];

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final filtered = _selectedCity == 'الكل'
        ? mockListings
        : mockListings.where((l) => l.city == _selectedCity).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apartment_rounded, color: SColors.blue600),
            const SizedBox(width: 8),
            Text('سكنّا',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: SColors.blue700,
                )),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: () {},
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: SColors.card,
                        borderRadius: BorderRadius.circular(SRadius.pill),
                        border: Border.all(color: SColors.line),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search, color: SColors.mut, size: 20),
                          SizedBox(width: 8),
                          Text('ابحث بالمنطقة', style: TextStyle(color: SColors.mut)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _cities.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final city = _cities[i];
                  final selected = city == _selectedCity;
                  return ChoiceChip(
                    label: Text(city),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedCity = city),
                    selectedColor: SColors.blue600,
                    backgroundColor: SColors.card,
                    side: BorderSide(color: selected ? SColors.blue600 : SColors.line),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : SColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SRadius.pill),
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'شقق متاحة للعائلات',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SColors.navy),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(onReset: () => setState(() => _selectedCity = 'الكل'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final listing = filtered[i];
                        final card = _ListingCard(
                          listing: listing,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ListingDetailScreen()),
                          ),
                        );
                        if (reduceMotion) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: card,
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(milliseconds: 250 + i * 40),
                            curve: Curves.easeOut,
                            builder: (context, t, child) => Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(0, (1 - t) * 16),
                                child: child,
                              ),
                            ),
                            child: card,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SColors.amber,
        foregroundColor: SColors.navy,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddListingStep1Screen()),
        ),
        icon: const Icon(Icons.add_home_rounded),
        label: const Text('أضف شقتك', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final MockListing listing;
  final VoidCallback onTap;
  const _ListingCard({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SColors.card,
      borderRadius: BorderRadius.circular(SRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(SRadius.md),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SRadius.md),
            border: Border.all(color: SColors.line),
            boxShadow: sShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  MockPhoto(
                    height: 160,
                    radius: const BorderRadius.vertical(top: Radius.circular(SRadius.md)),
                  ),
                  if (listing.verification != SVerification.none)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: VerificationRibbon(
                        level: listing.verification,
                        date: listing.verifiedDate,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: SColors.navy),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${listing.price} ${listing.currencySymbol} / شهر',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: SColors.blue700,
                          ),
                        ),
                        const Spacer(),
                        Text('${listing.area} · ${listing.city}',
                            style: const TextStyle(color: SColors.mut, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _MiniStat(icon: Icons.bed_outlined, text: '${listing.rooms} غرف'),
                        const SizedBox(width: 12),
                        _MiniStat(
                          icon: Icons.checkroom_outlined,
                          text: listing.furnished ? 'مفروشة' : 'غير مفروشة',
                        ),
                        const Spacer(),
                        const ApproxRadiusBadge(compact: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniStat({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: SColors.mut),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: SColors.mut, fontSize: 12)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onReset;
  const _EmptyState({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: SColors.mut),
            const SizedBox(height: 16),
            const Text(
              'ما في شقق تطابق بحثك الآن',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: SColors.navy),
            ),
            const SizedBox(height: 6),
            const Text(
              'جرّب توسيع المنطقة أو تغيير الفلاتر.',
              textAlign: TextAlign.center,
              style: TextStyle(color: SColors.mut),
            ),
            const SizedBox(height: 16),
            SSecondaryButton(label: 'عرض كل الشقق', onPressed: onReset),
          ],
        ),
      ),
    );
  }
}
