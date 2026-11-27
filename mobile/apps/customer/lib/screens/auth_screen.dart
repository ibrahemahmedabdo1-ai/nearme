import 'dart:math';
import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';

const _legalBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.state});
  final AppState state;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController(), _pw = TextEditingController(), _name = TextEditingController(), _bio = TextEditingController();
  DateTime? _birth;
  bool _register = false, _busy = false, _terms = false, _loadingInterests = false;
  String _gender = 'prefer_not_to_say';
  int _minAge = 18, _maxAge = 45;
  List<Map<String, dynamic>> _allInterests = [];
  final Set<String> _selectedInterests = {};
  final Set<String> _preferredGenders = {};
  String? _error;

  static const _errors = {
    'invalid_credentials': 'البريد أو كلمة المرور غير صحيحة',
    'age_restricted': 'التطبيق مخصص لمن هم 18 عامًا فأكثر',
    'email_taken': 'البريد مستخدم بالفعل',
    'device_already_registered': 'هذا الجهاز مسجّل بحساب آخر',
    'password_too_weak': 'كلمة المرور ضعيفة (10 أحرف على الأقل مع حروف كبيرة وصغيرة وأرقام)',
    'password_too_short': 'كلمة المرور قصيرة جدًا',
    'unknown_interest': 'بعض الاهتمامات المختارة غير متاحة، حدّث القائمة وحاول مجددًا',
    'invalid_age_range': 'نطاق العمر غير صحيح',
    'rate_limited': 'محاولات كثيرة، حاول لاحقًا',
    'service_restricted': 'الخدمة متوقفة مؤقتًا',
    ...kErrorsAr,
  };

  @override
  void initState() { super.initState(); _loadInterests(); }

  Future<void> _loadInterests() async {
    setState(() => _loadingInterests = true);
    try {
      final data = await widget.state.api.get('/api/interests');
      final rows = (data['interests'] as List<dynamic>).cast<Map<String, dynamic>>();
      if (mounted) setState(() { _allInterests = rows; _error = null; });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل قائمة الاهتمامات. تحقق من اتصال الإنترنت ثم أعد المحاولة.');
    } finally { if (mounted) setState(() => _loadingInterests = false); }
  }

  Future<String> _installId() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString('install_id');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(32, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await p.setString('install_id', id);
    }
    return id;
  }

  int? get _age {
    if (_birth == null) return null;
    final now = DateTime.now();
    return now.year - _birth!.year - ((now.month < _birth!.month || (now.month == _birth!.month && now.day < _birth!.day)) ? 1 : 0);
  }

  Future<void> _openLegal(String page) async {
    final base = _legalBaseUrl.replaceFirst(RegExp(r'/
    if (_register) {
      if (_birth == null || !isAdult(_birth!)) { setState(() => _error = 'اختر تاريخ ميلاد صحيحًا. التسجيل متاح لمن هم 18 عامًا فأكثر.'); return; }
      if (_selectedInterests.length < 3) { setState(() => _error = 'اختر 3 اهتمامات على الأقل حتى نعرض لك أشخاصًا مناسبين.'); return; }
      if (_maxAge < _minAge) { setState(() => _error = 'الحد الأقصى للعمر يجب أن يكون أكبر من أو يساوي الحد الأدنى.'); return; }
      if (!_terms) { setState(() => _error = 'يجب الموافقة على الشروط أولًا.'); return; }
    }
    setState(() { _busy = true; _error = null; });
    try {
      if (_register) {
        await widget.state.register(
          email: _email.text.trim(), password: _pw.text, name: _name.text.trim(), birth: _birth!, installId: await _installId(),
          gender: _gender, bio: _bio.text.trim(), interests: _selectedInterests.toList(), minAge: _minAge, maxAge: _maxAge, preferredGenders: _preferredGenders.toList(),
        );
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
  void dispose() { _email.dispose(); _pw.dispose(); _name.dispose(); _bio.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsetsDirectional.all(24), children: [
          const SizedBox(height: 24),
          Text('NEAR ME', textAlign: TextAlign.center, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: cs.primary)),
          const SizedBox(height: 6),
          Text(_register ? 'أنشئ حسابك واكمل ملفك الشخصي' : 'مرحبًا بعودتك', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (_register) ...[
            TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'الاسم الظاهر *', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 12),
          ],
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _pw, obscureText: true, autofillHints: const [AutofillHints.password], decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline))),
          if (_register) ...[
            const SizedBox(height: 20),
            const Text('1. بياناتك الأساسية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.cake_outlined),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1920), lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)));
                if (d != null) setState(() { _birth = d; _error = null; });
              },
              label: Text(_birth == null ? 'تاريخ الميلاد * (18 عامًا فأكثر)' : 'تاريخ الميلاد: ${_birth!.year}-${_birth!.month.toString().padLeft(2, '0')}-${_birth!.day.toString().padLeft(2, '0')}  •  العمر: $_age سنة'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: 'النوع', prefixIcon: Icon(Icons.wc_outlined)),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('ذكر')),
                DropdownMenuItem(value: 'female', child: Text('أنثى')),
                DropdownMenuItem(value: 'other', child: Text('آخر')),
                DropdownMenuItem(value: 'prefer_not_to_say', child: Text('أفضل عدم التحديد')),
              ],
              onChanged: (v) => setState(() => _gender = v ?? _gender),
            ),
            const SizedBox(height: 12),
            TextField(controller: _bio, maxLength: 500, maxLines: 3, decoration: const InputDecoration(labelText: 'نبذة قصيرة عنك (اختياري)', hintText: 'عرّف الآخرين بنفسك...', alignLabelWithHint: true)),
            const SizedBox(height: 12),
            const Text('2. من تحب أن تتعرف عليهم؟', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: DropdownButtonFormField<int>(value: _minAge, decoration: const InputDecoration(labelText: 'من عمر'), items: [for (int a = 18; a <= 80; a++) DropdownMenuItem(value: a, child: Text('$a سنة'))], onChanged: (v) => setState(() { _minAge = v ?? _minAge; if (_maxAge < _minAge) _maxAge = _minAge; }))),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<int>(value: _maxAge, decoration: const InputDecoration(labelText: 'إلى عمر'), items: [for (int a = 18; a <= 99; a++) DropdownMenuItem(value: a, child: Text('$a سنة'))], onChanged: (v) => setState(() => _maxAge = v ?? _maxAge))),
            ]),
            const SizedBox(height: 12),
            const Text('نوع الأشخاص الذين تريد اكتشافهم (يمكن اختيار أكثر من نوع):', style: TextStyle(fontSize: 13)),
            Wrap(spacing: 8, children: [
              for (final g in const {'male':'أولاد','female':'بنات','other':'آخر'}.entries)
                FilterChip(label: Text(g.value), selected: _preferredGenders.contains(g.key), onSelected: (v) => setState(() { if (v) { _preferredGenders.add(g.key); } else { _preferredGenders.remove(g.key); } })),
            ]),
            const Text('إذا لم تختر أي نوع، ستظهر لك جميع الأنواع المتاحة.', style: TextStyle(fontSize: 11)),
            const SizedBox(height: 18),
            Row(children: [
              const Expanded(child: Text('3. اهتماماتك', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              Text('${_selectedInterests.length}/10', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            const Text('اختر 3 اهتمامات على الأقل لتخصيص الأشخاص المقترحين لك.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            if (_loadingInterests) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
            if (!_loadingInterests && _allInterests.isEmpty) OutlinedButton.icon(onPressed: _loadInterests, icon: const Icon(Icons.refresh), label: const Text('إعادة تحميل الاهتمامات')),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final i in _allInterests)
                FilterChip(
                  label: Text('${i['name_ar'] ?? i['name_en']}'),
                  selected: _selectedInterests.contains(i['slug']),
                  onSelected: (v) => setState(() {
                    final slug = i['slug'] as String;
                    if (v && _selectedInterests.length < 10) _selectedInterests.add(slug);
                    else _selectedInterests.remove(slug);
                  }),
                ),
            ]),
            const SizedBox(height: 12),
            CheckboxListTile(value: _terms, onChanged: (v) => setState(() => _terms = v ?? false), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, title: const Text('أؤكد أن عمري 18 عامًا أو أكثر وأوافق على الشروط وسياسة الخصوصية وإرشادات المجتمع', style: TextStyle(fontSize: 12))),
            Wrap(spacing: 4, children: [
              TextButton(onPressed: () => _openLegal('terms'), child: const Text('الشروط')),
              TextButton(onPressed: () => _openLegal('privacy'), child: const Text('سياسة الخصوصية')),
              TextButton(onPressed: () => _openLegal('community-guidelines'), child: const Text('إرشادات المجتمع')),
            ]),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: cs.error))),
          const SizedBox(height: 16),
          GradientButton(label: _busy ? 'جارٍ التنفيذ...' : (_register ? 'إنشاء الحساب والبدء' : 'تسجيل الدخول'), onPressed: _busy || (_register && (_loadingInterests || _allInterests.isEmpty || !_terms)) ? null : _submit),
          TextButton(onPressed: _busy ? null : () => setState(() { _register = !_register; _error = null; }), child: Text(_register ? 'لدي حساب بالفعل' : 'إنشاء حساب جديد')),
        ]),
      ),
    );
  }
}
), '');
    final uri = Uri.parse('$base/$page');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح صفحة السياسات. تحقق من اتصال الإنترنت.')));
    }
  }

  Future<void> _submit() async {
    if (_register) {
      if (_birth == null || !isAdult(_birth!)) { setState(() => _error = 'اختر تاريخ ميلاد صحيحًا. التسجيل متاح لمن هم 18 عامًا فأكثر.'); return; }
      if (_selectedInterests.length < 3) { setState(() => _error = 'اختر 3 اهتمامات على الأقل حتى نعرض لك أشخاصًا مناسبين.'); return; }
      if (_maxAge < _minAge) { setState(() => _error = 'الحد الأقصى للعمر يجب أن يكون أكبر من أو يساوي الحد الأدنى.'); return; }
      if (!_terms) { setState(() => _error = 'يجب الموافقة على الشروط أولًا.'); return; }
    }
    setState(() { _busy = true; _error = null; });
    try {
      if (_register) {
        await widget.state.register(
          email: _email.text.trim(), password: _pw.text, name: _name.text.trim(), birth: _birth!, installId: await _installId(),
          gender: _gender, bio: _bio.text.trim(), interests: _selectedInterests.toList(), minAge: _minAge, maxAge: _maxAge, preferredGenders: _preferredGenders.toList(),
        );
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
  void dispose() { _email.dispose(); _pw.dispose(); _name.dispose(); _bio.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsetsDirectional.all(24), children: [
          const SizedBox(height: 24),
          Text('NEAR ME', textAlign: TextAlign.center, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: cs.primary)),
          const SizedBox(height: 6),
          Text(_register ? 'أنشئ حسابك واكمل ملفك الشخصي' : 'مرحبًا بعودتك', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (_register) ...[
            TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'الاسم الظاهر *', prefixIcon: Icon(Icons.person_outline))),
            const SizedBox(height: 12),
          ],
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _pw, obscureText: true, autofillHints: const [AutofillHints.password], decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline))),
          if (_register) ...[
            const SizedBox(height: 20),
            const Text('1. بياناتك الأساسية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.cake_outlined),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime(2000), firstDate: DateTime(1920), lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)));
                if (d != null) setState(() { _birth = d; _error = null; });
              },
              label: Text(_birth == null ? 'تاريخ الميلاد * (18 عامًا فأكثر)' : 'تاريخ الميلاد: ${_birth!.year}-${_birth!.month.toString().padLeft(2, '0')}-${_birth!.day.toString().padLeft(2, '0')}  •  العمر: $_age سنة'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(labelText: 'النوع', prefixIcon: Icon(Icons.wc_outlined)),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('ذكر')),
                DropdownMenuItem(value: 'female', child: Text('أنثى')),
                DropdownMenuItem(value: 'other', child: Text('آخر')),
                DropdownMenuItem(value: 'prefer_not_to_say', child: Text('أفضل عدم التحديد')),
              ],
              onChanged: (v) => setState(() => _gender = v ?? _gender),
            ),
            const SizedBox(height: 12),
            TextField(controller: _bio, maxLength: 500, maxLines: 3, decoration: const InputDecoration(labelText: 'نبذة قصيرة عنك (اختياري)', hintText: 'عرّف الآخرين بنفسك...', alignLabelWithHint: true)),
            const SizedBox(height: 12),
            const Text('2. من تحب أن تتعرف عليهم؟', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: DropdownButtonFormField<int>(value: _minAge, decoration: const InputDecoration(labelText: 'من عمر'), items: [for (int a = 18; a <= 80; a++) DropdownMenuItem(value: a, child: Text('$a سنة'))], onChanged: (v) => setState(() { _minAge = v ?? _minAge; if (_maxAge < _minAge) _maxAge = _minAge; }))),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<int>(value: _maxAge, decoration: const InputDecoration(labelText: 'إلى عمر'), items: [for (int a = 18; a <= 99; a++) DropdownMenuItem(value: a, child: Text('$a سنة'))], onChanged: (v) => setState(() => _maxAge = v ?? _maxAge))),
            ]),
            const SizedBox(height: 12),
            const Text('نوع الأشخاص الذين تريد اكتشافهم (يمكن اختيار أكثر من نوع):', style: TextStyle(fontSize: 13)),
            Wrap(spacing: 8, children: [
              for (final g in const {'male':'أولاد','female':'بنات','other':'آخر'}.entries)
                FilterChip(label: Text(g.value), selected: _preferredGenders.contains(g.key), onSelected: (v) => setState(() { if (v) { _preferredGenders.add(g.key); } else { _preferredGenders.remove(g.key); } })),
            ]),
            const Text('إذا لم تختر أي نوع، ستظهر لك جميع الأنواع المتاحة.', style: TextStyle(fontSize: 11)),
            const SizedBox(height: 18),
            Row(children: [
              const Expanded(child: Text('3. اهتماماتك', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              Text('${_selectedInterests.length}/10', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            const Text('اختر 3 اهتمامات على الأقل لتخصيص الأشخاص المقترحين لك.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            if (_loadingInterests) const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
            if (!_loadingInterests && _allInterests.isEmpty) OutlinedButton.icon(onPressed: _loadInterests, icon: const Icon(Icons.refresh), label: const Text('إعادة تحميل الاهتمامات')),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final i in _allInterests)
                FilterChip(
                  label: Text('${i['name_ar'] ?? i['name_en']}'),
                  selected: _selectedInterests.contains(i['slug']),
                  onSelected: (v) => setState(() {
                    final slug = i['slug'] as String;
                    if (v && _selectedInterests.length < 10) _selectedInterests.add(slug);
                    else _selectedInterests.remove(slug);
                  }),
                ),
            ]),
            const SizedBox(height: 12),
            CheckboxListTile(value: _terms, onChanged: (v) => setState(() => _terms = v ?? false), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, title: const Text('أؤكد أن عمري 18 عامًا أو أكثر وأوافق على الشروط وسياسة الخصوصية وإرشادات المجتمع', style: TextStyle(fontSize: 12))),
            Wrap(spacing: 4, children: [
              TextButton(onPressed: () => _openLegal('terms'), child: const Text('الشروط')),
              TextButton(onPressed: () => _openLegal('privacy'), child: const Text('سياسة الخصوصية')),
              TextButton(onPressed: () => _openLegal('community-guidelines'), child: const Text('إرشادات المجتمع')),
            ]),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: cs.error))),
          const SizedBox(height: 16),
          GradientButton(label: _busy ? 'جارٍ التنفيذ...' : (_register ? 'إنشاء الحساب والبدء' : 'تسجيل الدخول'), onPressed: _busy || (_register && (_loadingInterests || _allInterests.isEmpty || !_terms)) ? null : _submit),
          TextButton(onPressed: _busy ? null : () => setState(() { _register = !_register; _error = null; }), child: Text(_register ? 'لدي حساب بالفعل' : 'إنشاء حساب جديد')),
        ]),
      ),
    );
  }
}
