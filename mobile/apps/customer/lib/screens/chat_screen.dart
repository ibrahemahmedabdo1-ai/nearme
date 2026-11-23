import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:near_me_core/near_me_core.dart';
import '../media.dart';
import 'chat_media.dart';

/// Chat thread. No ads here by policy (kAdForbiddenScreens contains 'chat_thread').
/// Transport: polling every 4s while visible. A managed realtime provider (Ably/Pusher) can replace the timer via the backend Realtime adapter.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.api, required this.conversation, this.builder = const AppBuilderConfig()});
  final ApiClient api;
  final AppBuilderConfig builder;
  final Map<String, dynamic> conversation;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _msgs = [];
  Timer? _timer;
  String? _banner, _me;
  Map<String, dynamic>? _replyTo;
  Map<String, dynamic> _peer = const {};
  Timer? _typingTimer;
  DateTime _lastTyping = DateTime.fromMillisecondsSinceEpoch(0);
  String get _id => widget.conversation['id'] as String;
  String get _otherId => widget.conversation['other_id'] as String;
  late String _intro = widget.conversation['intro_status'] as String;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() { _timer?.cancel(); WidgetsBinding.instance.removeObserver(this); _c.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) { if (s == AppLifecycleState.paused) { _timer?.cancel(); } else if (s == AppLifecycleState.resumed) { _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load()); _load(); } }

  Future<void> _load() async {
    try {
      final me = await widget.api.get('/api/me');
      _me = (me['user'] as Map<String, dynamic>)['id'] as String;
      final d = await widget.api.get('/api/conversations/$_id/messages');
      final list = (d['messages'] as List<dynamic>).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() { _msgs = list; _peer = (d['peer'] as Map<String, dynamic>?) ?? const {}; });
      for (final m in list) { if (m['sender_id'] != _me && m['read_at'] == null) { widget.api.request('PATCH', '/api/conversations/$_id/messages/${m['id']}', body: {'action': 'read'}).catchError((_) => <String, dynamic>{}); } }
    } on ApiException catch (e) { if (mounted) setState(() => _banner = e.code == 'blocked' ? 'تعذّر عرض المحادثة' : null); }
    catch (_) {/* offline: keep current list */}
  }

  void _onChanged(String _) {
    if (DateTime.now().difference(_lastTyping).inSeconds < 4) return; // throttle typing pings
    _lastTyping = DateTime.now();
    widget.api.post('/api/conversations/$_id/typing', {}).catchError((_) => <String, dynamic>{});
  }

  Future<void> _sendMedia() async {
    final b = widget.builder;
    final r = await showModalBottomSheet<Map<String, dynamic>>(context: context, builder: (_) => MediaPicker(api: widget.api, stickers: b.feature('stickers'), gifs: b.feature('gifs')));
    if (r != null) await _send(kind: r['kind'] as String, text: r['body'] as String);
  }

  Future<void> _sendPhoto() async {
    try {
      final id = await MediaUploader(widget.api).pickAndUpload(source: ImageSource.gallery);
      if (id != null) await _send(kind: 'image', attachmentId: id);
    } catch (e) { if (mounted) setState(() => _banner = errorText(e)); }
  }

  Future<void> _send({String kind = 'text', String? text, String? attachmentId}) async {
    final t = text ?? _c.text.trim();
    if (t.isEmpty && attachmentId == null) return;
    try {
      await widget.api.post('/api/conversations/$_id/messages', {'kind': kind, if (t.isNotEmpty) 'body': t, if (attachmentId != null) 'attachment_id': attachmentId, if (_replyTo != null) 'reply_to': _replyTo!['id']});
      _c.clear(); setState(() { _replyTo = null; _banner = null; });
      await _load();
    } on ApiException catch (e) {
      const m = {'intro_limit_reached': 'وصلت إلى 3 رسائل. انتظر ردّ الطرف الآخر قبل إرسال المزيد.', 'blocked': 'لا يمكن إرسال رسائل لهذا العضو.', 'request_rejected': 'تم رفض طلب التعارف.', 'messaging_restricted': 'إرسال الرسائل مقيّد على حسابك مؤقتًا.', 'service_restricted': 'الخدمة متوقفة مؤقتًا.', 'rate_limited': 'رسائل كثيرة، تمهّل قليلًا.'};
      setState(() => _banner = m[e.code] ?? 'تعذّر الإرسال (${e.code})');
    }
  }

  Future<void> _respond(bool accept) async { await widget.api.post('/api/conversations/$_id/respond', {'accept': accept}); setState(() => _intro = accept ? 'accepted' : 'rejected'); if (!accept && mounted) Navigator.pop(context); }

  void _actions(Map<String, dynamic> m) {
    final mine = m['sender_id'] == _me;
    showModalBottomSheet<void>(context: context, builder: (_) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.reply), title: const Text('رد'), onTap: () { Navigator.pop(context); setState(() => _replyTo = m); }),
      ListTile(leading: const Icon(Icons.copy), title: const Text('نسخ'), onTap: () { Clipboard.setData(ClipboardData(text: '${m['body'] ?? ''}')); Navigator.pop(context); }),
      ListTile(leading: const Icon(Icons.push_pin_outlined), title: Text(m['pinned'] == true ? 'إلغاء التثبيت' : 'تثبيت'), onTap: () { Navigator.pop(context); _patch(m, 'pin', {'pinned': m['pinned'] != true}); }),
      ListTile(leading: const Icon(Icons.add_reaction_outlined), title: const Text('تفاعل ❤️'), onTap: () { Navigator.pop(context); _patch(m, 'react', {'emoji': '❤️'}); }),
      ListTile(leading: const Icon(Icons.delete_outline), title: const Text('حذف عندي'), onTap: () { Navigator.pop(context); _patch(m, 'delete_me', {}); }),
      if (mine) ListTile(leading: const Icon(Icons.delete_forever_outlined), title: const Text('حذف للجميع'), onTap: () { Navigator.pop(context); _patch(m, 'delete_all', {}); }),
      if (!mine) ListTile(leading: const Icon(Icons.flag_outlined), title: const Text('إبلاغ'), onTap: () { Navigator.pop(context); _report(m['id'] as String?); }),
    ])));
  }

  Future<void> _patch(Map<String, dynamic> m, String action, Map<String, dynamic> extra) async {
    try { await widget.api.request('PATCH', '/api/conversations/$_id/messages/${m['id']}', body: {'action': action, ...extra}); await _load(); }
    on ApiException catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == 'delete_window_closed' ? 'انتهت مهلة الحذف للجميع' : 'تعذّر التنفيذ'))); }
  }

  Future<void> _report(String? messageId) async {
    final cat = await showDialog<String>(context: context, builder: (_) => SimpleDialog(title: const Text('سبب الإبلاغ'), children: [for (final e in const {'harassment': 'مضايقة', 'fake_profile': 'حساب مزيف', 'spam': 'رسائل مزعجة', 'nudity': 'محتوى جنسي', 'minor_safety': 'سلامة القُصّر', 'csae': 'استغلال الأطفال', 'scam': 'احتيال', 'other': 'أخرى'}.entries) SimpleDialogOption(onPressed: () => Navigator.pop(context, e.key), child: Text(e.value))]));
    if (cat == null) return;
    await widget.api.post('/api/reports', {'target_user': _otherId, 'category': cat, if (messageId != null) 'message_id': messageId});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال البلاغ. سيراجعه فريقنا.')));
  }

  Future<void> _rate() async {
    final stars = await showDialog<int>(context: context, builder: (_) => SimpleDialog(title: const Text('قيّم هذا العضو'), children: [for (var i = 5; i >= 1; i--) SimpleDialogOption(onPressed: () => Navigator.pop(context, i), child: Text('★' * i))]));
    if (stars == null) return;
    try { await widget.api.post('/api/ratings', {'ratee': _otherId, 'conversation_id': _id, 'stars': stars}); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شكرًا لتقييمك'))); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e)))); }
  }

  Future<void> _gift() async {
    final gifts = const {'gift_rose': '🌹 وردة', 'gift_coffee': '☕ قهوة', 'gift_star': '⭐ نجمة'};
    if (!mounted) return;
    final id = await showDialog<String>(context: context, builder: (_) => SimpleDialog(title: const Text('هدية مجانية'), children: [for (final e in gifts.entries) SimpleDialogOption(onPressed: () => Navigator.pop(context, e.key), child: Text(e.value))]));
    if (id == null) return;
    try { await widget.api.post('/api/gifts', {'to_user': _otherId, 'item_id': id}); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الهدية 🎁'))); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e)))); }
  }

  Future<void> _block() async { await widget.api.post('/api/blocks', {'target_user': _otherId}); if (mounted) Navigator.pop(context); }

  @override
  Widget build(BuildContext context) {
    final pendingForMe = _intro == 'pending' && widget.conversation['initiator'] == _otherId;
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${widget.conversation['other_name']}'), if (_peer['typing'] == true) const Text('يكتب الآن…', style: TextStyle(fontSize: 11)) else if (_peer['online'] == true) const Text('متصل الآن', style: TextStyle(fontSize: 11)) else if (_peer['last_seen_at'] != null) const Text('شوهد مؤخرًا', style: TextStyle(fontSize: 11))]),
        actions: [PopupMenuButton<String>(onSelected: (v) { if (v == 'report') { _report(null); } else if (v == 'rate') { _rate(); } else if (v == 'gift') { _gift(); } else { _block(); } }, itemBuilder: (_) => [if (_intro == 'accepted') const PopupMenuItem(value: 'rate', child: Text('قيّم المحادثة')), if (_intro == 'accepted' && widget.builder.feature('gifts')) const PopupMenuItem(value: 'gift', child: Text('أرسل هدية')), const PopupMenuItem(value: 'report', child: Text('إبلاغ عن العضو')), PopupMenuItem(value: 'block', child: Text('حظر'))])],
      ),
      body: Column(children: [
        if (pendingForMe) Material(color: Theme.of(context).colorScheme.primaryContainer, child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [const Expanded(child: Text('طلب تعارف جديد')), TextButton(onPressed: () => _respond(false), child: const Text('رفض')), FilledButton(onPressed: () => _respond(true), style: FilledButton.styleFrom(minimumSize: const Size(80, 40)), child: const Text('قبول'))]))),
        Expanded(child: ListView.builder(
          controller: _scroll, padding: const EdgeInsets.all(12), itemCount: _msgs.length,
          itemBuilder: (_, i) {
            final m = _msgs[i]; final mine = m['sender_id'] == _me; final cs = Theme.of(context).colorScheme;
            final deleted = m['deleted_for_all_at'] != null;
            return Align(
              alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              child: GestureDetector(
                onLongPress: deleted ? null : () => _actions(m),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .75),
                  decoration: BoxDecoration(color: mine ? cs.primary : cs.surface, borderRadius: BorderRadius.circular(18)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    if (m['pinned'] == true) const Icon(Icons.push_pin, size: 12),
                    if (deleted) const Text('تم حذف هذه الرسالة') else messageContent(context, m, mine ? Colors.white : cs.onSurface, widget.api),
                    if ((m['reactions'] as List<dynamic>? ?? []).isNotEmpty) Text((m['reactions'] as List<dynamic>).map((r) => (r as Map<String, dynamic>)['emoji']).join(' ')),
                    if (mine) Text(m['read_at'] != null ? '✓✓' : (m['delivered_at'] != null ? '✓✓' : '✓'), style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : null)),
                  ]),
                ),
              ),
            );
          },
        )),
        if (_banner != null) Container(width: double.infinity, color: Colors.amber.withValues(alpha: .15), padding: const EdgeInsets.all(8), child: Text(_banner!, style: const TextStyle(fontSize: 12))),
        if (_replyTo != null) ListTile(dense: true, leading: const Icon(Icons.reply), title: Text('${_replyTo!['body'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _replyTo = null))),
        if (_intro != 'rejected') SafeArea(child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
          Expanded(child: TextField(controller: _c, minLines: 1, maxLines: 4, maxLength: 4000, onChanged: _onChanged, decoration: const InputDecoration(hintText: 'اكتب رسالة…', counterText: ''), onSubmitted: (_) => _send())),
          IconButton(onPressed: _sendPhoto, icon: const Icon(Icons.image_outlined)),
          if (widget.builder.feature('stickers') || widget.builder.feature('gifs')) IconButton(onPressed: _sendMedia, icon: const Icon(Icons.emoji_emotions_outlined)),
          const SizedBox(width: 4), IconButton(onPressed: _send, icon: const NmIcon('send', size: 40)),
        ]))),
      ]),
    );
  }
}
