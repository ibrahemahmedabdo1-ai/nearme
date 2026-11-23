import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';

/// Sticker + GIF picker for the chat composer. Returns {'kind': 'sticker'|'gif', 'body': id-or-url}.
class MediaPicker extends StatefulWidget {
  const MediaPicker({super.key, required this.api, required this.stickers, required this.gifs});
  final ApiClient api;
  final bool stickers, gifs;
  @override
  State<MediaPicker> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<MediaPicker> {
  List<Map<String, dynamic>> _stickers = [], _gifs = [];
  String? _gifError;
  final _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.stickers) widget.api.get('/api/stickers').then((d) { if (mounted) setState(() => _stickers = (d['stickers'] as List<dynamic>).cast<Map<String, dynamic>>()); }).catchError((_) => <String, dynamic>{});
    if (widget.gifs) _searchGifs('');
  }

  Future<void> _searchGifs(String t) async {
    try {
      final d = await widget.api.get('/api/gifs?q=${Uri.encodeQueryComponent(t)}');
      if (mounted) setState(() { _gifs = (d['gifs'] as List<dynamic>).cast<Map<String, dynamic>>(); _gifError = null; });
    } catch (e) { if (mounted) setState(() => _gifError = errorText(e)); }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [if (widget.stickers) 'ملصقات', if (widget.gifs) 'GIF'];
    return DefaultTabController(
      length: tabs.length,
      child: SizedBox(height: 360, child: Column(children: [
        TabBar(tabs: [for (final t in tabs) Tab(text: t)]),
        Expanded(child: TabBarView(children: [
          if (widget.stickers) GridView.count(crossAxisCount: 5, padding: const EdgeInsets.all(12), children: [
            for (final s in _stickers) InkWell(onTap: () => Navigator.pop(context, {'kind': 'sticker', 'body': s['id']}), child: Center(child: Text(((s['payload'] as Map<String, dynamic>?)?['emoji'] ?? '🙂') as String, style: const TextStyle(fontSize: 34)))),
          ]),
          if (widget.gifs) Column(children: [
            Padding(padding: const EdgeInsets.all(8), child: TextField(controller: _q, onSubmitted: _searchGifs, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن GIF'))),
            if (_gifError != null) Padding(padding: const EdgeInsets.all(16), child: Text(_gifError!)),
            Expanded(child: GridView.count(crossAxisCount: 3, children: [
              for (final g in _gifs) InkWell(onTap: () => Navigator.pop(context, {'kind': 'gif', 'body': g['url']}), child: Image.network(g['preview'] as String? ?? g['url'] as String, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))),
            ])),
          ]),
        ])),
      ])),
    );
  }
}

/// Emoji for the seeded sticker catalogue (ids come from /api/stickers; unknown ids fall back to a smiley).
const kStickerEmoji = {'stk_smile': '😊', 'stk_heart': '💖', 'stk_party': '🥳', 'stk_fire': '🔥', 'stk_wave': '👋'};

/// Renders the body of a non-text message.
Widget messageContent(BuildContext context, Map<String, dynamic> m, Color color, ApiClient api) {
  switch (m['kind']) {
    case 'sticker': return Text(kStickerEmoji['${m['body']}'] ?? '🙂', style: const TextStyle(fontSize: 40));
    case 'gif': return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network('${m['body']}', width: 200, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)));
    case 'image': return AttachmentImage(api: api, attachmentId: '${m['attachment_id']}');
    case 'file': return Text('📎 ملف', style: TextStyle(color: color));
    case 'location': return Text('📍 ${m['body']}', style: TextStyle(color: color));
    default: return Text('${m['body']}', style: TextStyle(color: color));
  }
}

/// Fetches a short-lived signed URL for an attachment (participants only) and shows it.
class AttachmentImage extends StatefulWidget {
  const AttachmentImage({super.key, required this.api, required this.attachmentId});
  final ApiClient api;
  final String attachmentId;
  @override
  State<AttachmentImage> createState() => _AttachmentImageState();
}

class _AttachmentImageState extends State<AttachmentImage> {
  String? _url, _err;
  @override
  void initState() { super.initState(); widget.api.get('/api/attachments/${widget.attachmentId}').then((d) { if (mounted) setState(() => _url = d['url'] as String); }).catchError((Object e) { if (mounted) setState(() => _err = errorText(e)); return <String, dynamic>{}; }); }
  @override
  Widget build(BuildContext context) => _url != null ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_url!, width: 220, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))) : Text(_err ?? '…');
}
