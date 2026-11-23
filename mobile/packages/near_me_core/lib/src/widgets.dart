import 'package:flutter_svg/flutter_svg.dart';
import 'api_client.dart';
import 'package:flutter/material.dart';

/// Frosted card used across apps.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsetsDirectional.all(14)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: s.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: s.onSurface.withValues(alpha: .08))),
      child: Padding(padding: padding, child: child),
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.gradient});
  final String label;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Opacity(
      opacity: onPressed == null ? .5 : 1,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(gradient: gradient ?? LinearGradient(colors: [s.primary, s.secondary]), borderRadius: BorderRadius.circular(16)),
          child: InkWell(onTap: onPressed, borderRadius: BorderRadius.circular(16), child: SizedBox(height: 52, child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))))),
        ),
      ),
    );
  }
}

class OnlineDot extends StatelessWidget {
  const OnlineDot({super.key});
  @override
  Widget build(BuildContext context) => Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0xFF34D399), blurRadius: 6)]));
}

/// Staff sign-in (email + password + mandatory TOTP). Shared by Admin and Support apps.
class StaffLogin extends StatefulWidget {
  const StaffLogin({super.key, required this.api, required this.builder});
  final ApiClient api;
  final WidgetBuilder builder;
  @override
  State<StaffLogin> createState() => _StaffLoginState();
}

class _StaffLoginState extends State<StaffLogin> {
  final _e = TextEditingController(), _p = TextEditingController(), _t = TextEditingController();
  bool _in = false, _busy = false;
  String? _err;
  Future<void> _go() async {
    setState(() { _busy = true; _err = null; });
    try {
      final r = await widget.api.post('/api/auth/login', {'email': _e.text.trim(), 'password': _p.text, 'totp': _t.text.trim()});
      await widget.api.saveTokens(r);
      setState(() => _in = true);
    } on ApiException catch (e) { setState(() => _err = e.code); } catch (_) { setState(() => _err = 'network'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    if (_in) return widget.builder(context);
    return Scaffold(body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 40), const Text('تسجيل دخول الموظفين', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), const SizedBox(height: 24),
      TextField(controller: _e, decoration: const InputDecoration(labelText: 'البريد')), const SizedBox(height: 12),
      TextField(controller: _p, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور')), const SizedBox(height: 12),
      TextField(controller: _t, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'رمز التحقق الثنائي (2FA)')),
      if (_err != null) Text(_err!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      const SizedBox(height: 12), FilledButton(onPressed: _busy ? null : _go, child: const Text('دخول')),
    ])));
  }
}

/// 3D icon from the shared set (assets/icons/<name>.svg). Inactive icons are dimmed/desaturated.
class NmIcon extends StatelessWidget {
  const NmIcon(this.name, {super.key, this.size = 40, this.active = true});
  final String name;
  final double size;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final icon = SvgPicture.asset('assets/icons/$name.svg', package: 'near_me_core', width: size, height: size, semanticsLabel: name);
    if (active) return icon;
    return Opacity(opacity: .5, child: ColorFiltered(colorFilter: const ColorFilter.matrix(<double>[0.6, 0.3, 0.1, 0, 0, 0.2, 0.7, 0.1, 0, 0, 0.2, 0.3, 0.5, 0, 0, 0, 0, 0, 1, 0]), child: icon));
  }
}
