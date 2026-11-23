import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';
import 'common.dart';

/// Moderation hub: reports, appeals (Owner decision is final), verification review, AI findings (advisory) and recommendations.
class ModerationPage extends StatelessWidget {
  const ModerationPage({super.key, required this.api});
  final ApiClient api;
  @override
  Widget build(BuildContext context) => DefaultTabController(length: 5, child: Column(children: [
        const TabBar(isScrollable: true, tabs: [Tab(text: 'البلاغات'), Tab(text: 'الاعتراضات'), Tab(text: 'التوثيق'), Tab(text: 'تنبيهات AI'), Tab(text: 'التوصيات')]),
        Expanded(child: TabBarView(children: [_reports(), _appeals(), _verifications(), _findings(), _recs()])),
      ]));

  Widget _reports() => ApiList(api: api, path: '/api/admin/reports', keyName: 'reports', tile: (c, r, reload) => ListTile(
        leading: Icon(r['category'] == 'csae' || r['category'] == 'minor_safety' ? Icons.warning_amber_rounded : Icons.flag_outlined, color: r['category'] == 'csae' ? Colors.red : null),
        title: Text('${r['target_name']} · ${r['category']}'), subtitle: Text('${r['details'] ?? ''}'),
        trailing: PopupMenuButton<String>(onSelected: (v) async {
          if (v == 'reviewing' || v == 'dismissed') { await run(c, () => api.post('/api/admin/reports/${r['id']}', {'status': v})); }
          else if (v == 'warn') { final reason = await askText(c, 'سبب التحذير'); if (reason != null && reason.length >= 3 && c.mounted) await run(c, () => api.post('/api/admin/punishments', {'user_id': r['target_user'], 'kind': 'warning', 'reason': reason, 'points': 3, 'report_id': r['id']})); }
          await reload();
        }, itemBuilder: (_) => const [PopupMenuItem(value: 'reviewing', child: Text('قيد المراجعة')), PopupMenuItem(value: 'warn', child: Text('تحذير')), PopupMenuItem(value: 'dismissed', child: Text('رفض'))]),
      ));

  Widget _appeals() => ApiList(api: api, path: '/api/admin/appeals', keyName: 'appeals', tile: (c, a, reload) => ListTile(
        title: Text('${a['display_name']} · ${a['kind']}'), subtitle: Text('${a['reason']}\n«${a['text']}»'), isThreeLine: true,
        trailing: PopupMenuButton<String>(onSelected: (v) async { if (await confirm(c, v == 'overturned' ? 'إلغاء العقوبة؟' : 'تثبيت العقوبة؟')) { if (!c.mounted) return; await run(c, () => api.post('/api/admin/appeals/${a['id']}', {'decision': v})); await reload(); } },
            itemBuilder: (_) => const [PopupMenuItem(value: 'overturned', child: Text('إلغاء العقوبة')), PopupMenuItem(value: 'upheld', child: Text('تثبيت العقوبة'))]),
      ));

  Widget _verifications() => ApiList(api: api, path: '/api/admin/verifications?status=pending', keyName: 'verifications', tile: (c, v, reload) => ListTile(
        leading: const NmIcon('shield', size: 36), title: Text('${v['display_name']} · ${v['method']}'),
        subtitle: Text(v['ai_confidence'] == null ? 'لا يوجد تحليل AI' : 'AI (استشاري): ${v['ai_confidence']}'),
        trailing: PopupMenuButton<String>(onSelected: (a) async {
          final r = await run(c, () => api.post('/api/admin/verifications/${v['id']}', {'action': a}));
          if (a == 'evidence' && r != null && c.mounted) await showDialog<void>(context: c, builder: (_) => AlertDialog(title: const Text('رابط مؤقت (60 ثانية)'), content: SelectableText('${r['url']}')));
          await reload();
        }, itemBuilder: (_) => const [PopupMenuItem(value: 'evidence', child: Text('عرض الدليل (مسجّل)')), PopupMenuItem(value: 'analyze', child: Text('تحليل AI')), PopupMenuItem(value: 'support_review', child: Text('تمت مراجعة الدعم')), PopupMenuItem(value: 'approve', child: Text('قبول')), PopupMenuItem(value: 'reject', child: Text('رفض'))]),
      ));

  Widget _findings() => ApiList(api: api, path: '/api/admin/ai-findings', keyName: 'findings', empty: 'لا توجد تنبيهات', tile: (c, f, reload) => ListTile(
        title: Text('${f['kind']} · ${f['confidence']}'), subtitle: Text('${(f['reason_codes'] as List<dynamic>).join(', ')}\nاستشاري: لا يُعاقَب أحد تلقائيًا'),
        trailing: PopupMenuButton<String>(onSelected: (s) async { await run(c, () => api.patch('/api/admin/ai-findings/${f['id']}', {'status': s})); await reload(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'confirmed', child: Text('تأكيد')), PopupMenuItem(value: 'dismissed', child: Text('تجاهل'))]),
      ));

  Widget _recs() => ApiList(api: api, path: '/api/admin/recommendations', keyName: 'recommendations', tile: (c, r, reload) => ListTile(
        title: Text('${r['recommended']}'), subtitle: Text('${r['note']}'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.check), onPressed: () async { await run(c, () => api.patch('/api/admin/recommendations/${r['id']}', {'status': 'accepted'})); toast(c, 'سُجّل القرار. طبّق الإجراء من العقوبات.'); await reload(); }),
          IconButton(icon: const Icon(Icons.close), onPressed: () async { await run(c, () => api.patch('/api/admin/recommendations/${r['id']}', {'status': 'declined'})); await reload(); }),
        ]),
      ));
}
