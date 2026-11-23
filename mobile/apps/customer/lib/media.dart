import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:near_me_core/near_me_core.dart';

/// Upload flow for chat media: announce -> PUT to object storage -> malware scan. A file can only be sent once its scan is clean.
/// Returns the attachment id, or throws ApiException (e.g. storage_not_configured / malware_scanner_not_configured).
class MediaUploader {
  MediaUploader(this.api);
  final ApiClient api;

  Future<String?> pickAndUpload({ImageSource source = ImageSource.gallery}) async {
    final f = await ImagePicker().pickImage(source: source, maxWidth: 2048, imageQuality: 85);
    if (f == null) return null;
    final Uint8List bytes = await f.readAsBytes();
    final name = f.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : 'jpg';
    final mime = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
    final meta = await api.post('/api/uploads', {
      'name': 'photo.${ext == 'jpeg' ? 'jpg' : ext}', 'mime': mime, 'size': bytes.length,
      'head_b64': base64.encode(bytes.sublist(0, bytes.length < 16 ? bytes.length : 16)), 'sha256': sha256.convert(bytes).toString(),
    });
    final put = await http.put(Uri.parse(meta['upload_url'] as String), headers: {'content-type': mime}, body: bytes);
    if (put.statusCode >= 300) throw ApiException(502, 'upload_failed');
    final scan = await api.post('/api/uploads/complete', {'attachment_id': meta['attachment_id']});
    if (scan['scan_status'] != 'clean') throw ApiException(422, 'attachment_not_ready');
    return meta['attachment_id'] as String;
  }
}
