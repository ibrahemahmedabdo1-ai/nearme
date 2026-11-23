import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';

/// Edit display name, bio, interests (max 10) and temporarily hide the profile from discovery.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _name = TextEditingController(), _bio = TextEditingController();
  List<Map<String, dynamic>> _all = [];
  final Set<String> _sel = {};
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final me = await widget.api.get('/api/me'), ints = await widget.api.get('/api/interests');
        final u = me['user'] as Map<String, dynamic>;
        if (!mounted) return;
        setState(() { _name.text = '${u['display_name']}'; _bio.text = '${u['bio'] ?? ''}'; _sel.addAll((me['interests'] as List<dynamic>).cast<String>()); _all = (ints['interests'] as List<dynamic>).cast<Map<String, dynamic>>(); });
      } catch (e) { if (mounted) setState(() => _msg = errorText(e)); }
    }();
  }

  Future<void> _save() async {
    setState(() { _busy = true; _msg = null; });
    try {
      await widget.api.patch('/api/me', {'display_name': _name.text.trim(), 'bio': _bio.text.trim()});
      await widget.api.put('/api/me/interests', {'slugs': _sel.toList()});
      if (mounted) Navigator.pop(context);
    } catch (e) { setState(() => _msg = errorText(e)); } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _hide(int? hours) async {
    try { await widget.api.post('/api/me/hide', {'hours': hours}); if (mounted) setState(() => _msg = hours == null ? 'ملفك ظاهر الآن' : 'ملفك مخفي مؤقتًا'); } catch (e) { setState(() => _msg = errorText(e)); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تعديل الملف')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _name, maxLength: 40, decoration: const InputDecoration(labelText: 'الاسم')),
          TextField(controller: _bio, maxLength: 500, maxLines: 4, decoration: const InputDecoration(labelText: 'نبذة عنك')),
          const SizedBox(height: 8), const Text('الاهتمامات (حتى 10)'),
          Wrap(spacing: 8, children: [for (final i in _all) FilterChip(label: Text('${i['name_ar']}'), selected: _sel.contains(i['slug']), onSelected: (v) => setState(() { if (v && _sel.length < 10) { _sel.add(i['slug'] as String); } else if (!v) { _sel.remove(i['slug']); } }))]),
          const SizedBox(height: 16),
          GlassCard(child: Column(children: [
            const ListTile(title: Text('إخفاء ملفي مؤقتًا من الاستكشاف')),
            Wrap(spacing: 8, children: [ActionChip(label: const Text('ساعة'), onPressed: () => _hide(1)), ActionChip(label: const Text('24 ساعة'), onPressed: () => _hide(24)), ActionChip(label: const Text('7 أيام'), onPressed: () => _hide(168)), ActionChip(label: const Text('إظهار'), onPressed: () => _hide(null))]),
          ])),
          if (_msg != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_msg!)),
          const SizedBox(height: 16),
          GradientButton(label: _busy ? '…' : 'حفظ', onPressed: _busy ? null : _save),
        ]),
      );
}
