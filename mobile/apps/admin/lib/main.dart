import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';
import 'package:near_me_support/near_me_support.dart';
import 'pages/builder_page.dart';
import 'pages/common.dart';
import 'pages/marketing_page.dart';
import 'pages/moderation_page.dart';
import 'pages/operations_page.dart';
import 'pages/staff_page.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');

void main() => runApp(const AdminApp());

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) {
    final api = ApiClient(baseUrl: apiBaseUrl);
    final t = themeById('midnight_violet');
    return MaterialApp(title: 'NEAR ME Admin', theme: t.build(Brightness.light), darkTheme: t.build(Brightness.dark), locale: const Locale('ar'), home: StaffLogin(api: api, builder: (_) => AdminHome(api: api)));
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.api});
  final ApiClient api;
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [Dashboard(api: widget.api), UsersPage(api: widget.api), SupportCenter(api: widget.api), ModerationPage(api: widget.api), MorePage(api: widget.api)];
    return Scaffold(
      body: SafeArea(child: pages[_i]),
      bottomNavigationBar: NavigationBar(selectedIndex: _i, onDestinationSelected: (v) => setState(() => _i = v), destinations: [
        NavigationDestination(icon: NmIcon('chart', size: 34, active: false), selectedIcon: NmIcon('chart', size: 40), label: 'اللوحة'),
        NavigationDestination(icon: NmIcon('users', size: 34, active: false), selectedIcon: NmIcon('users', size: 40), label: 'المستخدمون'),
        NavigationDestination(icon: NmIcon('ticket', size: 34, active: false), selectedIcon: NmIcon('ticket', size: 40), label: 'الدعم'),
        NavigationDestination(icon: NmIcon('shield', size: 34, active: false), selectedIcon: NmIcon('shield', size: 40), label: 'الإشراف'),
        NavigationDestination(icon: NmIcon('sliders', size: 34, active: false), selectedIcon: NmIcon('sliders', size: 40), label: 'المزيد'),
      ]),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.api});
  final ApiClient api;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Map<String, dynamic>? _d;
  String? _err;
  @override
  void initState() { super.initState(); widget.api.get('/api/admin/stats').then((d) => setState(() => _d = d)).catchError((Object e) => setState(() => _err = e is ApiException ? e.code : 'network')); }
  String _v(String k) => _d?[k] == null ? '—' : '${_d![k]}'; // null => no real data source: show a dash, never an invented number
  @override
  Widget build(BuildContext context) {
    if (_err != null) return Center(child: Text('تعذّر التحميل: $_err'));
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('لوحة التحكم', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), const SizedBox(height: 12),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.7, children: [
        for (final e in {'إجمالي المستخدمين': 'total_users', 'جدد (7 أيام)': 'new_7d', 'DAU': 'dau', 'MAU': 'mau', 'رسائل 24س': 'messages_24h', 'تطابقات 24س': 'matches_24h', 'بلاغات مفتوحة': 'open_reports', 'توثيق معلّق': 'pending_verifications', 'AdMob': 'admob', 'الاحتفاظ': 'retention'}.entries)
          GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(e.key, style: const TextStyle(fontSize: 12)), Text(_v(e.value), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))])),
      ]),
    ]);
  }
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.api});
  final ApiClient api;
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<dynamic> _u = [];
  Future<void> _search(String q) async { final d = await widget.api.get('/api/admin/users?q=${Uri.encodeQueryComponent(q)}'); setState(() => _u = d['users'] as List<dynamic>); }
  @override
  void initState() { super.initState(); _search(''); }
  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(onSubmitted: _search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'اسم / بريد / رقم العضوية'))),
        Expanded(child: ListView(children: [for (final u in _u.cast<Map<String, dynamic>>()) ListTile(title: Text('${u['display_name']}'), subtitle: Text('NM-${u['member_code']} · ${u['status']} · ثقة ${u['trust_score']}'))])),
      ]);
}

class EmergencyPage extends StatelessWidget {
  const EmergencyPage({super.key, required this.api});
  final ApiClient api;
  static const modes = ['normal', 'maintenance', 'read_only', 'registration_lock', 'chat_protection', 'security_lockdown', 'full_shutdown'];
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('وضع الطوارئ (للمالك فقط)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        for (final m in modes)
          ListTile(title: Text(m), trailing: const Icon(Icons.chevron_right), onTap: () async {
            final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text('تفعيل $m؟'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('تأكيد'))]));
            if (ok == true) { try { await api.post('/api/admin/emergency', {'mode': m}); } on ApiException catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code))); } }
          }),
      ]);
}

/// Everything else, as a grid. The server enforces permissions; a screen the account may not use simply shows 403 in Arabic.
class MorePage extends StatefulWidget {
  const MorePage({super.key, required this.api});
  final ApiClient api;
  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  bool _owner = false;
  ApiClient get api => widget.api;
  @override
  void initState() { super.initState(); api.get('/api/me').then((d) { if (mounted) setState(() => _owner = d['role'] == 'owner'); }).catchError((_) => <String, dynamic>{}); }
  @override
  Widget build(BuildContext context) {
    void go(String title, Widget w, {bool bare = false}) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => bare ? w : SubPage(title: title, child: w)));
    final items = <(IconData, String, VoidCallback)>[
      if (_owner) (Icons.badge_outlined, 'الموظفون', () => go('', StaffPage(api: api), bare: true)),
      (Icons.emergency_outlined, 'الطوارئ', () => go('الطوارئ', EmergencyPage(api: api))),
      (Icons.campaign_outlined, 'التسويق', () => go('مركز التسويق', MarketingPage(api: api, isOwner: _owner))),
      (Icons.celebration_outlined, 'المناسبات', () => go('', OccasionsPage(api: api), bare: true)),
      (Icons.view_quilt_outlined, 'محرر التطبيق', () => go('محرر التطبيق', BuilderPage(api: api))),
      if (_owner) (Icons.ads_click, 'الإعلانات', () => go('', AdsPage(api: api), bare: true)),
      (Icons.tune, 'أوزان التوافق', () => go('', WeightsPage(api: api), bare: true)),
      if (_owner) (Icons.rocket_launch_outlined, 'الإصدارات', () => go('', ReleasesPage(api: api), bare: true)),
      if (_owner) (Icons.backup_outlined, 'النسخ الاحتياطي', () => go('', BackupsPage(api: api), bare: true)),
      if (_owner) (Icons.lock_outline, 'أمان المالك', () => go('', OwnerSecurityPage(api: api), bare: true)),
    ];
    return GridView.count(crossAxisCount: 2, padding: const EdgeInsets.all(16), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.5, children: [
      for (final i in items) InkWell(onTap: i.$3, borderRadius: BorderRadius.circular(20), child: GlassCard(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i.$1, size: 30), const SizedBox(height: 6), Text(i.$2)]))),
    ]);
  }
}
