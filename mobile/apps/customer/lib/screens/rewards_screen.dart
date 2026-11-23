import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';

/// Daily challenges (progress is computed by the server), inventory + equip, received gifts, and the OPTIONAL rewarded ad.
/// All rewards are free, non-cash cosmetics.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key, required this.api, required this.builder, this.onWatchRewardedAd});
  final ApiClient api;
  final AppBuilderConfig builder;
  /// Provided by the app: shows an AdMob rewarded ad and resolves true when the user earned the reward.
  final Future<bool> Function()? onWatchRewardedAd;
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  List<Map<String, dynamic>> _challenges = [], _items = [], _gifts = [];
  Map<String, dynamic> _equipped = {};
  String? _msg;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final c = await widget.api.get('/api/challenges'), i = await widget.api.get('/api/inventory');
      if (!mounted) return;
      setState(() {
        _challenges = (c['challenges'] as List<dynamic>).cast<Map<String, dynamic>>();
        _items = (i['items'] as List<dynamic>).cast<Map<String, dynamic>>();
        _gifts = (i['gifts_received'] as List<dynamic>).cast<Map<String, dynamic>>();
        _equipped = (i['equipped'] as Map<String, dynamic>?) ?? {};
      });
    } catch (e) { if (mounted) setState(() => _msg = errorText(e)); }
  }

  Future<void> _claim(String id) async {
    try { final r = await widget.api.post('/api/challenges/$id/claim', {}); setState(() => _msg = r['reward_item'] == null ? 'تم الاستلام' : 'حصلت على: ${r['reward_item']}'); await _load(); }
    catch (e) { setState(() => _msg = errorText(e)); }
  }

  Future<void> _equip(String slot, String? item) async {
    try { await widget.api.post('/api/inventory/equip', {'slot': slot, 'item_id': item}); await _load(); } catch (e) { setState(() => _msg = errorText(e)); }
  }

  Future<void> _ad() async {
    final watched = await widget.onWatchRewardedAd?.call() ?? false;
    if (!watched) { setState(() => _msg = 'الإعلان غير متاح الآن'); return; }
    try { final r = await widget.api.post('/api/rewards/ad', {}); setState(() => _msg = r['item_id'] == null ? 'لديك كل العناصر المتاحة' : 'عنصر جديد: ${r['item_id']}'); await _load(); }
    catch (e) { setState(() => _msg = errorText(e)); }
  }

  static const _slotOf = {'frame': 'frame', 'cover': 'cover', 'name_color': 'name_color', 'effect': 'effect'};

  @override
  Widget build(BuildContext context) {
    final f = widget.builder;
    return Scaffold(
      appBar: AppBar(title: const Text('الإنجازات والمخزون')),
      body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_msg != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_msg!)),
        if (f.feature('challenges')) ...[
          const Text('تحديات اليوم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          for (final c in _challenges) GlassCard(child: ListTile(
            contentPadding: EdgeInsets.zero, title: Text('${c['title_ar']}'),
            subtitle: LinearProgressIndicator(value: ((c['progress'] as int) / (c['target'] as int)).clamp(0, 1).toDouble()),
            trailing: c['claimed'] == true ? const Icon(Icons.check_circle) : FilledButton(onPressed: c['completed'] == true ? () => _claim('${c['id']}') : null, child: const Text('استلم')),
          )),
        ],
        if (f.feature('rewarded_ads') && widget.onWatchRewardedAd != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: OutlinedButton.icon(onPressed: _ad, icon: const Icon(Icons.play_circle_outline), label: const Text('شاهد إعلانًا واحصل على عنصر مجاني (اختياري)'))),
        if (f.feature('inventory')) ...[
          const SizedBox(height: 12), const Text('مخزوني', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final it in _items.where((i) => _slotOf.containsKey(i['kind'])))
              ChoiceChip(label: Text('${it['name_ar']}'), selected: _equipped[it['kind']] == it['id'], onSelected: (v) => _equip(_slotOf[it['kind']]!, v ? it['id'] as String : null)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [for (final it in _items.where((i) => i['kind'] == 'badge')) Chip(label: Text('🏅 ${it['name_ar']}'))]),
        ],
        if (f.feature('gifts') && _gifts.isNotEmpty) ...[
          const SizedBox(height: 12), const Text('هدايا استلمتها', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          for (final g in _gifts) ListTile(leading: Text(((g['payload'] as Map<String, dynamic>?)?['emoji'] ?? '🎁') as String, style: const TextStyle(fontSize: 26)), title: Text('من ${g['from_name']}')),
        ],
      ])),
    );
  }
}
