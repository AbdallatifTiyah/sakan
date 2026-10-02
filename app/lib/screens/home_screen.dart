import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/listing.dart';
import '../data/listings_repo.dart';
import '../data/locations_repo.dart';
import '../widgets/listing_photo.dart';
import '../widgets/verification_ribbon.dart';
import '../widgets/approx_radius_badge.dart';
import 'listing_detail_screen.dart';
import 'add_listing_flow.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<SCity> _cities = [];
  SCity? _selectedCity;
  List<Listing> _listings = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        LocationsRepo.fetchCities(),
        ListingsRepo.fetchListings(
          citySlug: _selectedCity?.slug,
          search: _searchCtrl.text,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _cities = results[0] as List<SCity>;
        _listings = results[1] as List<Listing>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل البيانات. تأكد من الاتصال وحاول مرة ثانية.';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

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
        child: RefreshIndicator(
          onRefresh: _load,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'ابحث بالمنطقة',
                    prefixIcon: const Icon(Icons.search, color: SColors.mut, size: 20),
                    filled: true,
                    fillColor: SColors.card,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SRadius.pill),
                      borderSide: const BorderSide(color: SColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(SRadius.pill),
                      borderSide: const BorderSide(color: SColors.line),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _CityChip(
                      label: 'الكل',
                      selected: _selectedCity == null,
                      onTap: () {
                        setState(() => _selectedCity = null);
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                    for (final c in _cities) ...[
                      _CityChip(
                        label: c.nameAr,
                        selected: _selectedCity?.id == c.id,
                        onTap: () {
                          setState(() => _selectedCity = c);
                          _load();
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
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
              Expanded(child: _buildBody(reduceMotion)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SColors.amber,
        foregroundColor: SColors.navy,
        onPressed: () async {
          final posted = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AddListingFlow()),
          );
          if (posted == true) _load();
        },
        icon: const Icon(Icons.add_home_rounded),
        label: const Text('أضف شقتك', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildBody(bool reduceMotion) {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: 3,
        itemBuilder: (context, i) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _CardSkeleton(),
        ),
      );
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    if (_listings.isEmpty) {
      return _EmptyState(
        onReset: () {
          setState(() {
            _selectedCity = null;
            _searchCtrl.clear();
          });
          _load();
        },
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _listings.length,
      itemBuilder: (context, i) {
        final listing = _listings[i];
        final card = _ListingCard(
          listing: listing,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: listing.id)),
          ),
        );
        if (reduceMotion) {
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: card);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 250 + i * 40),
            curve: Curves.easeOut,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: child),
            ),
            child: card,
          ),
        );
      },
    );
  }
}

class _CityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CityChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: SColors.blue600,
      backgroundColor: SColors.card,
      side: BorderSide(color: selected ? SColors.blue600 : SColors.line),
      labelStyle: TextStyle(
        color: selected ? Colors.white : SColors.navy,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SRadius.pill)),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Listing listing;
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
                  ListingPhoto(
                    url: listing.images.isNotEmpty ? listing.images.first : null,
                    height: 160,
                    radius: const BorderRadius.vertical(top: Radius.circular(SRadius.md)),
                  ),
                  if (listing.verification != SVerification.none)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: VerificationRibbon(level: listing.verification, date: listing.verifiedAt),
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
                          '${listing.price.toStringAsFixed(0)} ${listing.currencySymbol} / ${listing.rentalPeriodLabel}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: SColors.blue700),
                        ),
                        const Spacer(),
                        Text('${listing.area} · ${listing.city}',
                            style: const TextStyle(color: SColors.mut, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (listing.roomsTotal != null)
                          _MiniStat(icon: Icons.bed_outlined, text: '${listing.roomsTotal} غرف'),
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

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SColors.card,
        borderRadius: BorderRadius.circular(SRadius.md),
        border: Border.all(color: SColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            decoration: const BoxDecoration(
              color: SColors.blue050,
              borderRadius: BorderRadius.vertical(top: Radius.circular(SRadius.md)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 180, color: SColors.blue050),
                const SizedBox(height: 10),
                Container(height: 14, width: 100, color: SColors.blue050),
              ],
            ),
          ),
        ],
      ),
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

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: SColors.mut),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: SColors.mut)),
            const SizedBox(height: 16),
            SSecondaryButton(label: 'إعادة المحاولة', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
