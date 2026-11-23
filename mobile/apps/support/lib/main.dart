import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';
import 'package:near_me_support/near_me_support.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');

void main() => runApp(const SupportApp());

class SupportApp extends StatelessWidget {
  const SupportApp({super.key});
  @override
  Widget build(BuildContext context) {
    final api = ApiClient(baseUrl: apiBaseUrl);
    final t = themeById('graphite');
    return MaterialApp(title: 'NEAR ME Support', theme: t.build(Brightness.light), darkTheme: t.build(Brightness.dark), locale: const Locale('ar'), home: StaffLogin(api: api, builder: (_) => SupportCenter(api: api)));
  }
}
