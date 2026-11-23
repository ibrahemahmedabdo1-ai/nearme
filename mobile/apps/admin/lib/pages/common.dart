import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';

void toast(BuildContext c, String m) { if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m))); }

Future<bool> confirm(BuildContext c, String title, {String? body}) async =>
    (await showDialog<bool>(context: c, builder: (_) => AlertDialog(title: Text(title), content: body == null ? null : Text(body), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('تأكيد'))]))) == true;

Future<String?> askText(BuildContext c, String title, {bool obscure = false}) {
  final t = TextEditingController();
  return showDialog<String>(context: c, builder: (_) => AlertDialog(title: Text(title), content: TextField(controller: t, obscureText: obscure, autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(c, t.text.trim()), child: const Text('موافق'))]));
}

/// Runs an API call, reporting errors in Arabic. Returns the response or null.
Future<Map<String, dynamic>?> run(BuildContext c, Future<Map<String, dynamic>> Function() f) async {
  try { return await f(); } catch (e) { toast(c, errorText(e)); return null; }
}

/// Loads a list from [path] under [key] and renders each row with [tile]. Pull-to-refresh included.
class ApiList extends StatefulWidget {
  const ApiList({super.key, required this.api, required this.path, required this.keyName, required this.tile, this.empty = 'لا توجد عناصر'});
  final ApiClient api;
  final String path, keyName, empty;
  final Widget Function(BuildContext, Map<String, dynamic>, Future<void> Function() reload) tile;
  @override
  State<ApiList> createState() => _ApiListState();
}

class _ApiListState extends State<ApiList> {
  List<Map<String, dynamic>>? _rows;
  String? _err;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final d = await widget.api.get(widget.path); if (mounted) setState(() { _rows = (d[widget.keyName] as List<dynamic>).cast<Map<String, dynamic>>(); _err = null; }); }
    catch (e) { if (mounted) setState(() => _err = errorText(e)); }
  }
  @override
  Widget build(BuildContext context) {
    if (_err != null) return Center(child: Text(_err!));
    if (_rows == null) return const Center(child: CircularProgressIndicator());
    if (_rows!.isEmpty) return Center(child: Text(widget.empty));
    return RefreshIndicator(onRefresh: _load, child: ListView(children: [for (final r in _rows!) widget.tile(context, r, _load)]));
  }
}

/// A scaffold for a sub-page opened from the "More" menu.
class SubPage extends StatelessWidget {
  const SubPage({super.key, required this.title, required this.child, this.actions});
  final String title;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title), actions: actions), body: child);
}
