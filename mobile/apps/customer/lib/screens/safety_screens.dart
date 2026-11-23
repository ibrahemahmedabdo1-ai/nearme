import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:near_me_core/near_me_core.dart';
import 'package:http/http.dart' as http;

/// Verification: the selfie is uploaded to private storage and reviewed by staff; AI output is advisory only.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  String? _msg;
  bool _busy = false;
  Future<void> _submit() async {
    setState(() { _busy = true; _msg = null; });
    try {
      final img = await ImagePicker().pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front, maxWidth: 1600, imageQuality: 85);
      if (img == null) return;
      final r = await widget.api.post('/api/verification', {'method': 'live_selfie'});
      final put = await http.put(Uri.parse(r['upload_url'] as String), headers: {'content-type': 'image/jpeg'}, body: await img.readAsBytes());
      if (put.statusCode >= 300) throw ApiException(502, 'upload_failed');
      setState(() => _msg = 'تم إرسال طلب التوثيق. سيراجعه فريقنا، وتُحذف الصورة تلقائيًا بعد المراجعة.');
    } catch (e) { setState(() => _msg = errorText(e)); } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('توثيق الحساب')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('التقط صورة سيلفي واضحة. يراجعها فريق الدعم يدويًا؛ الذكاء الاصطناعي استشاري فقط ولا يقرر وحده. تُحذف الصورة بعد المراجعة.'),
          const SizedBox(height: 16),
          GradientButton(label: _busy ? '…' : 'التقط سيلفي وأرسل', onPressed: _busy ? null : _submit),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_msg!)),
        ]),
      );
}

/// Appeal a punishment. Restricted/suspended members re-enter their credentials (their sessions may be revoked).
class AppealScreen extends StatefulWidget {
  const AppealScreen({super.key, required this.api, this.punishmentId});
  final ApiClient api;
  final String? punishmentId;
  @override
  State<AppealScreen> createState() => _AppealScreenState();
}

class _AppealScreenState extends State<AppealScreen> {
  late final _pid = TextEditingController(text: widget.punishmentId ?? '');
  final _email = TextEditingController(), _pw = TextEditingController(), _text = TextEditingController();
  String? _msg;
  Future<void> _send() async {
    try {
      await widget.api.post('/api/appeals', {'punishment_id': _pid.text.trim(), 'text': _text.text.trim(), if (_email.text.isNotEmpty) 'email': _email.text.trim(), if (_pw.text.isNotEmpty) 'password': _pw.text});
      setState(() => _msg = 'تم إرسال اعتراضك. القرار النهائي للمالك.');
    } catch (e) { setState(() => _msg = errorText(e)); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('اعتراض على عقوبة')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _pid, decoration: const InputDecoration(labelText: 'رقم العقوبة')),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'البريد (إن لم تكن مسجّلًا الدخول)')),
          TextField(controller: _pw, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور (إن لم تكن مسجّلًا الدخول)')),
          TextField(controller: _text, maxLines: 5, maxLength: 2000, decoration: const InputDecoration(labelText: 'سبب الاعتراض (10 أحرف على الأقل)')),
          GradientButton(label: 'إرسال', onPressed: _send),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_msg!)),
        ]),
      );
}

/// Contact support (and the child-safety / feedback channel required by Google Play for social/dating apps).
class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  final _s = TextEditingController(), _t = TextEditingController();
  String? _msg;
  Future<void> _send() async {
    try { await widget.api.post('/api/tickets', {'subject': _s.text.trim(), 'text': _t.text.trim()}); setState(() { _msg = 'تم إرسال طلبك. سنرد عليك قريبًا.'; _s.clear(); _t.clear(); }); }
    catch (e) { setState(() => _msg = errorText(e)); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الدعم والملاحظات')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _s, maxLength: 150, decoration: const InputDecoration(labelText: 'الموضوع')),
          TextField(controller: _t, maxLines: 6, maxLength: 4000, decoration: const InputDecoration(labelText: 'التفاصيل')),
          GradientButton(label: 'إرسال', onPressed: _send),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_msg!)),
        ]),
      );
}

/// Incoming likes ("who liked me"): like back to create a match, or pass.
class IncomingLikesScreen extends StatefulWidget {
  const IncomingLikesScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<IncomingLikesScreen> createState() => _IncomingLikesScreenState();
}

class _IncomingLikesScreenState extends State<IncomingLikesScreen> {
  List<Map<String, dynamic>> _likes = [];
  String? _err;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final d = await widget.api.get('/api/likes/incoming'); if (mounted) setState(() => _likes = (d['likes'] as List<dynamic>).cast<Map<String, dynamic>>()); } catch (e) { if (mounted) setState(() => _err = errorText(e)); } }
  Future<void> _answer(Map<String, dynamic> l, String kind) async { try { await widget.api.post('/api/swipes', {'to_user': l['from_user'] ?? l['id'], 'kind': kind}); await _load(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e)))); } }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('أعجبوا بك')),
        body: _err != null ? Center(child: Text(_err!)) : _likes.isEmpty ? const Center(child: Text('لا توجد إعجابات جديدة')) : ListView(children: [
          for (final l in _likes) ListTile(
            leading: const NmIcon('user', size: 40), title: Text('${l['name'] ?? l['display_name']}'), subtitle: Text(l['kind'] == 'super_like' ? 'سوبر لايك ⭐' : 'إعجاب'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.close), onPressed: () => _answer(l, 'pass')), IconButton(icon: const Icon(Icons.favorite), onPressed: () => _answer(l, 'like'))]),
          ),
        ]),
      );
}

/// Security Center: recent sign-ins, security events, signed-in sessions (revocable) and registered devices.
class SecurityCenterScreen extends StatefulWidget {
  const SecurityCenterScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<SecurityCenterScreen> createState() => _SecurityCenterScreenState();
}

class _SecurityCenterScreenState extends State<SecurityCenterScreen> {
  Map<String, dynamic> _sessions = {}, _sec = {};
  String? _err;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final a = await widget.api.get('/api/me/sessions'), b = await widget.api.get('/api/me/security'); if (mounted) setState(() { _sessions = a; _sec = b; }); }
    catch (e) { if (mounted) setState(() => _err = errorText(e)); }
  }
  Future<void> _revoke(String id) async { try { await widget.api.delete('/api/me/sessions/$id'); await _load(); } catch (e) { if (mounted) setState(() => _err = errorText(e)); } }
  @override
  Widget build(BuildContext context) {
    final cur = _sessions['current'];
    return Scaffold(
      appBar: AppBar(title: const Text('مركز الأمان')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_err != null) Text(_err!),
        const Text('الجلسات النشطة', style: TextStyle(fontWeight: FontWeight.w800)),
        for (final s in ((_sessions['sessions'] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>())
          ListTile(title: Text('${s['created_at']}'.split('T').first), subtitle: Text('${s['ip'] ?? ''}'), trailing: s['id'] == cur ? const Chip(label: Text('هذا الجهاز')) : TextButton(onPressed: () => _revoke('${s['id']}'), child: const Text('إنهاء'))),
        const SizedBox(height: 12), const Text('أحداث أمنية', style: TextStyle(fontWeight: FontWeight.w800)),
        for (final e in ((_sec['events'] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>()) ListTile(dense: true, title: Text('${e['kind']}'), subtitle: Text('${e['created_at']}')),
      ]),
    );
  }
}
