import 'dart:async';
import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  AppState(this.api);
  final ApiClient api;
  bool signedIn = false;
  String language = 'ar';
  String themeId = '';
  String? country;
  ThemeMode themeMode = ThemeMode.system;
  List<ThemeSchedule> schedule = [];
  int radiusKm = kDefaultRadiusKm; // 0 means "all distances"
  Map<String, dynamic> remoteConfig = {};
  int pinTimeoutSec = 60;
  AppBuilderConfig get builder => AppBuilderConfig.fromJson((remoteConfig['config'] as Map<String, dynamic>?)?['builder.app']); // Owner-published, data-only
  List<int> get allowedPinTimeouts { final v = (remoteConfig['config'] as Map<String, dynamic>?)?['pin.allowed_timeouts_sec']; return v is List ? v.cast<int>() : const [0, 60, 300, 900]; }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    language = p.getString('lang') ?? 'ar';
    themeId = p.getString('theme') ?? '';
    themeMode = ThemeMode.values[p.getInt('themeMode') ?? 0];
    pinTimeoutSec = p.getInt('pinTimeout') ?? 60;
    signedIn = await api.restore();
    try { remoteConfig = await api.get('/api/config'); } catch (_) {/* offline: keep defaults */}
  }

  Future<void> login(String email, String password, String installId) async {
    final t = await api.post('/api/auth/login', {'email': email, 'password': password, 'install_id': installId});
    await api.saveTokens(t);
    signedIn = true;
    notifyListeners();
  }

  Future<void> register({required String email, required String password, required String name, required DateTime birth, required String installId}) async {
    final b = '${birth.year.toString().padLeft(4, '0')}-${birth.month.toString().padLeft(2, '0')}-${birth.day.toString().padLeft(2, '0')}';
    final t = await api.post('/api/auth/register', {'email': email, 'password': password, 'display_name': name, 'birthdate': b, 'install_id': installId, 'accept_terms': true});
    await api.saveTokens(t);
    signedIn = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    try { await api.post('/api/auth/logout', {}); } catch (_) {}
    await api.signOutLocal();
    signedIn = false;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await api.request('DELETE', '/api/me');
    await api.signOutLocal();
    signedIn = false;
    notifyListeners();
  }

  Future<void> setLanguage(String l) async { language = l; (await SharedPreferences.getInstance()).setString('lang', l); notifyListeners(); }
  Future<void> setTheme(String id) async { themeId = id; (await SharedPreferences.getInstance()).setString('theme', id); notifyListeners(); }
  Future<void> setThemeMode(ThemeMode m) async { themeMode = m; (await SharedPreferences.getInstance()).setInt('themeMode', m.index); notifyListeners(); }
  Future<void> setPinTimeout(int s) async { pinTimeoutSec = allowedPinTimeouts.contains(s) ? s : allowedPinTimeouts.first; (await SharedPreferences.getInstance()).setInt('pinTimeout', pinTimeoutSec); notifyListeners(); }
  Timer? _beat;
  /// Foreground heartbeat for the online indicator (respects the member's own privacy toggles on the server).
  void startPresence() { _beat?.cancel(); _beat = Timer.periodic(const Duration(seconds: 60), (_) { if (signedIn) api.post('/api/presence', {}).catchError((_) => <String, dynamic>{}); }); }
  void stopPresence() => _beat?.cancel();
  void setRadius(int km) { radiusKm = km; notifyListeners(); }
}
