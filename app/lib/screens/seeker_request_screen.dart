import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/locations_repo.dart';
import '../data/seeker_repo.dart';

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
  List<SCity> _cities = [];
  SCity? _city;
  List<SArea> _areas = [];
  final Set<int> _selectedAreas = {};
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

  @override
  void initState() {
    super.initState();
    LocationsRepo.fetchCities().then((c) {
      if (mounted) setState(() => _cities = c);
    });
    for (final c in [_budgetCtrl, _nameCtrl, _phoneCtrl]) {
      c.addListener(() => mounted ? setState(() {}) : null);
    }
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
      _selectedAreas.clear();
      _areas = [];
    });
    if (city == null) return;
    final areas = await LocationsRepo.fetchAreas(city.id);
    if (!mounted) return;
    setState(() => _areas = areas);
  }

  bool get _canSubmit =>
      _nameCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.trim().isNotEmpty &&
      _city != null &&
      _selectedAreas.isNotEmpty &&
      _budgetCtrl.text.trim().isNotEmpty &&
      num.tryParse(_budgetCtrl.text.trim()) != null &&
      _smoker != null;

  Future<void> _submit() async {
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
                          onSelected: (_) => setState(() {
                            if (_selectedAreas.contains(a.id)) {
                              _selectedAreas.remove(a.id);
                            } else {
                              _selectedAreas.add(a.id);
                            }
                          }),
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
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _budgetCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'الميزانية القصوى (شيكل)', border: OutlineInputBorder()),
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
                    onSelected: (_) => setState(() => _smoker = false),
                    selectedColor: SColors.blue600,
                    labelStyle: TextStyle(color: _smoker == false ? Colors.white : SColors.navy, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('نعم'),
                    selected: _smoker == true,
                    onSelected: (_) => setState(() => _smoker = true),
                    selectedColor: SColors.blue600,
                    labelStyle: TextStyle(color: _smoker == true ? Colors.white : SColors.navy, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
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
            TextField(
              controller: _nameCtrl,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'اسمك', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'رقم هاتفك', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SPrimaryButton(
              label: _submitting ? 'جارٍ الإرسال...' : 'سجّل طلب البحث',
              onPressed: (_canSubmit && !_submitting) ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
