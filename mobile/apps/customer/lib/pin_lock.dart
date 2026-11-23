import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:near_me_core/near_me_core.dart';

/// Local PIN lock. Real PIN and decoy PIN are stored only as salted, iterated hashes in the Android Keystore-backed secure storage.
/// A decoy PIN opens [DecoyShell], an EMPTY harmless shell that never loads or shows any real account data.
class PinStore {
  PinStore([FlutterSecureStorage? s]) : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;

  static String _hash(String pin, String salt) {
    var d = utf8.encode('$salt:$pin');
    for (var i = 0; i < 20000; i++) { d = sha256.convert(d).bytes; }
    return base64.encode(d);
  }

  static String _salt() => base64.encode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));

  Future<bool> get enabled async => (await _s.read(key: 'pin_real')) != null;

  Future<String?> setPins({required String real, String? decoy}) async {
    final e = validatePin(real); if (e != null) return e;
    if (decoy != null) { final d = validatePin(decoy); if (d != null) return d; if (decoy == real) return 'decoy_same_as_real'; }
    final s = _salt();
    await _s.write(key: 'pin_real', value: '$s:${_hash(real, s)}');
    if (decoy != null) { final s2 = _salt(); await _s.write(key: 'pin_decoy', value: '$s2:${_hash(decoy, s2)}'); } else { await _s.delete(key: 'pin_decoy'); }
    await _s.write(key: 'pin_fails', value: '0');
    return null;
  }

  Future<void> clear() async { for (final k in ['pin_real', 'pin_decoy', 'pin_fails', 'pin_lock_until']) { await _s.delete(key: k); } }

  /// Brute-force protection: 5 failures => 30 s lockout, doubling each further 5 failures.
  Future<Duration> lockedFor() async {
    final u = int.tryParse(await _s.read(key: 'pin_lock_until') ?? '');
    if (u == null) return Duration.zero;
    final left = u - DateTime.now().millisecondsSinceEpoch;
    return left > 0 ? Duration(milliseconds: left) : Duration.zero;
  }

  Future<PinResult> check(String pin) async {
    if ((await lockedFor()) > Duration.zero) return PinResult.wrong;
    bool match(String? stored) { if (stored == null) return false; final i = stored.indexOf(':'); return _hash(pin, stored.substring(0, i)) == stored.substring(i + 1); }
    if (match(await _s.read(key: 'pin_real'))) { await _s.write(key: 'pin_fails', value: '0'); return PinResult.real; }
    if (match(await _s.read(key: 'pin_decoy'))) return PinResult.decoy;
    final fails = (int.tryParse(await _s.read(key: 'pin_fails') ?? '0') ?? 0) + 1;
    await _s.write(key: 'pin_fails', value: '$fails');
    if (fails % 5 == 0) { final secs = 30 * pow(2, fails ~/ 5 - 1).toInt(); await _s.write(key: 'pin_lock_until', value: '${DateTime.now().millisecondsSinceEpoch + secs * 1000}'); }
    return PinResult.wrong;
  }
}

/// Locks [child] on start and after the user's chosen timeout (must be one of the Owner-allowed values) in the background.
class PinLockGate extends StatefulWidget {
  const PinLockGate({super.key, required this.child, required this.store, required this.timeoutSec});
  final Widget child;
  final PinStore store;
  final int timeoutSec; // 0 = lock immediately when leaving the app
  @override
  State<PinLockGate> createState() => _PinLockGateState();
}

class _PinLockGateState extends State<PinLockGate> with WidgetsBindingObserver {
  bool _locked = false, _decoy = false, _ready = false;
  DateTime? _leftAt;
  final _c = TextEditingController();
  String? _err;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); widget.store.enabled.then((e) { if (mounted) setState(() { _locked = e; _ready = true; }); }); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _c.dispose(); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) async {
    if (s == AppLifecycleState.paused) { _leftAt = DateTime.now(); }
    if (s == AppLifecycleState.resumed && _leftAt != null && await widget.store.enabled) {
      if (DateTime.now().difference(_leftAt!).inSeconds >= widget.timeoutSec) { setState(() { _locked = true; _decoy = false; }); }
    }
  }

  Future<void> _submit() async {
    final r = await widget.store.check(_c.text);
    _c.clear();
    if (!mounted) return;
    switch (r) {
      case PinResult.real: setState(() { _locked = false; _decoy = false; _err = null; });
      case PinResult.decoy: setState(() { _locked = false; _decoy = true; _err = null; });
      case PinResult.wrong:
        final wait = await widget.store.lockedFor();
        setState(() => _err = wait > Duration.zero ? 'محاولات كثيرة. انتظر ${wait.inSeconds} ثانية' : 'رمز غير صحيح');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const Scaffold(body: SizedBox.shrink());
    if (_decoy) return const DecoyShell();
    if (!_locked) return widget.child;
    return Scaffold(body: SafeArea(child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const NmIcon('shield', size: 72), const SizedBox(height: 16), const Text('أدخل رمز القفل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 16),
      TextField(controller: _c, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, textAlign: TextAlign.center, onSubmitted: (_) => _submit()),
      if (_err != null) Text(_err!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 12), FilledButton(onPressed: _submit, child: const Text('فتح')),
    ])))));
  }
}

/// Opened by the decoy PIN. Deliberately contains NO account information and makes NO network calls.
class DecoyShell extends StatelessWidget {
  const DecoyShell({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('NEAR ME')), body: const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد محادثات أو تطابقات بعد.', textAlign: TextAlign.center))));
}
