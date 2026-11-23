library near_me_support;

import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';

class SupportCenter extends StatefulWidget {
  const SupportCenter({super.key, required this.api});
  final ApiClient api;
  @override
  State<SupportCenter> createState() => _SupportCenterState();
}

class _SupportCenterState extends State<SupportCenter> {
  String _status = 'open';
  List<dynamic> _tickets = [];
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final d = await widget.api.get('/api/admin/tickets?status=$_status'); setState(() { _tickets = d['tickets'] as List<dynamic>; _error = null; }); }
    on ApiException catch (e) { setState(() => _error = e.code); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('مركز الدعم')),
        body: Column(children: [
          Wrap(spacing: 8, children: [for (final s in ['open', 'pending', 'escalated', 'closed']) ChoiceChip(label: Text(s), selected: _status == s, onSelected: (_) { _status = s; _load(); })]),
          if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error == 'forbidden' ? 'لا تملك صلاحية' : 'خطأ: $_error')),
          Expanded(child: _tickets.isEmpty ? const Center(child: Text('لا توجد تذاكر')) : ListView.separated(itemCount: _tickets.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
            final t = _tickets[i] as Map<String, dynamic>;
            return ListTile(title: Text('${t['subject']}'), subtitle: Text('${t['display_name'] ?? 'زائر'} · #${t['member_code'] ?? '-'}'), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => TicketView(api: widget.api, ticketId: t['id'] as String, subject: '${t['subject']}'))));
          })),
        ]),
      );
}

class TicketView extends StatefulWidget {
  const TicketView({super.key, required this.api, required this.ticketId, required this.subject});
  final ApiClient api;
  final String ticketId, subject;
  @override
  State<TicketView> createState() => _TicketViewState();
}

class _TicketViewState extends State<TicketView> {
  List<dynamic> _msgs = [];
  final _c = TextEditingController();
  String _identity = 'support';
  bool _internal = false;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { final d = await widget.api.get('/api/admin/tickets/${widget.ticketId}'); setState(() => _msgs = d['messages'] as List<dynamic>); }
  Future<void> _send() async {
    if (_c.text.trim().isEmpty) return;
    try { await widget.api.post('/api/admin/tickets/${widget.ticketId}', {'body': _c.text.trim(), 'identity': _identity, 'internal_note': _internal}); _c.clear(); await _load(); }
    on ApiException catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == 'identity_not_allowed' ? 'هذه الهوية غير مسموحة لك' : 'تعذّر الإرسال'))); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.subject)),
        body: Column(children: [
          Expanded(child: ListView(padding: const EdgeInsets.all(12), children: [for (final m in _msgs.cast<Map<String, dynamic>>()) Card(color: m['internal_note'] == true ? const Color(0x33FBBF24) : null, child: ListTile(title: Text('${m['body']}'), subtitle: Text(m['internal_note'] == true ? 'ملاحظة داخلية' : '${m['identity']}')))])),
          Padding(padding: const EdgeInsets.all(8), child: Column(children: [
            Row(children: [
              DropdownButton<String>(value: _identity, items: const [DropdownMenuItem(value: 'support', child: Text('الدعم')), DropdownMenuItem(value: 'admin', child: Text('الأدمن')), DropdownMenuItem(value: 'anonymous', child: Text('مجهول'))], onChanged: (v) => setState(() => _identity = v ?? 'support')),
              const SizedBox(width: 12), FilterChip(label: const Text('ملاحظة داخلية'), selected: _internal, onSelected: (v) => setState(() => _internal = v)),
            ]),
            Row(children: [Expanded(child: TextField(controller: _c, decoration: const InputDecoration(hintText: 'اكتب ردًا…'))), IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded))]),
          ])),
        ]),
      );
}
