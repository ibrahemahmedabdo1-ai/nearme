import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:near_me_core/near_me_core.dart';
import 'common.dart';

/// Owner only: create admin/support accounts, grant/revoke extra permissions (owner-only ones are never offered), disable, revoke sessions.
class StaffPage extends StatelessWidget {
  const StaffPage({super.key, required this.api});
  final ApiClient api;
  static const grantable = ['tickets.read', 'tickets.reply', 'users.read', 'users.moderate', 'verification.review', 'verification.approve', 'reports.review', 'punish.warn', 'punish.suspend', 'punish.ban', 'analytics.read', 'config.edit', 'themes.edit', 'occasions.edit', 'ads.config', 'marketing.manage', 'security.view'];

  Future<void> _create(BuildContext c, Future<void> Function() reload) async {
    final email = TextEditingController(), name = TextEditingController(); var role = 'support';
    final ok = await showDialog<bool>(context: c, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: const Text('حساب موظف جديد'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: email, decoration: const InputDecoration(labelText: 'البريد')), TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
        DropdownButton<String>(value: role, items: const [DropdownMenuItem(value: 'support', child: Text('دعم')), DropdownMenuItem(value: 'admin', child: Text('مدير'))], onChanged: (v) => set(() => role = v!))]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء'))],
    )));
    if (ok != true || !c.mounted) return;
    final r = await run(c, () => api.post('/api/admin/staff', {'email': email.text.trim(), 'display_name': name.text.trim(), 'role': role}));
    if (r == null || !c.mounted) return;
    await showDialog<void>(context: c, barrierDismissible: false, builder: (_) => AlertDialog(
      title: const Text('بيانات الدخول (تظهر مرة واحدة فقط)'),
      content: SelectableText('كلمة المرور: ${r['initial_password']}\nسر 2FA: ${r['totp_secret']}\n\nأضف السر إلى تطبيق مصادقة. لن تُعرض مرة أخرى.'),
      actions: [TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: 'كلمة المرور: ${r['initial_password']}\nسر 2FA: ${r['totp_secret']}')), child: const Text('نسخ')), FilledButton(onPressed: () => Navigator.pop(c), child: const Text('تم الحفظ'))],
    ));
    await reload();
  }

  Future<void> _permissions(BuildContext c, Map<String, dynamic> s, Future<void> Function() reload) async {
    final sel = <String>{...((s['extra_permissions'] as List<dynamic>?) ?? const []).cast<String>()};
    final ok = await showDialog<bool>(context: c, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: Text('صلاحيات إضافية: ${s['display_name']}'),
      content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: [for (final p in grantable) CheckboxListTile(dense: true, value: sel.contains(p), title: Text(p), onChanged: (v) => set(() => v == true ? sel.add(p) : sel.remove(p)))])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ'))],
    )));
    if (ok == true && c.mounted) { await run(c, () => api.patch('/api/admin/staff/${s['id']}', {'permissions': sel.toList()})); await reload(); }
  }

  @override
  Widget build(BuildContext context) => SubPage(
        title: 'الموظفون',
        child: StatefulBuilder(builder: (context, set) => Scaffold(
          floatingActionButton: FloatingActionButton.extended(onPressed: () async { await _create(context, () async => set(() {})); set(() {}); }, icon: const Icon(Icons.person_add), label: const Text('موظف جديد')),
          body: ApiList(key: UniqueKey(), api: api, path: '/api/admin/staff', keyName: 'staff', tile: (c, s, reload) => ListTile(
            title: Text('${s['display_name']} · ${s['role']}'), subtitle: Text('${s['email']}${s['disabled_by_owner'] == true ? ' · معطّل' : ''}'),
            trailing: PopupMenuButton<String>(onSelected: (v) async {
              if (v == 'perm') { await _permissions(c, s, reload); }
              else if (v == 'toggle') { await run(c, () => api.patch('/api/admin/staff/${s['id']}', {'disabled': s['disabled_by_owner'] != true})); await reload(); }
              else if (v == 'revoke') { await run(c, () => api.delete('/api/admin/staff/${s['id']}')); toast(c, 'تم إنهاء الجلسات'); }
            }, itemBuilder: (_) => [const PopupMenuItem(value: 'perm', child: Text('الصلاحيات')), PopupMenuItem(value: 'toggle', child: Text(s['disabled_by_owner'] == true ? 'تفعيل' : 'تعطيل')), const PopupMenuItem(value: 'revoke', child: Text('إنهاء كل الجلسات'))]),
          )),
        )),
      );
}
