import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';
import '../ads.dart';
import '../app_state.dart';
import 'profile_edit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});
  final AppState state;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _me;
  List<Map<String, dynamic>> _people = [];
  List<dynamic> _myInterests = [];
  bool _loading = true;
  String? _error;
  final Set<String> _working = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.state.api.get('/api/me'),
        widget.state.api.get('/api/discover?radius=all'),
      ]);
      final meData = results[0];
      final discovery = results[1];
      if (!mounted) return;
      setState(() {
        _me = meData['user'] as Map<String, dynamic>?;
        _myInterests = (meData['interests'] as List<dynamic>? ?? <dynamic>[]);
        _people = (discovery['results'] as List<dynamic>).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _swipe(Map<String, dynamic> person, String kind) async {
    final id = person['id'] as String;
    setState(() => _working.add(id));
    try {
      await widget.state.api.post('/api/swipes', {'to_user': id, 'kind': kind});
      if (mounted) setState(() => _people.removeWhere((p) => p['id'] == id));
      if (kind == 'like' && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الإعجاب')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally { if (mounted) setState(() => _working.remove(id)); }
  }

  void _editProfile() => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ProfileEditScreen(api: widget.state.api))).then((_) => _load());

  @override
  Widget build(BuildContext context) {
    final name = _me?['display_name']?.toString() ?? '';
    final bio = _me?['bio']?.toString() ?? '';
    final interests = _myInterests;
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('أهلاً ${name.isEmpty ? 'بك' : name} 👋', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('اكتشف أشخاصًا يشاركونك اهتماماتك'),
            ])),
            IconButton(onPressed: _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 16),
          GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.person_pin_circle_outlined), const SizedBox(width: 8), const Expanded(child: Text('ملفك الشخصي', style: TextStyle(fontWeight: FontWeight.w800))), TextButton(onPressed: _editProfile, child: const Text('إكمال / تعديل'))]),
            Text(bio.isEmpty ? 'أضف نبذة قصيرة واهتماماتك ليصبح ملفك أكثر اكتمالًا.' : bio, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              _tag('الاسم: ${name.isEmpty ? 'غير مكتمل' : 'مكتمل'}'),
              _tag('الاهتمامات: ${interests.length}'),
              _tag('النبذة: ${bio.isEmpty ? 'أضف نبذة' : 'مكتملة'}'),
            ]),
          ])),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Text('أشخاص قد يناسبونك', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
            if (!_loading) Text('${_people.length}'),
          ]),
          const SizedBox(height: 10),
          if (_loading) const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
          if (!_loading && _error != null) GlassCard(child: Column(children: [
            const Text('لم نتمكن من تحميل الصفحة الرئيسية.'),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: cs.error, fontSize: 12)),
            TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
          ])),
          if (!_loading && _error == null && _people.isEmpty) GlassCard(child: Column(children: [
            const Icon(Icons.people_outline, size: 42),
            const SizedBox(height: 8),
            const Text('لا توجد اقتراحات متاحة حاليًا', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('ستظهر الحسابات المناسبة هنا بمجرد توفر أعضاء آخرين. أكمل ملفك وجرّب تحديث الصفحة لاحقًا.', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _editProfile, icon: const Icon(Icons.edit_outlined), label: const Text('أكمل ملفك الشخصي')),
          ])),
          for (final p in _people) _personCard(p),
          const SizedBox(height: 12),
          const GlassCard(child: Text('تحدي اليوم: أرسل 3 تحيات واكسب مكافأة غير نقدية.')),
          const SizedBox(height: 12),
          const NmBanner(screen: 'home'),
        ],
      ),
    );
  }

  Widget _tag(String text) => Chip(label: Text(text, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero);

  Widget _personCard(Map<String, dynamic> p) {
    final id = p['id'] as String;
    final name = p['name']?.toString() ?? 'عضو';
    final interests = (p['interests'] as List<dynamic>? ?? []).map((e) => e.toString()).take(4).toList();
    final busy = _working.contains(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 26, child: Text(name.isEmpty ? '?' : name.characters.first, style: const TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$name${p['age'] == null ? '' : ', ${p['age']} سنة'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('${p['compatibility'] ?? 0}% توافق${p['verified'] == true ? ' · موثّق' : ''}', style: const TextStyle(fontSize: 12)),
          ])),
          if (p['boosted'] == true) const Icon(Icons.rocket_launch, size: 18),
        ]),
        if ((p['bio'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(p['bio'].toString(), maxLines: 3, overflow: TextOverflow.ellipsis)),
        if (interests.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 4, children: [for (final i in interests) Chip(label: Text(i, style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact)])),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: busy ? null : () => _swipe(p, 'pass'), icon: const Icon(Icons.close), label: const Text('تخطي'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton.icon(onPressed: busy ? null : () => _swipe(p, 'like'), icon: const Icon(Icons.favorite_border), label: const Text('إعجاب'))),
        ]),
      ])),
    );
  }
}
