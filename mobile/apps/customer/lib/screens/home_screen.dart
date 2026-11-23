import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';
import '../ads.dart';
import '../app_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});
  final AppState state;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _me;
  @override
  void initState() { super.initState(); widget.state.api.get('/api/me').then((d) { if (mounted) setState(() => _me = d['user'] as Map<String, dynamic>?); }).catchError((_) {}); }
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsetsDirectional.all(16), children: [
      Text('أهلاً ${_me?['display_name'] ?? ''} 👋', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      const GlassCard(child: Text('لا توجد تطابقات جديدة بعد. ابدأ الاستكشاف من تبويب Near Me.')),
      const SizedBox(height: 12),
      const GlassCard(child: Text('تحدي اليوم: أرسل 3 تحيات واكسب مكافأة (غير نقدية).')),
      const SizedBox(height: 12),
      const NmBanner(screen: 'home'),
    ]);
  }
}
