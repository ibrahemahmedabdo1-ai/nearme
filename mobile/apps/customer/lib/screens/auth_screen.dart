import 'dart:math';
import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.state});
  final AppState state;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController(), _pw = TextEditingController(), _name = TextEditingController();
  DateTime? _birth;
  bool _register = false, _busy = false, _terms = false;
  String? _error;

  static const _errors = {
    'invalid_credentials': 'البريد أو كلمة المرور غير صحيحة',
    'age_restricted': 'التطبيق مخصص لمن هم 18 عامًا فأكثر',
    'email_taken': 'البريد مستخدم بالفعل',
    'device_already_registered': 'هذا الجهاز مسجّل بحساب آخر',
    'password_too_weak': 'كلمة المرور ضعيفة (10 أحرف على الأقل مع حروف كبيرة وصغيرة وأرقام)',
    'password_too_short': 'كلمة المرور قصيرة جدًا',
    'rate_limited': 'محاولات كثيرة، حاول لاحقًا',
    'service_restricted': 'الخدمة متوقفة مؤقتًا',
    ...kErrorsAr,
  };

  Future<String> _installId() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString('install_id');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(32, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join(); // random per-install id; no hardware identifiers
      await p.setString('install_id', id);
    }
    return id;
  }

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      if (_register) {
        if (_birth == null || !isAdult(_birth!)) throw ApiException(403, 'age_restricted');
        await widget.state.register(email: _email.text.trim(), password: _pw.text, name: _name.text.trim(), birth: _birth!, installId: await _installId());
      } else {
        await widget.state.login(_email.text.trim(), _pw.text, await _installId());
      }
    } on ApiException catch (e) {
      setState(() => _error = _errors[e.code] ?? 'حدث خطأ (${e.code})');
    } catch (_) {
      setState(() => _error = 'تعذّر الاتصال بالخادم');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsetsDirectional.all(24), children: [
          const SizedBox(height: 40),
          Text('NEAR ME', textAlign: TextAlign.center, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: cs.primary)),
          const SizedBox(height: 6),
          Text(_register ? 'أنشئ حسابك' : 'مرحبًا بعودتك', textAlign: TextAlign.center),
          const SizedBox(height: 28),
          if (_register) ...[TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم')), const SizedBox(height: 12)],
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
          const SizedBox(height: 12),
          TextField(controller: _pw, obscureText: true, autofillHints: const [AutofillHints.password], decoration: const InputDecoration(labelText: 'كلمة المرور')),
          if (_register) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1920), lastDate: DateTime.now());
                if (d != null) setState(() => _birth = d);
              },
              child: Text(_birth == null ? 'تاريخ الميلاد (18+ فقط)' : '${_birth!.year}-${_birth!.month}-${_birth!.day}'),
            ),
            CheckboxListTile(value: _terms, onChanged: (v) => setState(() => _terms = v ?? false), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, title: const Text('أؤكد أن عمري 18 عامًا أو أكثر وأوافق على الشروط وسياسة الخصوصية', style: TextStyle(fontSize: 12))),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: cs.error))),
          const SizedBox(height: 16),
          GradientButton(label: _register ? 'إنشاء حساب' : 'تسجيل الدخول', onPressed: _busy || (_register && !_terms) ? null : _submit),
          TextButton(onPressed: () => setState(() { _register = !_register; _error = null; }), child: Text(_register ? 'لدي حساب' : 'إنشاء حساب جديد')),
        ]),
      ),
    );
  }
}
