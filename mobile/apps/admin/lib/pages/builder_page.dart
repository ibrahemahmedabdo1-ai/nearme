import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';
import 'common.dart';

/// Visual App Builder: edit theme, tab labels, feature toggles and texts with a live preview, save a draft, publish, roll back.
/// DATA ONLY: the server rejects executable content and the Customer app only reads known keys.
class BuilderPage extends StatefulWidget {
  const BuilderPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<BuilderPage> createState() => _BuilderPageState();
}

class _BuilderPageState extends State<BuilderPage> {
  String? _theme;
  final Map<String, TextEditingController> _tabs = {for (final k in AppBuilderConfig.defaultTabs.keys) k: TextEditingController()};
  final Map<String, bool> _features = {for (final k in AppBuilderConfig.featureKeys) k: true};
  final _welcomeTitle = TextEditingController(), _welcomeSub = TextEditingController();
  List<Map<String, dynamic>> _versions = [];
  int? _draftId;

  @override
  void initState() { super.initState(); _loadVersions(); }

  AppBuilderConfig _current() => AppBuilderConfig(
        themeId: _theme,
        tabs: {for (final e in _tabs.entries) if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim()},
        features: Map.of(_features),
        texts: {if (_welcomeTitle.text.trim().isNotEmpty) 'welcome_title': _welcomeTitle.text.trim(), if (_welcomeSub.text.trim().isNotEmpty) 'welcome_subtitle': _welcomeSub.text.trim()},
      );

  void _apply(AppBuilderConfig c) {
    _theme = c.themeId;
    for (final e in _tabs.entries) { e.value.text = c.tabs[e.key] ?? ''; }
    for (final k in AppBuilderConfig.featureKeys) { _features[k] = c.feature(k); }
    _welcomeTitle.text = c.texts['welcome_title'] ?? ''; _welcomeSub.text = c.texts['welcome_subtitle'] ?? '';
  }

  Future<void> _loadVersions() async {
    final d = await run(context, () => widget.api.get('/api/admin/config?scope=app'));
    if (d == null || !mounted) return;
    final v = (d['versions'] as List<dynamic>).cast<Map<String, dynamic>>();
    final live = v.where((x) => x['state'] == 'published').toList();
    setState(() { _versions = v; if (live.isNotEmpty) _apply(AppBuilderConfig.fromJson(live.first['payload'])); });
  }

  Future<void> _save({bool publish = false}) async {
    final r = await run(context, () => widget.api.post('/api/admin/config', {'action': 'draft', 'scope': 'app', 'payload': _current().toJson()}));
    if (r == null || !mounted) return;
    _draftId = r['id'] as int;
    if (publish) {
      if (!await confirm(context, 'نشر التغييرات لكل المستخدمين؟', body: 'يمكن التراجع من سجل الإصدارات.')) return;
      if (!mounted) return;
      await run(context, () => widget.api.post('/api/admin/config', {'action': 'publish', 'scope': 'app', 'id': _draftId}));
      toast(context, 'تم النشر');
    } else { toast(context, 'تم حفظ المسودة'); }
    await _loadVersions();
  }

  Future<void> _rollback(int id) async {
    if (!await confirm(context, 'استرجاع هذا الإصدار؟')) return;
    if (!mounted) return;
    await run(context, () => widget.api.post('/api/admin/config', {'action': 'rollback', 'scope': 'app', 'id': id}));
    await _loadVersions();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _current();
    final theme = themeById(_theme ?? 'midnight_violet');
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('معاينة', style: TextStyle(fontWeight: FontWeight.w800)),
      _Preview(cfg: cfg, theme: theme),
      const SizedBox(height: 16),
      const Text('الثيم', style: TextStyle(fontWeight: FontWeight.w800)),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final t in kThemes) ChoiceChip(avatar: CircleAvatar(backgroundColor: t.primary, radius: 8), label: Text(t.nameAr), selected: _theme == t.id, onSelected: (_) => setState(() => _theme = t.id))]),
      const SizedBox(height: 16), const Text('أسماء التبويبات', style: TextStyle(fontWeight: FontWeight.w800)),
      for (final e in _tabs.entries) TextField(controller: e.value, maxLength: 24, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: AppBuilderConfig.defaultTabs[e.key])),
      const SizedBox(height: 8), const Text('الميزات', style: TextStyle(fontWeight: FontWeight.w800)),
      for (final k in AppBuilderConfig.featureKeys) SwitchListTile(dense: true, title: Text(k), value: _features[k] ?? true, onChanged: (v) => setState(() => _features[k] = v)),
      const SizedBox(height: 8), const Text('النصوص', style: TextStyle(fontWeight: FontWeight.w800)),
      TextField(controller: _welcomeTitle, maxLength: 120, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'عنوان الترحيب')),
      TextField(controller: _welcomeSub, maxLength: 120, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'وصف الترحيب')),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: OutlinedButton(onPressed: () => _save(), child: const Text('حفظ مسودة'))), const SizedBox(width: 8), Expanded(child: FilledButton(onPressed: () => _save(publish: true), child: const Text('حفظ ونشر')))]),
      const SizedBox(height: 20), const Text('سجل الإصدارات', style: TextStyle(fontWeight: FontWeight.w800)),
      for (final v in _versions) ListTile(dense: true, title: Text('#${v['id']} · ${v['state']}'), subtitle: Text('${v['created_at']}'.split('T').first), trailing: v['state'] == 'published' ? const Icon(Icons.check_circle) : TextButton(onPressed: () => _rollback(v['id'] as int), child: const Text('استرجاع'))),
    ]);
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.cfg, required this.theme});
  final AppBuilderConfig cfg;
  final NearMeTheme theme;
  @override
  Widget build(BuildContext context) => Theme(
        data: theme.build(Brightness.dark),
        child: Builder(builder: (c) => Container(
          height: 190, decoration: BoxDecoration(color: Theme.of(c).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.primary.withValues(alpha: .5))),
          child: Column(children: [
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(cfg.text('welcome_title', 'NEAR ME'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: theme.primary)),
              Text(cfg.text('welcome_subtitle', 'تعرّف على من حولك'), style: const TextStyle(fontSize: 12)),
            ]))),
            Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: theme.primary.withValues(alpha: .12), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (final k in ['chats', 'home', 'near', 'profile']) Text(cfg.tab(k), style: const TextStyle(fontSize: 11))])),
          ]),
        )),
      );
}
