import 'package:flutter/material.dart';
import '../theme.dart';
import '../app_lang.dart';
import '../data/seeker_repo.dart';
import 'seeker_request_screen.dart';

const _kindLabels = {'apartment': 'شقة كاملة', 'studio': 'استديو', 'room_shared': 'غرفة بسكن مشترك'};
const _periodLabels = {'weekly': 'أسبوعي', 'daily': 'يومي'};

/// شاشة "الباحثين" — وجهة ثانية بالشريط السفلي (بند ١٣). تعرض طلبات بحث
/// منشورة فعلياً من v_requests_public (دليل الطلب الحقيقي، قاعدة ٢١: الكلام
/// مسنود ببيانات لا تخمين)، وتفتح نفس SeekerRequestScreen الموجودة أصلاً
/// لتسجيل طلب جديد.
class SeekersScreen extends StatefulWidget {
  const SeekersScreen({super.key});

  @override
  State<SeekersScreen> createState() => _SeekersScreenState();
}

class _SeekersScreenState extends State<SeekersScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;

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
      final requests = await SeekerRepo.fetchPublicRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = tt('تعذّر تحميل البيانات. تأكد من الاتصال وحاول مرة ثانية.', 'Could not load data. Check your connection and try again.');
        _loading = false;
      });
    }
  }

  void _openRegister() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SeekerRequestScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tt('الباحثون عن سكن', 'People looking for housing'), style: const TextStyle(color: SColors.blue700, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  tt('طلبات بحث فعلية — دليل الطلب الحقيقي على سكنّا.', 'Real search requests — real demand on Sakanna.'),
                  style: const TextStyle(color: SColors.mut, fontSize: 13, height: 1.6),
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: SColors.amber,
        foregroundColor: SColors.navy,
        onPressed: _openRegister,
        icon: const Icon(Icons.person_search_rounded),
        label: Text(tt('سجّل طلب بحث', 'Register a request'), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: 3,
        itemBuilder: (context, i) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _RequestCardSkeleton(),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: SColors.mut),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: SColors.mut)),
              const SizedBox(height: 16),
              SSecondaryButton(label: tt('إعادة المحاولة', 'Retry'), onPressed: _load),
            ],
          ),
        ),
      );
    }
    if (_requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_outlined, size: 48, color: SColors.mut),
              const SizedBox(height: 16),
              Text(
                tt('ما في طلبات بحث منشورة حالياً.', 'No published search requests right now.'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, color: SColors.navy),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _requests.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _RequestCard(request: _requests[i]),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final city = request['city'] as String? ?? '';
    final budget = request['budget_max'];
    final kind = request['kind_pref'] as String?;
    final period = request['rental_period_pref'] as String?;
    final smoker = request['smoker'];
    final moveIn = DateTime.tryParse(request['move_in_date']?.toString() ?? '');

    return Container(
      decoration: BoxDecoration(
        color: SColors.card,
        borderRadius: BorderRadius.circular(SRadius.md),
        border: Border.all(color: SColors.line),
        boxShadow: sShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${request['ref'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: SColors.navy),
                ),
              ),
              Text(
                '${tt('حتى', 'Up to')} ${budget ?? ''} ${tt('شيكل', 'ILS')}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: SColors.blue700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(city, style: const TextStyle(color: SColors.mut, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (kind != null) _Tag(_kindLabels[kind] ?? kind),
              if (period != null && _periodLabels.containsKey(period)) _Tag(_periodLabels[period]!),
              if (smoker == false) _Tag(tt('غير مدخّن/ة', 'Non-smoker')),
              if (moveIn != null)
                _Tag('${tt('من', 'From')} ${moveIn.year}-${moveIn.month.toString().padLeft(2, '0')}-${moveIn.day.toString().padLeft(2, '0')}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: SColors.blue050, borderRadius: BorderRadius.circular(SRadius.pill)),
      child: Text(text, style: const TextStyle(color: SColors.blue700, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _RequestCardSkeleton extends StatelessWidget {
  const _RequestCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: SColors.card,
        borderRadius: BorderRadius.circular(SRadius.md),
        border: Border.all(color: SColors.line),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 14, width: 120, color: SColors.blue050),
          const SizedBox(height: 10),
          Container(height: 14, width: 180, color: SColors.blue050),
        ],
      ),
    );
  }
}
