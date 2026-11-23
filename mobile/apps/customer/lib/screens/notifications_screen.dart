import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  String? _err;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final d = await widget.api.get('/api/notifications');
      if (mounted) setState(() => _items = (d['notifications'] as List<dynamic>).cast<Map<String, dynamic>>());
      await widget.api.post('/api/notifications', {}); // mark all read once shown
    } catch (e) { if (mounted) setState(() => _err = errorText(e)); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الإشعارات')),
        body: _err != null ? Center(child: Text(_err!)) : _items.isEmpty ? const Center(child: Text('لا توجد إشعارات')) : ListView(children: [
          for (final n in _items) ListTile(leading: Icon(n['kind'] == 'gift' ? Icons.card_giftcard : n['kind'] == 'occasion' ? Icons.celebration_outlined : Icons.notifications_none, color: n['read_at'] == null ? Theme.of(context).colorScheme.primary : null), title: Text('${n['title']}'), subtitle: n['body'] == null ? null : Text('${n['body']}')),
        ]),
      );
}
