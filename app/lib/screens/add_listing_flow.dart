import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../features.dart';
import '../data/locations_repo.dart';
import '../data/owner_repo.dart';
import '../data/storage_repo.dart';

const _kinds = [
  ('apartment', 'شقة كاملة'),
  ('studio', 'استديو'),
  ('room_shared', 'غرفة بسكن مشترك'),
];
const _genders = [
  ('mixed', 'عائلات'),
  ('female', 'إناث فقط'),
  ('male', 'ذكور فقط'),
];
const _currencies = [
  ('ILS', 'شيكل'),
  ('JOD', 'دينار'),
  ('USD', 'دولار'),
];

/// مسار "أضف شقتك" الكامل — ٨ خطوات، كل خطوة أسئلة مترابطة فقط (لا فورم
/// طويل واحد، قرار DESIGN.md). الإرسال الفعلي عبر submit_listing() حرفياً.
class AddListingFlow extends StatefulWidget {
  const AddListingFlow({super.key});

  @override
  State<AddListingFlow> createState() => _AddListingFlowState();
}

class _AddListingFlowState extends State<AddListingFlow> {
  static const _totalSteps = 8;
  int _step = 0;
  bool _submitting = false;

  List<SCity> _cities = [];
  SCity? _city;
  List<SArea> _areas = [];
  SArea? _area;
  String _kind = 'apartment';

  final _priceCtrl = TextEditingController();
  final _depositCtrl = TextEditingController();
  String _currency = 'ILS';

  final _roomsCtrl = TextEditingController();
  final _minStayCtrl = TextEditingController();
  DateTime _availableFrom = DateTime.now();
  bool _furnished = true;
  String _genderPol = 'mixed';

  bool _billsWater = false, _billsElectricity = false, _billsInternet = false;
  final Set<String> _features = {};

  final _descCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _occupantsNoteCtrl = TextEditingController();

  final _picker = ImagePicker();
  final List<XFile> _photos = [];

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _promoCtrl = TextEditingController();
  num? _feeBefore;
  num? _feeAfter;
  String? _promoMessage;
  bool _checkingPromo = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
    // بدون هالـlisteners، الكتابة بالحقول ما بتعيد تقييم _canProceed —
    // زر "التالي" بيضل معطّل حتى لو الحقل اتعبّى (باگ حي اكتُشف بفحص المحاكي).
    for (final c in [_priceCtrl, _nameCtrl, _phoneCtrl]) {
      c.addListener(_onFormFieldChanged);
    }
  }

  void _onFormFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [
      _priceCtrl,
      _depositCtrl,
      _roomsCtrl,
      _minStayCtrl,
      _descCtrl,
      _landmarkCtrl,
      _occupantsNoteCtrl,
      _nameCtrl,
      _phoneCtrl,
      _promoCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCities() async {
    final cities = await LocationsRepo.fetchCities();
    if (!mounted) return;
    setState(() => _cities = cities);
  }

  Future<void> _onCitySelected(SCity city) async {
    setState(() {
      _city = city;
      _area = null;
      _areas = [];
    });
    final areas = await LocationsRepo.fetchAreas(city.id);
    if (!mounted) return;
    setState(() => _areas = areas);
  }

  Future<void> _loadFeeQuote() async {
    try {
      final fee = await OwnerRepo.quoteListingFee(_kind);
      if (!mounted) return;
      setState(() {
        _feeBefore = fee;
        _feeAfter = fee;
      });
    } catch (_) {}
  }

  Future<void> _applyPromo() async {
    final code = _promoCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _checkingPromo = true;
      _promoMessage = null;
    });
    try {
      final quote = await OwnerRepo.quotePromoDiscount(code, _kind);
      if (!mounted) return;
      setState(() {
        _feeBefore = quote.feeBefore;
        _feeAfter = quote.feeAfter;
        _promoMessage = quote.feeAfter == 0
            ? 'خصم ${quote.discountPct}٪ — رسم النجاح: صفر شيكل'
            : 'خصم ${quote.discountPct}٪ — رسم النجاح المتوقع: ${quote.feeAfter.toStringAsFixed(0)} شيكل بدل ${quote.feeBefore.toStringAsFixed(0)}';
        _checkingPromo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _promoMessage = e.toString().replaceFirst('Exception: ', '');
        _checkingPromo = false;
      });
    }
  }

  bool get _canProceed {
    switch (_step) {
      case 0:
        return _city != null;
      case 1:
        return _area != null;
      case 2:
        return _priceCtrl.text.trim().isNotEmpty && num.tryParse(_priceCtrl.text.trim()) != null;
      case 3:
        return true;
      case 4:
        return true;
      case 5:
        return true;
      case 6:
        return _photos.isNotEmpty;
      case 7:
        return _nameCtrl.text.trim().isNotEmpty && _phoneCtrl.text.trim().isNotEmpty;
      default:
        return false;
    }
  }

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(limit: 8 - _photos.length);
    if (picked.isEmpty) return;
    setState(() => _photos.addAll(picked.take(8 - _photos.length)));
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final urls = <String>[];
      for (var i = 0; i < _photos.length; i++) {
        final url = await StorageRepo.uploadListingPhoto(_photos[i].path, i);
        urls.add(url);
      }
      final ref = await OwnerRepo.submitListing(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        title: _descCtrl.text.trim().isNotEmpty
            ? _descCtrl.text.trim().split('\n').first
            : '${_kinds.firstWhere((k) => k.$1 == _kind).$2} بـ${_area?.nameAr ?? ""}',
        area: _area!.id,
        price: num.parse(_priceCtrl.text.trim()),
        kind: _kind,
        genderPol: _genderPol,
        furnished: _furnished,
        availableFrom: _availableFrom,
        occupantsNote: _occupantsNoteCtrl.text.trim().isEmpty ? null : _occupantsNoteCtrl.text.trim(),
        landmark: _landmarkCtrl.text.trim().isEmpty ? null : _landmarkCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        features: _features.toList(),
        deposit: _depositCtrl.text.trim().isEmpty ? null : num.tryParse(_depositCtrl.text.trim()),
        rooms: _roomsCtrl.text.trim().isEmpty ? null : int.tryParse(_roomsCtrl.text.trim()),
        minStayMonths: _minStayCtrl.text.trim().isEmpty ? null : int.tryParse(_minStayCtrl.text.trim()),
        images: urls,
        currency: _currency,
        billsWater: _billsWater,
        billsElectricity: _billsElectricity,
        billsInternet: _billsInternet,
        promoCode: _promoCtrl.text.trim().isEmpty ? null : _promoCtrl.text.trim(),
        rentalPeriod: 'monthly',
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SRadius.md)),
          title: const Text('تم إرسال شقتك للمراجعة'),
          content: Text('رقم الإعلان: $ref\nرح يظهر بالموقع بعد مراجعة الطاقم.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تم'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _next() {
    if (_step == 1) _loadFeeQuote();
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: const Text('أضف شقتك'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepProgress(step: _step + 1, total: _totalSteps),
              const SizedBox(height: 24),
              Expanded(child: SingleChildScrollView(child: _buildStep())),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(child: SSecondaryButton(label: 'السابق', onPressed: _back)),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: SPrimaryButton(
                      label: _submitting
                          ? 'جارٍ الإرسال...'
                          : _step == _totalSteps - 1
                              ? 'أرسل للمراجعة'
                              : 'التالي',
                      icon: _step == _totalSteps - 1 ? null : Icons.arrow_back,
                      onPressed: (_canProceed && !_submitting) ? _next : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _CityStep(cities: _cities, selected: _city, onSelect: _onCitySelected);
      case 1:
        return _AreaKindStep(
          areas: _areas,
          selectedArea: _area,
          onAreaSelected: (a) => setState(() => _area = a),
          kind: _kind,
          onKindChanged: (k) => setState(() => _kind = k),
        );
      case 2:
        return _PriceStep(
          priceCtrl: _priceCtrl,
          depositCtrl: _depositCtrl,
          currency: _currency,
          onCurrencyChanged: (c) => setState(() => _currency = c),
        );
      case 3:
        return _DetailsStep(
          roomsCtrl: _roomsCtrl,
          minStayCtrl: _minStayCtrl,
          availableFrom: _availableFrom,
          onDateChanged: (d) => setState(() => _availableFrom = d),
          furnished: _furnished,
          onFurnishedChanged: (v) => setState(() => _furnished = v),
          genderPol: _genderPol,
          onGenderChanged: (g) => setState(() => _genderPol = g),
        );
      case 4:
        return _BillsFeaturesStep(
          billsWater: _billsWater,
          billsElectricity: _billsElectricity,
          billsInternet: _billsInternet,
          onBillsChanged: (w, e, i) => setState(() {
            _billsWater = w;
            _billsElectricity = e;
            _billsInternet = i;
          }),
          selectedFeatures: _features,
          onFeatureToggled: (slug) => setState(() {
            if (_features.contains(slug)) {
              _features.remove(slug);
            } else {
              _features.add(slug);
            }
          }),
        );
      case 5:
        return _DescriptionStep(
          descCtrl: _descCtrl,
          landmarkCtrl: _landmarkCtrl,
          occupantsNoteCtrl: _occupantsNoteCtrl,
        );
      case 6:
        return _PhotosStep(photos: _photos, onAdd: _pickPhotos, onRemove: (i) => setState(() => _photos.removeAt(i)));
      case 7:
        return _ContactPromoStep(
          nameCtrl: _nameCtrl,
          phoneCtrl: _phoneCtrl,
          promoCtrl: _promoCtrl,
          feeBefore: _feeBefore,
          feeAfter: _feeAfter,
          promoMessage: _promoMessage,
          checkingPromo: _checkingPromo,
          onApplyPromo: _applyPromo,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _StepProgress extends StatelessWidget {
  final int step, total;
  const _StepProgress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(left: i == total - 1 ? 0 : 4),
            height: 5,
            decoration: BoxDecoration(
              color: active ? SColors.blue600 : SColors.line,
              borderRadius: BorderRadius.circular(SRadius.pill),
            ),
          ),
        );
      }),
    );
  }
}

class _StepTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _StepTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: SColors.navy)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: const TextStyle(color: SColors.mut, fontSize: 14)),
          ],
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceRow({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(SRadius.md),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? SColors.blue050 : SColors.card,
            borderRadius: BorderRadius.circular(SRadius.md),
            border: Border.all(color: selected ? SColors.blue600 : SColors.line, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? SColors.blue600 : SColors.mut),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: SColors.navy,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityStep extends StatelessWidget {
  final List<SCity> cities;
  final SCity? selected;
  final ValueChanged<SCity> onSelect;
  const _CityStep({required this.cities, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (cities.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(title: 'وين شقتك؟', subtitle: 'سؤال واحد بس عشان نبدأ — باقي التفاصيل بالخطوات الجاية.'),
        for (final c in cities) _ChoiceRow(label: c.nameAr, selected: selected?.id == c.id, onTap: () => onSelect(c)),
      ],
    );
  }
}

class _AreaKindStep extends StatelessWidget {
  final List<SArea> areas;
  final SArea? selectedArea;
  final ValueChanged<SArea> onAreaSelected;
  final String kind;
  final ValueChanged<String> onKindChanged;
  const _AreaKindStep({
    required this.areas,
    required this.selectedArea,
    required this.onAreaSelected,
    required this.kind,
    required this.onKindChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(title: 'وين بالضبط، وشو نوع السكن؟'),
        const Text('المنطقة', style: TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
        const SizedBox(height: 10),
        if (areas.isEmpty)
          const Text('اختر مدينة أولاً', style: TextStyle(color: SColors.mut))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: areas
                .map((a) => ChoiceChip(
                      label: Text(a.nameAr),
                      selected: selectedArea?.id == a.id,
                      onSelected: (_) => onAreaSelected(a),
                      selectedColor: SColors.blue600,
                      labelStyle: TextStyle(
                        color: selectedArea?.id == a.id ? Colors.white : SColors.navy,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: SColors.card,
                      side: BorderSide(color: selectedArea?.id == a.id ? SColors.blue600 : SColors.line),
                    ))
                .toList(),
          ),
        const SizedBox(height: 24),
        const Text('نوع السكن', style: TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
        const SizedBox(height: 10),
        for (final k in _kinds) _ChoiceRow(label: k.$2, selected: kind == k.$1, onTap: () => onKindChanged(k.$1)),
      ],
    );
  }
}

class _PriceStep extends StatelessWidget {
  final TextEditingController priceCtrl, depositCtrl;
  final String currency;
  final ValueChanged<String> onCurrencyChanged;
  const _PriceStep({
    required this.priceCtrl,
    required this.depositCtrl,
    required this.currency,
    required this.onCurrencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(title: 'السعر'),
        const Text('العملة', style: TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: _currencies
              .map((c) => ChoiceChip(
                    label: Text(c.$2),
                    selected: currency == c.$1,
                    onSelected: (_) => onCurrencyChanged(c.$1),
                    selectedColor: SColors.blue600,
                    labelStyle: TextStyle(color: currency == c.$1 ? Colors.white : SColors.navy, fontWeight: FontWeight.w600),
                    backgroundColor: SColors.card,
                    side: BorderSide(color: currency == c.$1 ? SColors.blue600 : SColors.line),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: priceCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(labelText: 'السعر الشهري', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: depositCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(labelText: 'مبلغ التأمين (اختياري)', border: OutlineInputBorder()),
        ),
      ],
    );
  }
}

class _DetailsStep extends StatelessWidget {
  final TextEditingController roomsCtrl, minStayCtrl;
  final DateTime availableFrom;
  final ValueChanged<DateTime> onDateChanged;
  final bool furnished;
  final ValueChanged<bool> onFurnishedChanged;
  final String genderPol;
  final ValueChanged<String> onGenderChanged;
  const _DetailsStep({
    required this.roomsCtrl,
    required this.minStayCtrl,
    required this.availableFrom,
    required this.onDateChanged,
    required this.furnished,
    required this.onFurnishedChanged,
    required this.genderPol,
    required this.onGenderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(title: 'تفاصيل إضافية'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: roomsCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'عدد الغرف', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: minStayCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'أقل مدة (أشهر)', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('تاريخ التوفر', style: TextStyle(color: SColors.navy)),
          subtitle: Text('${availableFrom.year}-${availableFrom.month.toString().padLeft(2, '0')}-${availableFrom.day.toString().padLeft(2, '0')}'),
          trailing: const Icon(Icons.calendar_today_outlined, color: SColors.blue600),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: availableFrom,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) onDateChanged(picked);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('مفروشة', style: TextStyle(color: SColors.navy)),
          value: furnished,
          activeThumbColor: SColors.blue600,
          onChanged: onFurnishedChanged,
        ),
        const SizedBox(height: 12),
        const Text('مناسبة لـ', style: TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: _genders
              .map((g) => ChoiceChip(
                    label: Text(g.$2),
                    selected: genderPol == g.$1,
                    onSelected: (_) => onGenderChanged(g.$1),
                    selectedColor: SColors.blue600,
                    labelStyle: TextStyle(color: genderPol == g.$1 ? Colors.white : SColors.navy, fontWeight: FontWeight.w600),
                    backgroundColor: SColors.card,
                    side: BorderSide(color: genderPol == g.$1 ? SColors.blue600 : SColors.line),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _BillsFeaturesStep extends StatelessWidget {
  final bool billsWater, billsElectricity, billsInternet;
  final void Function(bool, bool, bool) onBillsChanged;
  final Set<String> selectedFeatures;
  final ValueChanged<String> onFeatureToggled;
  const _BillsFeaturesStep({
    required this.billsWater,
    required this.billsElectricity,
    required this.billsInternet,
    required this.onBillsChanged,
    required this.selectedFeatures,
    required this.onFeatureToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(title: 'الفواتير والمواصفات'),
        const Text('الفواتير الشاملة', style: TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('ماء'),
          value: billsWater,
          activeThumbColor: SColors.blue600,
          onChanged: (v) => onBillsChanged(v, billsElectricity, billsInternet),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('كهرباء'),
          value: billsElectricity,
          activeThumbColor: SColors.blue600,
          onChanged: (v) => onBillsChanged(billsWater, v, billsInternet),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('إنترنت'),
          value: billsInternet,
          activeThumbColor: SColors.blue600,
          onChanged: (v) => onBillsChanged(billsWater, billsElectricity, v),
        ),
        const SizedBox(height: 16),
        const Text('المواصفات', style: TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sFeatures
              .map((f) => FilterChip(
                    label: Text(f.ar),
                    selected: selectedFeatures.contains(f.slug),
                    onSelected: (_) => onFeatureToggled(f.slug),
                    selectedColor: SColors.blue100,
                    checkmarkColor: SColors.blue700,
                    labelStyle: TextStyle(
                      color: selectedFeatures.contains(f.slug) ? SColors.blue700 : SColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: SColors.card,
                    side: BorderSide(color: selectedFeatures.contains(f.slug) ? SColors.blue600 : SColors.line),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _DescriptionStep extends StatelessWidget {
  final TextEditingController descCtrl, landmarkCtrl, occupantsNoteCtrl;
  const _DescriptionStep({required this.descCtrl, required this.landmarkCtrl, required this.occupantsNoteCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(title: 'وصف السكن'),
        TextField(
          controller: descCtrl,
          maxLines: 5,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            labelText: 'الوصف',
            hintText: 'وصف قصير للشقة ومحيطها...',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: landmarkCtrl,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(labelText: 'أقرب معلم (اختياري)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: occupantsNoteCtrl,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            labelText: 'ملاحظة عن الساكنين الحاليين (اختياري)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class _PhotosStep extends StatelessWidget {
  final List<XFile> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  const _PhotosStep({required this.photos, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(title: 'صور الشقة', subtitle: 'حتى ٨ صور — أضف صورة وحدة على الأقل.'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: photos.length + (photos.length < 8 ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == photos.length) {
              return InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(SRadius.sm),
                child: Container(
                  decoration: BoxDecoration(
                    color: SColors.blue050,
                    borderRadius: BorderRadius.circular(SRadius.sm),
                    border: Border.all(color: SColors.line),
                  ),
                  child: const Icon(Icons.add_a_photo_outlined, color: SColors.blue600),
                ),
              );
            }
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(SRadius.sm),
                  child: Image.file(File(photos[i].path), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                ),
                Positioned(
                  top: 2,
                  left: 2,
                  child: InkWell(
                    onTap: () => onRemove(i),
                    child: const CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ContactPromoStep extends StatelessWidget {
  final TextEditingController nameCtrl, phoneCtrl, promoCtrl;
  final num? feeBefore, feeAfter;
  final String? promoMessage;
  final bool checkingPromo;
  final VoidCallback onApplyPromo;
  const _ContactPromoStep({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.promoCtrl,
    required this.feeBefore,
    required this.feeAfter,
    required this.promoMessage,
    required this.checkingPromo,
    required this.onApplyPromo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepTitle(title: 'معلوماتك'),
        TextField(
          controller: nameCtrl,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(labelText: 'اسمك', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(labelText: 'رقم هاتفك', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: promoCtrl,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'كود الخصم (اختياري)', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: checkingPromo ? null : onApplyPromo,
              style: OutlinedButton.styleFrom(
                foregroundColor: SColors.blue600,
                side: const BorderSide(color: SColors.blue600),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              child: Text(checkingPromo ? '...' : 'تطبيق'),
            ),
          ],
        ),
        if (promoMessage != null) ...[
          const SizedBox(height: 10),
          Text(promoMessage!, style: const TextStyle(color: SColors.blue700, fontWeight: FontWeight.w600)),
        ],
        if (feeBefore != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SColors.blue050,
              borderRadius: BorderRadius.circular(SRadius.md),
            ),
            child: Text(
              'رسم النجاح المتوقع عند التأجير: ${feeAfter!.toStringAsFixed(0)} شيكل',
              style: const TextStyle(color: SColors.navy, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}
