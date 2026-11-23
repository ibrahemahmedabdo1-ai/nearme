import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';
import 'common.dart';

/// Occasions: schedule themed greetings (in-app / push) and see how many were sent.
class OccasionsPage extends StatelessWidget {
  const OccasionsPage({super.key, required this.api});
  final ApiClient api;
  @override
  Widget build(BuildContext context) => SubPage(title: 'المناسبات', child: Builder(builder: (c) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(icon: const Icon(Icons.add), label: const Text('مناسبة'), onPressed: () => _create(c)),
        body: ApiList(api: api, path: '/api/admin/occasions', keyName: 'occasions', tile: (c, o, reload) => ListTile(
          title: Text('${o['name']}'), subtitle: Text('${'${o['starts_at']}'.split('T').first} · داخل التطبيق ${o['in_app_sent']} · إشعارات ${o['push_sent']}'),
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { if (await confirm(c, 'حذف المناسبة؟')) { if (!c.mounted) return; await run(c, () => api.delete('/api/admin/occasions/${o['id']}')); await reload(); } }),
        )),
      )));

  Future<void> _create(BuildContext c) async {
    final name = TextEditingController(), ar = TextEditingController(), en = TextEditingController();
    var start = DateTime.now(), push = false;
    final ok = await showDialog<bool>(context: c, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: const Text('مناسبة جديدة'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
        TextField(controller: ar, maxLength: 300, decoration: const InputDecoration(labelText: 'الرسالة بالعربية')),
        TextField(controller: en, maxLength: 300, decoration: const InputDecoration(labelText: 'Message in English')),
        ListTile(dense: true, title: Text('البداية: ${start.toIso8601String().split('T').first}'), onTap: () async { final d = await showDatePicker(context: ctx, initialDate: start, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730))); if (d != null) set(() => start = d); }),
        SwitchListTile(dense: true, title: const Text('إرسال إشعار Push (لمن فعّله)'), value: push, onChanged: (v) => set(() => push = v)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء'))],
    )));
    if (ok == true && c.mounted) await run(c, () => api.post('/api/admin/occasions', {'name': name.text.trim(), 'starts_at': start.toUtc().toIso8601String(), 'ends_at': start.add(const Duration(days: 1)).toUtc().toIso8601String(), 'message': {'ar': ar.text.trim(), 'en': en.text.trim()}, 'send_push': push}));
  }
}

/// AdMob placements (Owner): enable/disable and tune frequency. Only fixed placements exist; never on chat/auth/safety screens.
class AdsPage extends StatelessWidget {
  const AdsPage({super.key, required this.api});
  final ApiClient api;
  @override
  Widget build(BuildContext context) => SubPage(title: 'الإعلانات (AdMob)', child: ApiList(api: api, path: '/api/admin/ads', keyName: 'placements', tile: (c, p, reload) => SwitchListTile(
        title: Text('${p['placement']} · ${p['format']}'), subtitle: Text('الفاصل الأدنى ${p['min_gap_sec']}ث · حد الجلسة ${p['max_per_session']}'), value: p['enabled'] == true,
        onChanged: (v) async { await run(c, () => api.put('/api/admin/ads', {'placement': p['placement'], 'enabled': v})); await reload(); },
      )));
}

/// Matching weights (Admin+): how much each factor counts in the compatibility score.
class WeightsPage extends StatefulWidget {
  const WeightsPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<WeightsPage> createState() => _WeightsPageState();
}

class _WeightsPageState extends State<WeightsPage> {
  Map<String, double> _w = {};
  @override
  void initState() { super.initState(); run(context, () => widget.api.get('/api/admin/matching-weights')).then((d) { if (d != null && mounted) setState(() => _w = (d['weights'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()))); }); }
  @override
  Widget build(BuildContext context) => SubPage(title: 'أوزان التوافق', child: ListView(padding: const EdgeInsets.all(16), children: [
        for (final k in _w.keys) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$k: ${_w[k]!.round()}'), Slider(value: _w[k]!, min: 0, max: 100, divisions: 20, onChanged: (v) => setState(() => _w[k] = v))]),
        FilledButton(onPressed: () async { final r = await run(context, () => widget.api.put('/api/admin/matching-weights', {for (final e in _w.entries) e.key: e.value.round()})); if (r != null && mounted) toast(context, 'تم الحفظ'); }, child: const Text('حفظ')),
      ]));
}

/// Releases: list, publish a version, mark a minimum required version (forced update). Owner only.
class ReleasesPage extends StatelessWidget {
  const ReleasesPage({super.key, required this.api});
  final ApiClient api;
  @override
  Widget build(BuildContext context) => SubPage(title: 'الإصدارات', child: Builder(builder: (c) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(icon: const Icon(Icons.rocket_launch), label: const Text('إصدار'), onPressed: () async {
          final name = TextEditingController(), code = TextEditingController(); var minReq = false, forced = false;
          final ok = await showDialog<bool>(context: c, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(title: const Text('إصدار جديد'), content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'رقم الإصدار (1.0.1)')), TextField(controller: code, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'version code')),
            SwitchListTile(dense: true, title: const Text('حد أدنى مطلوب'), value: minReq, onChanged: (v) => set(() => minReq = v)), SwitchListTile(dense: true, title: const Text('تحديث أمني إجباري'), value: forced, onChanged: (v) => set(() => forced = v))]),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء'))])));
          if (ok == true && c.mounted) await run(c, () => api.post('/api/admin/releases', {'version_name': name.text.trim(), 'version_code': int.tryParse(code.text) ?? 0, 'min_required': minReq, 'forced_security': forced}));
        }),
        body: Column(children: [
          FutureBuilder<Map<String, dynamic>>(future: api.get('/api/admin/releases/compat'), builder: (_, s) => s.hasData ? Padding(padding: const EdgeInsets.all(12), child: Text('ترحيلات قاعدة البيانات المطبّقة: ${(s.data!['migrations'] as List<dynamic>).length} · أقل نسخة مطلوبة: ${s.data!['min_required_version_code'] ?? '—'}')) : const SizedBox()),
          Expanded(child: ApiList(api: api, path: '/api/admin/releases', keyName: 'releases', tile: (c, r, _) => ListTile(title: Text('${r['version_name']} (${r['version_code']})'), subtitle: Text('${r['min_required'] == true ? 'حد أدنى · ' : ''}${r['forced_security'] == true ? 'إجباري أمني · ' : ''}${r['rollout_percent']}%'))))
        ]),
      )));
}

/// Backups (Owner): record a request; restore needs a typed confirmation and a fresh 2FA code. Files are produced by scripts/backup.sh.
class BackupsPage extends StatelessWidget {
  const BackupsPage({super.key, required this.api});
  final ApiClient api;
  @override
  Widget build(BuildContext context) => SubPage(title: 'النسخ الاحتياطي', child: Builder(builder: (c) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(icon: const Icon(Icons.backup), label: const Text('طلب نسخة'), onPressed: () async { final r = await run(c, () => api.post('/api/admin/backups', {'scope': 'database'})); if (r != null && c.mounted) toast(c, '${r['next']}'); }),
        body: ApiList(api: api, path: '/api/admin/backups', keyName: 'backups', tile: (c, b, reload) => ListTile(
          title: Text('${b['scope']} · ${b['status']}'), subtitle: Text('${b['created_at']}'),
          trailing: TextButton(child: const Text('تفويض استعادة'), onPressed: () async {
            final typed = await askText(c, 'اكتب: RESTORE ${b['id']}'); if (typed == null || !c.mounted) return;
            final code = await askText(c, 'رمز 2FA الحالي'); if (code == null || !c.mounted) return;
            final r = await run(c, () => api.post('/api/admin/backups/${b['id']}/restore', {'confirm': typed, 'totp': code}));
            if (r != null && c.mounted) toast(c, '${r['next']}'); await reload();
          }),
        )),
      )));
}

/// Owner security: rotate 2FA and issue one-time recovery codes (shown once).
class OwnerSecurityPage extends StatelessWidget {
  const OwnerSecurityPage({super.key, required this.api});
  final ApiClient api;
  @override
  Widget build(BuildContext context) => SubPage(title: 'أمان المالك', child: Builder(builder: (c) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('تدوير سر 2FA وإصدار 10 رموز استرداد تُستخدم مرة واحدة. الرموز القديمة تُلغى.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: () async {
          final pw = await askText(c, 'كلمة المرور الحالية', obscure: true); if (pw == null || !c.mounted) return;
          final code = await askText(c, 'رمز 2FA الحالي'); if (code == null || !c.mounted) return;
          final r = await run(c, () => api.post('/api/admin/owner/credentials', {'password': pw, 'totp': code}));
          if (r != null && c.mounted) await showDialog<void>(context: c, barrierDismissible: false, builder: (_) => AlertDialog(title: const Text('احفظها الآن — لن تظهر مرة أخرى'), content: SelectableText('سر 2FA الجديد:\n${r['totp_secret']}\n\nرموز الاسترداد:\n${(r['recovery_codes'] as List<dynamic>).join('\n')}'), actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('تم الحفظ'))]));
        }, child: const Text('تدوير 2FA وإصدار رموز استرداد')),
      ])));
}
