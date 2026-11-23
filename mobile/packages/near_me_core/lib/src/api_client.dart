import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.status, this.code);
  final int status;
  final String code;
  @override
  String toString() => 'ApiException($status, $code)';
}

/// Talks only to the NEAR ME backend (HTTPS). No database credentials or service keys ever live in the app.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client, FlutterSecureStorage? storage})
      : _http = client ?? http.Client(),
        _store = storage ?? const FlutterSecureStorage();
  final String baseUrl;
  final http.Client _http;
  final FlutterSecureStorage _store;
  String? _access;
  bool _refreshing = false;

  Future<void> saveTokens(Map<String, dynamic> t) async {
    _access = t['access_token'] as String;
    await _store.write(key: 'refresh', value: t['refresh_token'] as String);
  }

  Future<bool> restore() async => (await _store.read(key: 'refresh')) != null && await _refresh();

  Future<bool> _refresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final rt = await _store.read(key: 'refresh');
      if (rt == null) return false;
      final r = await _http.post(Uri.parse('$baseUrl/api/auth/refresh'), headers: _h(), body: jsonEncode({'refresh_token': rt}));
      if (r.statusCode != 200) { await signOutLocal(); return false; }
      await saveTokens(jsonDecode(r.body) as Map<String, dynamic>);
      return true;
    } finally { _refreshing = false; }
  }

  Future<void> signOutLocal() async { _access = null; await _store.delete(key: 'refresh'); }

  Map<String, String> _h() => {'content-type': 'application/json', if (_access != null) 'authorization': 'Bearer $_access'};

  Future<Map<String, dynamic>> request(String method, String path, {Object? body, bool retry = true}) async {
    final uri = Uri.parse('$baseUrl$path');
    final req = http.Request(method, uri)..headers.addAll(_h());
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 20)));
    if (res.statusCode == 401 && retry && await _refresh()) return request(method, path, body: body, retry: false);
    final data = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) throw ApiException(res.statusCode, (data['error'] ?? 'unknown') as String);
    return data;
  }

  Future<Map<String, dynamic>> get(String p) => request('GET', p);
  Future<Map<String, dynamic>> post(String p, Object b) => request('POST', p, body: b);
  Future<Map<String, dynamic>> put(String p, Object b) => request('PUT', p, body: b);
  Future<Map<String, dynamic>> patch(String p, Object b) => request('PATCH', p, body: b);
  Future<Map<String, dynamic>> delete(String p, [Object? b]) => request('DELETE', p, body: b);
}
