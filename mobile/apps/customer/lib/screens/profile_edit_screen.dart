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
  String _gender = 'prefer_not_to_say';
  final Set<String> _preferredGenders = {};
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final results = await Future.wait([widget.api.get('/api/me'), widget.api.get('/api/interests'), widget.api.get('/api/me/preferences')]);
        final me = results[0], ints = results[1], prefs = results[2]['preferences'] as Map<String, dynamic>;
        final u = me['user'] as Map<String, dynamic>;
        if (!mounted) return;
        setState(() { _name.text = '${u['display_name']}'; _bio.text = '${u['bio'] ?? ''}'; _gender = (u['gender'] as String?) ?? 'prefer_not_to_say'; _preferredGenders.addAll((prefs['genders'] as List<dynamic>? ?? const []).cast<String>()); _sel.addAll((me['interests'] as List<dynamic>).cast<String>()); _all = (ints['interests'] as List<dynamic>).cast<Map<String, dynamic>>(); });
      } catch (e) { if (mounted) setState(() => _msg = errorText(e)); }
    }();
  }

  Future<void> _save() async {
    setState(() { _busy = true; _msg = null; });
    try {
      await widget.api.patch('/api/me', {'display_name': _name.text.trim(), 'bio': _bio.text.trim(), 'gender': _gender});
      await widget.api.put('/api/me/interests', {'slugs': _sel.toList()});
      await widget.api.put('/api/me/preferences', {'genders': _preferredGenders.toList()});
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
          DropdownButtonFormField<String>(value: const ['male','female','other','prefer_not_to_say'].contains(_gender) ? _gender : 'prefer_not_to_say', decoration: const InputDecoration(labelText: 'النوع'), items: const [DropdownMenuItem(value: 'male', child: Text('ذكر')), DropdownMenuItem(value: 'female', child: Text('أنثى')), DropdownMenuItem(value: 'other', child: Text('آخر')), DropdownMenuItem(value: 'prefer_not_to_say', child: Text('أفضل عدم التحديد'))], onChanged: (v) => setState(() => _gender = v ?? _gender)),
          const SizedBox(height: 12),
          const Text('الأشخاص الذين تريد اكتشافهم'),
          const Text('عدم اختيار نوع يعني عرض جميع الأنواع المتاحة.'),
          Wrap(spacing: 8, children: [for (final g in const {'male':'أولاد','female':'بنات','other':'آخر'}.entries) FilterChip(label: Text(g.value), selected: _preferredGenders.contains(g.key), onSelected: (v) => setState(() { if (v) { _preferredGenders.add(g.key); } else { _preferredGenders.remove(g.key); } }))]),
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
