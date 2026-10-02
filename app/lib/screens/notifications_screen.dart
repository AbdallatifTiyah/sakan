import 'package:flutter/material.dart';
import '../theme.dart';
import '../data/notifications_repo.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await NotificationsRepo.fetch();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _onTapItem(Map<String, dynamic> item) async {
    if (item['is_read'] == true) return;
    setState(() => item['is_read'] = true);
    await NotificationsRepo.markRead(item['id'] as String);
  }

  String _fmtDate(dynamic iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '');
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : !NotificationsRepo.isLoggedIn
                  ? const _EmptyNotifications(message: 'سجّل دخول بحسابك لرؤية إشعاراتك.')
                  : _items.isEmpty
                      ? const _EmptyNotifications(message: 'ما في إشعارات لسا.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            final unread = item['is_read'] != true;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: unread ? SColors.blue050 : SColors.card,
                                borderRadius: BorderRadius.circular(SRadius.md),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(SRadius.md),
                                  onTap: () => _onTapItem(item),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(SRadius.md),
                                      border: Border.all(color: SColors.line),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (unread)
                                          Container(
                                            margin: const EdgeInsets.only(top: 6, left: 10),
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(color: SColors.amber, shape: BoxShape.circle),
                                          ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['title'] as String? ?? '',
                                                style: TextStyle(
                                                  fontWeight: unread ? FontWeight.bold : FontWeight.w600,
                                                  color: SColors.navy,
                                                ),
                                              ),
                                              if ((item['body'] as String?)?.isNotEmpty == true) ...[
                                                const SizedBox(height: 4),
                                                Text(item['body'] as String, style: const TextStyle(color: SColors.mut, fontSize: 13, height: 1.5)),
                                              ],
                                              const SizedBox(height: 6),
                                              Text(_fmtDate(item['created_at']), style: const TextStyle(color: SColors.mut, fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  final String message;
  const _EmptyNotifications({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none_rounded, size: 48, color: SColors.mut),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: SColors.mut)),
          ],
        ),
      ),
    );
  }
}
