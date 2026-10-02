import 'package:flutter/material.dart';
import '../theme.dart';
import '../main.dart';
import '../data/account_repo.dart';
import '../validators.dart';
import 'listing_tracking_screen.dart';
import 'request_tracking_screen.dart';

/// حسابي — طبقة اختيارية فوق التصفّح بدون تسجيل (قاعدة: الحساب اختياري
/// وإضافي، مش شرط). نفس Supabase Auth المستخدم بـaccount.html بالموقع.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: StreamBuilder(
        stream: supabase.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = supabase.auth.currentSession;
          return session == null ? const _AuthForm() : const _LoggedInView();
        },
      ),
    );
  }
}

class _AuthForm extends StatefulWidget {
  const _AuthForm();

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_emailCtrl, _passCtrl]) {
      c.addListener(() => mounted ? setState(() {}) : null);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await AccountRepo.signUp(_emailCtrl.text.trim(), _passCtrl.text);
      } else {
        await AccountRepo.signIn(_emailCtrl.text.trim(), _passCtrl.text);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _isSignUp ? 'إنشاء حساب' : 'تسجيل الدخول',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: SColors.navy),
            ),
            const SizedBox(height: 8),
            const Text(
              'الحساب اختياري — بيعطيك متابعة لإعلاناتك وطلباتك وإشعارات. التصفّح والإضافة شغّالة بدونه.',
              style: TextStyle(color: SColors.mut, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder()),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'البريد الإلكتروني مطلوب';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'بريد إلكتروني غير صحيح';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passCtrl,
              obscureText: true,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'كلمة السر (٦ أحرف على الأقل)', border: OutlineInputBorder()),
              validator: (v) => (v ?? '').length < 6 ? 'كلمة السر لازم تكون ٦ أحرف على الأقل' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: SColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SPrimaryButton(
              label: _loading ? 'جارٍ التحقّق...' : (_isSignUp ? 'إنشاء الحساب' : 'دخول'),
              onPressed: _loading ? null : _submit,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _isSignUp = !_isSignUp),
              child: Text(_isSignUp ? 'عندك حساب؟ سجّل دخول' : 'ما عندك حساب؟ أنشئ وحد'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoggedInView extends StatefulWidget {
  const _LoggedInView();

  @override
  State<_LoggedInView> createState() => _LoggedInViewState();
}

class _LoggedInViewState extends State<_LoggedInView> {
  List<dynamic> _profiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final profiles = await AccountRepo.myProfile();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SRadius.md)),
        title: const Text('حذف الحساب نهائياً'),
        content: const Text('بيتحذف حساب الدخول بالكامل ومش راجع. إعلاناتك وطلباتك القديمة بتضل موجودة بدون ربط بحساب.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('احذف', style: TextStyle(color: SColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      await AccountRepo.deleteAccount();
      if (!mounted) return;
      await supabase.auth.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final hasOwner = _profiles.any((p) => p['role'] == 'owner');
    final hasSeeker = _profiles.any((p) => p['role'] == 'seeker');

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(supabase.auth.currentUser?.email ?? '', style: const TextStyle(color: SColors.mut)),
          const SizedBox(height: 20),
          if (!hasOwner || !hasSeeker) _LinkRoleCard(hasOwner: hasOwner, hasSeeker: hasSeeker, onLinked: _load),
          if (hasOwner) ...[
            const SizedBox(height: 20),
            const Text('إعلاناتي وطلبات التواصل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: SColors.navy)),
            const SizedBox(height: 10),
            _OwnerDashboard(),
          ],
          if (hasSeeker) ...[
            const SizedBox(height: 20),
            const Text('طلباتي وحفظي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: SColors.navy)),
            const SizedBox(height: 10),
            _SeekerDashboard(),
          ],
          const SizedBox(height: 32),
          SSecondaryButton(label: 'تسجيل الخروج', onPressed: () => supabase.auth.signOut()),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _confirmDelete,
            child: const Text('حذف الحساب نهائياً', style: TextStyle(color: SColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _LinkRoleCard extends StatefulWidget {
  final bool hasOwner, hasSeeker;
  final VoidCallback onLinked;
  const _LinkRoleCard({required this.hasOwner, required this.hasSeeker, required this.onLinked});

  @override
  State<_LinkRoleCard> createState() => _LinkRoleCardState();
}

class _LinkRoleCardState extends State<_LinkRoleCard> {
  final _formKey = GlobalKey<FormState>();
  String? _role;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  /// لو الحساب عنده صفة أخرى أصلاً (مالك مثلاً وعم يفعّل باحث)، نفس الاسم
  /// والرقم غالباً — نعبّيهم تلقائياً، يبقوا قابلين للتعديل.
  Future<void> _selectRole(String role) async {
    setState(() => _role = role);
    if (_nameCtrl.text.trim().isNotEmpty || _phoneCtrl.text.trim().isNotEmpty) return;
    final otherRole = role == 'owner' ? 'seeker' : 'owner';
    final profile = await AccountRepo.findProfile(otherRole);
    if (!mounted || profile == null) return;
    setState(() {
      _nameCtrl.text = (profile['first_name'] as String?)?.trim() ?? '';
      _phoneCtrl.text = (profile['phone'] as String?)?.trim() ?? '';
    });
  }

  Future<void> _link() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await AccountRepo.linkRole(role: _role!, name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim());
      widget.onLinked();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SColors.blue050,
        borderRadius: BorderRadius.circular(SRadius.md),
      ),
      child: Form(
        key: _formKey,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('فعّل صفة جديدة على حسابك', style: TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!widget.hasOwner)
                Expanded(
                  child: ChoiceChip(
                    label: const Text('مالك'),
                    selected: _role == 'owner',
                    onSelected: (_) => _selectRole('owner'),
                    selectedColor: SColors.blue600,
                    labelStyle: TextStyle(color: _role == 'owner' ? Colors.white : SColors.navy),
                  ),
                ),
              if (!widget.hasOwner && !widget.hasSeeker) const SizedBox(width: 8),
              if (!widget.hasSeeker)
                Expanded(
                  child: ChoiceChip(
                    label: const Text('باحث عن سكن'),
                    selected: _role == 'seeker',
                    onSelected: (_) => _selectRole('seeker'),
                    selectedColor: SColors.blue600,
                    labelStyle: TextStyle(color: _role == 'seeker' ? Colors.white : SColors.navy),
                  ),
                ),
            ],
          ),
          if (_role != null) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'اسمك', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              validator: (v) => requiredValidator(v, 'اسمك'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'رقم هاتفك', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              validator: phoneValidator,
            ),
            const SizedBox(height: 12),
            SPrimaryButton(
              label: _submitting ? 'جارٍ التفعيل...' : 'تفعيل',
              onPressed: _submitting ? null : _link,
            ),
          ],
        ],
        ),
      ),
    );
  }
}

class _OwnerDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: AccountRepo.ownerDashboard(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator());
        final listings = snapshot.data!['listings'] as List<dynamic>? ?? [];
        if (listings.isEmpty) {
          return const Text('لسا ما أضفت شقة.', style: TextStyle(color: SColors.mut));
        }
        return Column(
          children: listings.map((l) {
            final listing = (l as Map).cast<String, dynamic>();
            final deletionPending = listing['deletion_requested_at'] != null;
            return Material(
              color: SColors.card,
              borderRadius: BorderRadius.circular(SRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(SRadius.md),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ListingTrackingScreen(listing: listing)),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SRadius.md),
                    border: Border.all(color: SColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(listing['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: SColors.navy)),
                            Text('${listing['ref']} · ${listing['status']}', style: const TextStyle(color: SColors.mut, fontSize: 12)),
                            if (deletionPending) ...[
                              const SizedBox(height: 4),
                              const Text('طلب الحذف قيد المراجعة', style: TextStyle(color: SColors.warn, fontSize: 11)),
                            ],
                          ],
                        ),
                      ),
                      Text('${listing['view_count'] ?? 0} مشاهدة', style: const TextStyle(color: SColors.mut, fontSize: 12)),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_left, color: SColors.mut, size: 18),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SeekerDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: AccountRepo.seekerDashboard(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator());
        final requests = snapshot.data!['requests'] as List<dynamic>? ?? [];
        if (requests.isEmpty) {
          return const Text('لسا ما سجّلت طلب بحث.', style: TextStyle(color: SColors.mut));
        }
        return Column(
          children: requests.map((r) {
            final request = (r as Map).cast<String, dynamic>();
            final deletionPending = request['deletion_requested_at'] != null;
            return Material(
              color: SColors.card,
              borderRadius: BorderRadius.circular(SRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(SRadius.md),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RequestTrackingScreen(request: request)),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SRadius.md),
                    border: Border.all(color: SColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${request['city']} · ${request['status']}', style: const TextStyle(color: SColors.navy)),
                            if (deletionPending) ...[
                              const SizedBox(height: 4),
                              const Text('طلب الحذف قيد المراجعة', style: TextStyle(color: SColors.warn, fontSize: 11)),
                            ],
                          ],
                        ),
                      ),
                      Text('${request['budget_max']} شيكل', style: const TextStyle(color: SColors.blue700, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_left, color: SColors.mut, size: 18),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
