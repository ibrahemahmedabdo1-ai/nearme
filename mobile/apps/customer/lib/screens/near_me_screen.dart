import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:near_me_core/near_me_core.dart';
import '../app_state.dart';

class NearMeScreen extends StatefulWidget {
  const NearMeScreen({super.key, required this.state});
  final AppState state;
  @override
  State<NearMeScreen> createState() => _NearMeScreenState();
}

class _NearMeScreenState extends State<NearMeScreen> {
  List<dynamic> _results = [];
  bool _loading = true, _needsPermission = false;
  String? _error;
  int _index = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = widget.state.radiusKm;
      final data = await widget.state.api.get('/api/discover?radius=${r == 0 ? 'all' : r}');
      setState(() { _results = data['results'] as List<dynamic>; _index = 0; });
    } on ApiException catch (e) {
      setState(() => _error = e.code);
    } catch (_) {
      setState(() => _error = 'network');
    } finally { if (mounted) setState(() => _loading = false); }
  }

  void _toast(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }

  Future<void> _rewind() async {
    try { await widget.state.api.post('/api/swipes/rewind', {}); _toast('تم التراجع'); await _load(); } catch (e) { _toast(errorText(e)); }
  }

  Future<void> _boost() async {
    try { await widget.state.api.post('/api/boost', {}); _toast('ملفك في المقدمة لمدة 30 دقيقة 🚀'); } catch (e) { _toast(errorText(e)); }
  }

  /// Location is requested only when the user taps "Use my location" (no background tracking).
  Future<void> _shareLocation() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) { setState(() => _needsPermission = true); return; }
    final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
    await widget.state.api.post('/api/me/location', {'lat': pos.latitude, 'lon': pos.longitude});
    setState(() => _needsPermission = false);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Column(children: [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
        child: Row(children: [
          const Expanded(child: Text('استكشاف', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
          if (s.builder.feature('rewind')) IconButton(onPressed: _rewind, icon: const Icon(Icons.undo_rounded), tooltip: 'تراجع'),
          if (s.builder.feature('boost')) IconButton(onPressed: _boost, icon: const Icon(Icons.rocket_launch_rounded), tooltip: 'تعزيز ملفي 30 دقيقة'),
          IconButton(onPressed: _shareLocation, icon: const Icon(Icons.my_location_rounded), tooltip: 'استخدم موقعي'),
        ]),
      ),
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsetsDirectional.symmetric(horizontal: 12), children: [
          for (final km in [...kRadiusOptionsKm, 0])
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(label: Text(km == 0 ? 'كل المسافات' : '$km كم'), selected: s.radiusKm == km, onSelected: (_) { s.setRadius(km); _load(); }),
            ),
        ]),
      ),
      if (_needsPermission) const Padding(padding: EdgeInsets.all(12), child: Text('الموقع مطلوب لعرض الأعضاء القريبين. يمكنك تفعيله من الإعدادات.')),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('تعذّر التحميل ($_error)'), TextButton(onPressed: _load, child: const Text('إعادة المحاولة'))]))
                : _index >= _results.length
                    ? const Center(child: Text('لا يوجد أعضاء ضمن هذا النطاق. جرّب مسافة أكبر.'))
                    : _Card(data: _results[_index] as Map<String, dynamic>, onNext: () => setState(() => _index++), api: s.api),
      ),
    ]);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.data, required this.onNext, required this.api});
  final Map<String, dynamic> data;
  final VoidCallback onNext;
  final ApiClient api;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final km = data['distance_km'];
    return Padding(
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: LinearGradient(colors: [cs.primary, cs.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            alignment: AlignmentDirectional.bottomStart,
            padding: const EdgeInsetsDirectional.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${data['name']}، ${data['age']}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
              if (data['boosted'] == true) const Text('🚀 معزَّز', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text([if (km != null) '≈ $km كم', '${data['compatibility']}% توافق', if (data['verified'] == true) 'موثّق'].join(' · '), style: const TextStyle(color: Colors.white70)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton.filledTonal(onPressed: onNext, icon: const Icon(Icons.close_rounded), iconSize: 28),
          const SizedBox(width: 18),
          IconButton.filled(onPressed: () async { try { await api.post('/api/swipes', {'to_user': data['id'], 'kind': 'like'}); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(e)))); return; } onNext(); }, icon: const Icon(Icons.favorite_rounded), iconSize: 32),
          const SizedBox(width: 18),
          IconButton.filledTonal(onPressed: () async { await api.post('/api/swipes', {'to_user': data['id'], 'kind': 'super_like'}); onNext(); }, icon: const Icon(Icons.star_rounded), iconSize: 28),
        ]),
      ]),
    );
  }
}
