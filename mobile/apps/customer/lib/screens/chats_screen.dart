import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';
import '../app_state.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key, required this.state});
  final AppState state;
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final d = await widget.state.api.get('/api/conversations'); if (mounted) setState(() => _items = d['conversations'] as List<dynamic>); }
    catch (_) {/* keep previous list */}
    finally { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد محادثات بعد.\nأرسل طلب تعارف من Near Me.', textAlign: TextAlign.center)));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsetsDirectional.all(12),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final c = _items[i] as Map<String, dynamic>;
          final pending = c['intro_status'] == 'pending';
          return GlassCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const NmIcon('user', size: 44),
              title: Text('${c['other_name']}'),
              subtitle: Text(pending ? (c['initiator'] == c['other_id'] ? 'طلب تعارف بانتظار ردّك' : 'بانتظار قبول الطرف الآخر') : 'محادثة'),
              trailing: (c['unread'] as int? ?? 0) > 0 ? CircleAvatar(radius: 11, child: Text('${c['unread']}', style: const TextStyle(fontSize: 11))) : null,
              onTap: () async { await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ChatScreen(api: widget.state.api, conversation: c, builder: widget.state.builder))); _load(); },
            ),
          );
        },
      ),
    );
  }
}
