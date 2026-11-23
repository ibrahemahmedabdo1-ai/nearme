import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';
import 'common.dart';

/// Marketing Center: accounts (official OAuth only), posts with approval workflow, campaigns (paid needs Owner authorization), AI studio.
class MarketingPage extends StatelessWidget {
  const MarketingPage({super.key, required this.api, required this.isOwner});
  final ApiClient api;
  final bool isOwner;
  @override
  Widget build(BuildContext context) => DefaultTabController(length: 4, child: Column(children: [
        const TabBar(isScrollable: true, tabs: [Tab(text: 'الحسابات'), Tab(text: 'المنشورات'), Tab(text: 'الحملات'), Tab(text: 'استوديو AI')]),
        Expanded(child: TabBarView(children: [_accounts(), _posts(), _campaigns(), _AiStudio(api: api)])),
      ]));

  Widget _accounts() => Builder(builder: (context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(icon: const Icon(Icons.link), label: const Text('ربط حساب'), onPressed: () async {
          final p = await showDialog<String>(context: context, builder: (_) => SimpleDialog(title: const Text('المنصة'), children: [for (final x in const ['facebook', 'instagram', 'tiktok', 'x']) SimpleDialogOption(onPressed: () => Navigator.pop(context, x), child: Text(x))]));
          if (p == null || !context.mounted) return;
          final r = await run(context, () => api.post('/api/admin/marketing/accounts/link', {'platform': p}));
          if (r != null && context.mounted) await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('افتح الرابط لتسجيل الدخول الرسمي'), content: SelectableText('${r['authorize_url']}')));
        }),
        body: ApiList(api: api, path: '/api/admin/marketing/accounts', keyName: 'accounts', tile: (c, a, reload) => ListTile(leading: const Icon(Icons.public), title: Text('${a['platform']} · ${a['display_name'] ?? a['external_id']}'), subtitle: Text('${a['status']}')),
        ),
      ));

  Widget _posts() => ApiList(api: api, path: '/api/admin/marketing/posts', keyName: 'posts', tile: (c, p, reload) {
        final st = '${p['status']}';
        return ListTile(
          title: Text('${(p['body'] as Map<String, dynamic>)['text']}', maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('${p['platform']} · $st${st == 'blocked_no_api_access' ? ' (واجهة المنصة غير مفعّلة؛ لم يُنشر)' : ''}'),
          trailing: PopupMenuButton<String>(onSelected: (a) async { await run(c, () => api.patch('/api/admin/marketing/posts/${p['id']}', {'action': a})); await reload(); }, itemBuilder: (_) => [
            if (st == 'draft') const PopupMenuItem(value: 'submit', child: Text('إرسال للموافقة')),
            if (st == 'pending_approval' && isOwner) const PopupMenuItem(value: 'approve', child: Text('موافقة (المالك)')),
            if (st != 'draft' && st != 'published') const PopupMenuItem(value: 'revert', child: Text('إرجاع لمسودة')),
          ]),
        );
      });

  Widget _campaigns() => Builder(builder: (context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(icon: const Icon(Icons.add), label: const Text('حملة'), onPressed: () async {
          final name = await askText(context, 'اسم الحملة'); if (name == null || name.length < 2 || !context.mounted) return;
          final paid = await confirm(context, 'حملة مدفوعة؟', body: 'الحملات المدفوعة تبقى مسودة حتى يوافق المالك. لا يُنفَق أي مبلغ تلقائيًا.');
          if (!context.mounted) return; await run(context, () => api.post('/api/admin/marketing/campaigns', {'name': name, 'kind': paid ? 'paid' : 'organic'}));
        }),
        body: ApiList(api: api, path: '/api/admin/marketing/campaigns', keyName: 'campaigns', tile: (c, k, reload) => ListTile(
          title: Text('${k['name']} · ${k['kind']}'), subtitle: Text('${k['status']} · منشورات ${k['posts']} · منشورة ${k['published']} · موقوفة ${k['blocked']}'),
          trailing: k['kind'] == 'paid' && k['status'] == 'draft' && isOwner ? TextButton(onPressed: () async { if (await confirm(c, 'اعتماد الحملة المدفوعة؟')) { if (!c.mounted) return; await run(c, () => api.post('/api/admin/marketing/campaigns/${k['id']}/authorize', {})); await reload(); } }, child: const Text('اعتماد')) : null,
        )),
      ));
}

class _AiStudio extends StatefulWidget {
  const _AiStudio({required this.api});
  final ApiClient api;
  @override
  State<_AiStudio> createState() => _AiStudioState();
}

class _AiStudioState extends State<_AiStudio> {
  final _t = TextEditingController();
  String? _out;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('اقتراحات استشارية يراجعها إنسان قبل أي نشر.'),
        TextField(controller: _t, maxLines: 4, decoration: const InputDecoration(labelText: 'فكرة المنشور أو بيانات الحملة')),
        Row(children: [
          FilledButton(onPressed: () async { final r = await run(context, () => widget.api.post('/api/admin/marketing/ai', {'task': 'draft_post', 'input': _t.text})); if (r != null) setState(() => _out = '${r['result']}'); }, child: const Text('صياغة منشور')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () async { final r = await run(context, () => widget.api.post('/api/admin/marketing/ai', {'task': 'analyze_campaign', 'input': _t.text})); if (r != null) setState(() => _out = '${r['result']}'); }, child: const Text('تحليل حملة')),
        ]),
        if (_out != null) Padding(padding: const EdgeInsets.only(top: 12), child: SelectableText(_out!)),
      ]);
}
