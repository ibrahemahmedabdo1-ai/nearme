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

/// AdMob placements (Owner): fixed inventory, consent-aware, with configurable frequency and session caps.
class AdsPage extends StatefulWidget {
  const AdsPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<AdsPage> createState() => _AdsPageState();
}

class _AdsPageState extends State<AdsPage> {
  List<Map<String, dynamic>> _placements = [];
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await widget.api.get('/api/admin/ads');
      if (mounted) setState(() => _placements = (d['placements'] as List<dynamic>).cast<Map<String, dynamic>>());
    } catch (e) { if (mounted) setState(() => _error = e is ApiException ? e.code : 'network'); }
    finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _save(Map<String, dynamic> p) async {
    setState(() => _saving = true);
    try {
      await widget.api.put('/api/admin/ads', {'placement': p['placement'], 'enabled': p['enabled'], 'min_gap_sec': p['min_gap_sec'], 'max_per_session': p['max_per_session']});
      if (mounted) toast(context, 'تم حفظ إعدادات ${p['placement']}');
    } catch (e) { if (mounted) toast(context, e is ApiException ? e.code : 'network'); }
    finally { if (mounted) setState(() => _saving = false); }
  }
  @override
  Widget build(BuildContext context) => SubPage(title: 'الإعلانات (AdMob)', child: _loading
      ? const Center(child: CircularProgressIndicator())
      : _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('تعذر تحميل الإعلانات: $_error'), TextButton(onPressed: _load, child: const Text('إعادة المحاولة'))]))
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('أماكن ثابتة فقط. الإعلانات لا تظهر في المحادثات أو التسجيل أو التوثيق أو الدعم أو الأمان.', style: TextStyle(fontSize: 12)),
              for (final p in _placements) Card(margin: const EdgeInsets.only(top: 12), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('${p['placement']} · ${p['format']}'), subtitle: Text(p['enabled'] == true ? 'مفعّل' : 'متوقف'), value: p['enabled'] == true, onChanged: _saving ? null : (v) => setState(() => p['enabled'] = v)),
                Text('الفاصل الأدنى: ${p['min_gap_sec']} ثانية (حد أمان إلزامي: ${p['safety_min_gap_sec']} ثانية)'),
                Slider(
                  value: ((p['min_gap_sec'] as num?)?.toDouble() ?? 120).clamp((p['safety_min_gap_sec'] as num?)?.toDouble() ?? 0, ((p['safety_min_gap_sec'] as num?)?.toDouble() ?? 0) + 3600).toDouble(),
                  min: (p['safety_min_gap_sec'] as num?)?.toDouble() ?? 0,
                  max: ((p['safety_min_gap_sec'] as num?)?.toDouble() ?? 0) + 3600,
                  divisions: 120,
                  label: '${p['min_gap_sec']}ث',
                  onChanged: _saving ? null : (v) => setState(() => p['min_gap_sec'] = (v / 30).round() * 30 < ((p['safety_min_gap_sec'] as num?)?.toInt() ?? 0) ? (p['safety_min_gap_sec'] as num).toInt() : (v / 30).round() * 30),
                ),
                Text('الحد الأقصى لكل جلسة: ${p['max_per_session']} ظهور (سقف الأمان: ${p['safety_max_per_session']})'),
                Slider(
                  value: ((p['max_per_session'] as num?)?.toDouble() ?? 0).clamp(0, (p['safety_max_per_session'] as num?)?.toDouble() ?? 0).toDouble(),
                  min: 0,
                  max: (p['safety_max_per_session'] as num?)?.toDouble() ?? 1,
                  divisions: ((p['safety_max_per_session'] as num?)?.toInt() ?? 1).clamp(1, 20),
                  label: '${p['max_per_session']}',
                  onChanged: _saving ? null : (v) => setState(() => p['max_per_session'] = v.round()),
                ),
                Align(alignment: AlignmentDirectional.centerEnd, child: FilledButton(onPressed: _saving ? null : () => _save(p), child: const Text('حفظ إعدادات المكان'))),
              ]))),
            ]));
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
