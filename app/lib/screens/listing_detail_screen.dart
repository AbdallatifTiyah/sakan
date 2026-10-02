import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' show Share;
import '../theme.dart';
import '../models/listing.dart';
import '../data/listings_repo.dart';
import '../data/account_repo.dart';
import '../features.dart';
import '../validators.dart';
import '../widgets/listing_photo.dart';
import '../widgets/verification_ribbon.dart';
import '../widgets/approx_radius_badge.dart';

class ListingDetailScreen extends StatefulWidget {
  final String listingId;
  const ListingDetailScreen({super.key, required this.listingId});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  Listing? _listing;
  bool _loading = true;
  String? _error;
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final listing = await ListingsRepo.fetchListingById(widget.listingId);
      if (!mounted) return;
      if (listing == null) {
        setState(() {
          _error = 'هذا الإعلان لم يعد متاحاً.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _listing = listing;
        _loading = false;
      });
      ListingsRepo.bumpView(widget.listingId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل البيانات. تأكد من الاتصال وحاول مرة ثانية.';
        _loading = false;
      });
    }
  }

  /// مسجّل دخول وله بروفايل باحث مكتمل (اسم ورقم)؟ صفر سؤال عن معلومات
  /// موجودة أصلاً بالحساب — تأكيد سريع بدل فورم كامل (قاعدة: ما تطلب معلومات
  /// الشخص وهو مسجّل دخول أصلاً). غير ذلك: نفس الفورم القديم.
  Future<void> _openContactSheet() async {
    final listing = _listing;
    if (listing == null) return;
    final profile = await AccountRepo.findProfile('seeker');
    final name = (profile?['first_name'] as String?)?.trim() ?? '';
    final phone = (profile?['phone'] as String?)?.trim() ?? '';
    if (!mounted) return;
    if (name.isNotEmpty && phone.isNotEmpty) {
      await _confirmContactWithProfile(listing, name, phone);
    } else {
      await _openContactFormSheet(listing);
    }
  }

  Future<void> _confirmContactWithProfile(Listing listing, String name, String phone) async {
    var sending = false;
    String? inlineError;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SRadius.md)),
          title: const Text('اطلب التواصل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'بنوصلك مع المالك باسم "$name" ورقم "$phone".',
                style: const TextStyle(color: SColors.mut, height: 1.6),
              ),
              if (inlineError != null) ...[
                const SizedBox(height: 10),
                Text(inlineError!, style: const TextStyle(color: SColors.danger, fontSize: 13)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: sending
                  ? null
                  : () {
                      Navigator.pop(dialogContext);
                      _openContactFormSheet(listing, initialName: name, initialPhone: phone);
                    },
              child: const Text('تعديل المعلومات'),
            ),
            TextButton(
              onPressed: sending
                  ? null
                  : () async {
                      setDialogState(() {
                        sending = true;
                        inlineError = null;
                      });
                      try {
                        await ListingsRepo.submitContactRequest(listingId: listing.id, name: name, phone: phone);
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم إرسال طلب التواصل')),
                        );
                      } catch (e) {
                        setDialogState(() {
                          sending = false;
                          inlineError = 'تعذّر إرسال الطلب. حاول مرة ثانية.';
                        });
                      }
                    },
              child: Text(sending ? 'جارٍ الإرسال...' : 'أرسل طلب التواصل'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openContactFormSheet(Listing listing, {String? initialName, String? initialPhone}) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: initialName ?? '');
    final phoneCtrl = TextEditingController(text: initialPhone ?? '');
    var sending = false;
    String? inlineError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: SColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SRadius.lg)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اطلب التواصل',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SColors.navy),
                ),
                const SizedBox(height: 6),
                const Text(
                  'بنوصلك مع المالك بأسرع وقت.',
                  style: TextStyle(color: SColors.mut, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'اسمك', border: OutlineInputBorder()),
                  validator: (v) => requiredValidator(v, 'اسمك'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم هاتفك', border: OutlineInputBorder()),
                  validator: phoneValidator,
                ),
                if (inlineError != null) ...[
                  const SizedBox(height: 12),
                  Text(inlineError!, style: const TextStyle(color: SColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                SPrimaryButton(
                  label: sending ? 'جارٍ الإرسال...' : 'أرسل طلب التواصل',
                  onPressed: sending
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) return;
                          setSheetState(() {
                            inlineError = null;
                            sending = true;
                          });
                          try {
                            await ListingsRepo.submitContactRequest(
                              listingId: listing.id,
                              name: nameCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                            );
                            if (!sheetContext.mounted) return;
                            Navigator.pop(sheetContext);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إرسال طلب التواصل')),
                            );
                          } catch (e) {
                            setSheetState(() {
                              sending = false;
                              inlineError = 'تعذّر إرسال الطلب. حاول مرة ثانية.';
                            });
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _listing == null) {
      return Scaffold(
        appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => Navigator.pop(context))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40, color: SColors.mut),
                const SizedBox(height: 12),
                Text(_error ?? '', textAlign: TextAlign.center, style: const TextStyle(color: SColors.mut)),
                const SizedBox(height: 16),
                SSecondaryButton(label: 'إعادة المحاولة', onPressed: _load),
              ],
            ),
          ),
        ),
      );
    }

    final listing = _listing!;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: SColors.blue050,
            expandedHeight: 260,
            leading: _CircleIconButton(icon: Icons.arrow_forward, onTap: () => Navigator.pop(context)),
            actions: [
              _CircleIconButton(
                icon: Icons.share_outlined,
                onTap: () => Share.share('شوف هاد السكن على سكنّا: https://sakanna.ps/?l=${listing.ref}'),
              ),
              const SizedBox(width: 8),
              _CircleIconButton(icon: Icons.favorite_border, onTap: () {}),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: listing.images.isEmpty ? 1 : listing.images.length,
                    onPageChanged: (i) => setState(() => _photoIndex = i),
                    itemBuilder: (context, i) => ListingPhoto(
                      url: listing.images.isNotEmpty ? listing.images[i] : null,
                    ),
                  ),
                  if (listing.images.length > 1)
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(SRadius.pill),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            '${_photoIndex + 1} / ${listing.images.length}',
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
                    '${listing.price.toStringAsFixed(0)} ${listing.currencySymbol} / ${listing.rentalPeriodLabel}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: SColors.blue700),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: SColors.mut),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${listing.neighborhood != null ? "${listing.neighborhood}، " : ""}${listing.area}، ${listing.city}'
                          '${listing.landmark != null && listing.landmark!.isNotEmpty ? " — ${listing.landmark}" : ""}',
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
                      date: listing.verifiedAt,
                      playEntranceAnimation: true,
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (listing.roomsTotal != null)
                        _StatBox(icon: Icons.bed_outlined, label: 'الغرف', value: '${listing.roomsTotal}'),
                      if (listing.roomsTotal != null) const SizedBox(width: 12),
                      _StatBox(
                        icon: Icons.checkroom_outlined,
                        label: 'الفرش',
                        value: listing.furnished ? 'مفروشة' : 'غير مفروشة',
                      ),
                      const SizedBox(width: 12),
                      _StatBox(
                        icon: Icons.people_outline_rounded,
                        label: 'مناسبة لـ',
                        value: listing.genderPolLabel,
                      ),
                    ],
                  ),
                  if (listing.minStayMonths != null) ...[
                    const SizedBox(height: 12),
                    Text('أقل مدة إيجار: ${listing.minStayMonths} شهر', style: const TextStyle(color: SColors.mut)),
                  ],
                  if (listing.description != null && listing.description!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('الوصف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: SColors.navy)),
                    const SizedBox(height: 10),
                    Text(listing.description!, style: const TextStyle(color: SColors.navy, height: 1.6)),
                  ],
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
                  if (listing.features.isNotEmpty) ...[
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
            onPressed: _openContactSheet,
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
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, color: SColors.navy),
            ),
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
