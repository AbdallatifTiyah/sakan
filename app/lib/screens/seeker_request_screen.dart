import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/account_repo.dart';
import '../data/locations_repo.dart';
import '../data/seeker_repo.dart';
import '../validators.dart';

const _occupations = [
  ('student', 'طالب/ة'),
  ('employee', 'موظف/ة'),
  ('family', 'عائلة'),
  ('visitor', 'زائر/ة'),
  ('other', 'غير ذلك'),
];
const _kinds = [
  ('apartment', 'شقة كاملة'),
  ('studio', 'استديو'),
  ('room_shared', 'غرفة بسكن مشترك'),
];
const _genders = [('female', 'أنثى'), ('male', 'ذكر')];

/// تسجيل طلب بحث — فورم واحد (لا خطوات)، نفس submit_request() حرفياً.
/// ثانوي لمسار المالك حسب التركيز التجاري الحالي (قرار ٢٠٢٦-١٠-٠٢).
class SeekerRequestScreen extends StatefulWidget {
  const SeekerRequestScreen({super.key});

  @override
  State<SeekerRequestScreen> createState() => _SeekerRequestScreenState();
}

class _SeekerRequestScreenState extends State<SeekerRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  List<SCity> _cities = [];
  SCity? _city;
  List<SArea> _areas = [];
  final Set<int> _selectedAreas = {};
  List<SNeighborhood> _allNeighborhoods = [];
  final Set<int> _selectedNeighborhoods = {};
  String? _gender;
  String _occupation = 'other';
  final _budgetCtrl = TextEditingController();
  DateTime _moveIn = DateTime.now();
  String? _kind;
  bool? _furnished;
  bool? _smoker;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _submitting = false;
  String? _cityError;
  String? _areasError;
  String? _smokerError;

  @override
  void initState() {
    super.initState();
    LocationsRepo.fetchCities().then((c) {
      if (mounted) setState(() => _cities = c);
    });
    for (final c in [_budgetCtrl, _nameCtrl, _phoneCtrl]) {
      c.addListener(() => mounted ? setState(() {}) : null);
    }
    _prefillFromAccount();
  }

  /// مسجّل دخول وله بروفايل (باحث أو مالك)؟ عبّي الاسم والرقم تلقائياً —
  /// تبقى قابلة للتعديل، بعكس شاشة التواصل اللي بتتخطّى السؤال كلياً.
  Future<void> _prefillFromAccount() async {
    final profile = await AccountRepo.findProfile('seeker') ?? await AccountRepo.findProfile('owner');
    if (!mounted || profile == null) return;
    final name = (profile['first_name'] as String?)?.trim() ?? '';
    final phone = (profile['phone'] as String?)?.trim() ?? '';
    if (name.isNotEmpty) _nameCtrl.text = name;
    if (phone.isNotEmpty) _phoneCtrl.text = phone;
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _onCityChanged(SCity? city) async {
    setState(() {
      _city = city;
      _cityError = null;
      _selectedAreas.clear();
      _selectedNeighborhoods.clear();
      _areas = [];
      _allNeighborhoods = [];
    });
    if (city == null) return;
    final areas = await LocationsRepo.fetchAreas(city.id);
    if (!mounted) return;
    setState(() => _areas = areas);
    final lists = await Future.wait(areas.map((a) => LocationsRepo.fetchNeighborhoods(a.id)));
    if (!mounted) return;
    setState(() => _allNeighborhoods = lists.expand((l) => l).toList());
  }

  void _toggleArea(int areaId) {
    setState(() {
      _areasError = null;
      if (_selectedAreas.contains(areaId)) {
        _selectedAreas.remove(areaId);
        _selectedNeighborhoods.removeWhere(
            (nid) => _allNeighborhoods.firstWhere((n) => n.id == nid).areaId == areaId);
      } else {
        _selectedAreas.add(areaId);
      }
    });
  }

  /// يملأ أخطاء الحقول اللي ما إلها TextFormField (المدينة/المناطق/التدخين
  /// اختيارات chips، مش فورم) ويرجّع صحة الفورم كامل — بدل تعطيل الزر بصمت،
  /// الزر بيضل مفعّل ويوضّح الحقل الناقص عند الضغط (قاعدة التحقّق الظاهر).
  bool _validate() {
    setState(() {
      _cityError = _city == null ? 'اختر مدينة' : null;
      _areasError = _selectedAreas.isEmpty ? 'اختر منطقة واحدة على الأقل' : null;
      _smokerError = _smoker == null ? 'اختر إجابة' : null;
    });
    final formOk = _formKey.currentState?.validate() ?? false;
    return formOk && _cityError == null && _areasError == null && _smokerError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _submitting = true);
    try {
      final ref = await SeekerRepo.submitRequest(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        gender: _gender,
        occupation: _occupation,
        budget: num.parse(_budgetCtrl.text.trim()),
        areas: _selectedAreas.toList(),
        moveIn: _moveIn,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        city: _city!.id,
        kind: _kind,
        furnished: _furnished,
        smoker: _smoker!,
        neighborhoods: _selectedNeighborhoods.toList(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SRadius.md)),
          title: const Text('تم تسجيل طلبك'),
          content: Text('رقم الطلب: $ref\nرح نوصلك لما يكون في سكن مناسب.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('تم')),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجّل طلب بحث')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const Text(
              'طلب مجاني بالكامل. بنوصلك إشعار لما ينضاف سكن يطابق طلبك.',
              style: TextStyle(color: SColors.mut, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 20),
            const Text('المدينة', style: TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _cities
                  .map((c) => ChoiceChip(
                        label: Text(c.nameAr),
                        selected: _city?.id == c.id,
                        onSelected: (_) => _onCityChanged(c),
                        selectedColor: SColors.blue600,
                        labelStyle: TextStyle(color: _city?.id == c.id ? Colors.white : SColors.navy, fontWeight: FontWeight.w600),
                        backgroundColor: SColors.card,
                        side: BorderSide(color: _city?.id == c.id ? SColors.blue600 : SColors.line),
                      ))
                  .toList(),
            ),
            if (_cityError != null) ...[
              const SizedBox(height: 6),
              Text(_cityError!, style: const TextStyle(color: SColors.danger, fontSize: 12)),
            ],
            if (_areas.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('المناطق المفضّلة (تقدر تختار أكثر من وحدة)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _areas
                    .map((a) => FilterChip(
                          label: Text(a.nameAr),
                          selected: _selectedAreas.contains(a.id),
                          onSelected: (_) => _toggleArea(a.id),
                          selectedColor: SColors.blue100,
                          checkmarkColor: SColors.blue700,
                          labelStyle: TextStyle(
                            color: _selectedAreas.contains(a.id) ? SColors.blue700 : SColors.navy,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: SColors.card,
                          side: BorderSide(color: _selectedAreas.contains(a.id) ? SColors.blue600 : SColors.line),
                        ))
                    .toList(),
              ),
              if (_areasError != null) ...[
                const SizedBox(height: 6),
                Text(_areasError!, style: const TextStyle(color: SColors.danger, fontSize: 12)),
              ],
            ],
            if (_selectedAreas.isNotEmpty &&
                _allNeighborhoods.any((n) => _selectedAreas.contains(n.areaId))) ...[
              const SizedBox(height: 20),
              const Text('المواقع المفضّلة (اختياري)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allNeighborhoods
                    .where((n) => _selectedAreas.contains(n.areaId))
                    .map((n) => FilterChip(
                          label: Text(n.nameAr),
                          selected: _selectedNeighborhoods.contains(n.id),
                          onSelected: (_) => setState(() {
                            if (_selectedNeighborhoods.contains(n.id)) {
                              _selectedNeighborhoods.remove(n.id);
                            } else {
                              _selectedNeighborhoods.add(n.id);
                            }
                          }),
                          selectedColor: SColors.blue100,
                          checkmarkColor: SColors.blue700,
                          labelStyle: TextStyle(
                            color: _selectedNeighborhoods.contains(n.id) ? SColors.blue700 : SColors.navy,
                            fontWeight: FontWeight.w600,
                          ),
                          backgroundColor: SColors.card,
                          side: BorderSide(color: _selectedNeighborhoods.contains(n.id) ? SColors.blue600 : SColors.line),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _budgetCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'الميزانية القصوى (شيكل)', border: OutlineInputBorder()),
              validator: (v) => numericValidator(v, min: 1, label: 'الميزانية القصوى'),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تاريخ الانتقال', style: TextStyle(color: SColors.navy)),
              subtitle: Text('${_moveIn.year}-${_moveIn.month.toString().padLeft(2, '0')}-${_moveIn.day.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.calendar_today_outlined, color: SColors.blue600),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _moveIn,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _moveIn = picked);
              },
            ),
            const SizedBox(height: 12),
            const Text('نوع السكن المفضّل (اختياري)', style: TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _kinds
                  .map((k) => ChoiceChip(
                        label: Text(k.$2),
                        selected: _kind == k.$1,
                        onSelected: (_) => setState(() => _kind = _kind == k.$1 ? null : k.$1),
                        selectedColor: SColors.blue600,
                        labelStyle: TextStyle(color: _kind == k.$1 ? Colors.white : SColors.navy, fontWeight: FontWeight.w600),
                        backgroundColor: SColors.card,
                        side: BorderSide(color: _kind == k.$1 ? SColors.blue600 : SColors.line),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text('مدخّن/ة؟', style: TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('لا'),
                    selected: _smoker == false,
                    onSelected: (_) => setState(() {
                      _smoker = false;
                      _smokerError = null;
                    }),
                    selectedColor: SColors.blue600,
                    labelStyle: TextStyle(color: _smoker == false ? Colors.white : SColors.navy, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('نعم'),
                    selected: _smoker == true,
                    onSelected: (_) => setState(() {
                      _smoker = true;
                      _smokerError = null;
                    }),
                    selectedColor: SColors.blue600,
                    labelStyle: TextStyle(color: _smoker == true ? Colors.white : SColors.navy, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (_smokerError != null) ...[
              const SizedBox(height: 6),
              Text(_smokerError!, style: const TextStyle(color: SColors.danger, fontSize: 12)),
            ],
            const SizedBox(height: 20),
            const Text('حالتك', style: TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _occupations
                  .map((o) => ChoiceChip(
                        label: Text(o.$2),
                        selected: _occupation == o.$1,
                        onSelected: (_) => setState(() => _occupation = o.$1),
                        selectedColor: SColors.blue600,
                        labelStyle: TextStyle(color: _occupation == o.$1 ? Colors.white : SColors.navy, fontWeight: FontWeight.w600),
                        backgroundColor: SColors.card,
                        side: BorderSide(color: _occupation == o.$1 ? SColors.blue600 : SColors.line),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            const Text('جنسك (اختياري)', style: TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _genders
                  .map((g) => ChoiceChip(
                        label: Text(g.$2),
                        selected: _gender == g.$1,
                        onSelected: (_) => setState(() => _gender = _gender == g.$1 ? null : g.$1),
                        selectedColor: SColors.blue600,
                        labelStyle: TextStyle(color: _gender == g.$1 ? Colors.white : SColors.navy, fontWeight: FontWeight.w600),
                        backgroundColor: SColors.card,
                        side: BorderSide(color: _gender == g.$1 ? SColors.blue600 : SColors.line),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            const Text('معلوماتك', style: TextStyle(fontWeight: FontWeight.bold, color: SColors.navy, fontSize: 16)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'اسمك', border: OutlineInputBorder()),
              validator: (v) => requiredValidator(v, 'اسمك'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'رقم هاتفك', border: OutlineInputBorder()),
              validator: phoneValidator,
            ),
            const SizedBox(height: 24),
            SPrimaryButton(
              label: _submitting ? 'جارٍ الإرسال...' : 'سجّل طلب البحث',
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
        ),
      ),
    );
  }
}
