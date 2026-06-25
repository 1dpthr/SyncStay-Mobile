import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  static const _bucket = 'hostel-images';

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<String> uploadHostelPhoto(Uint8List bytes, String hostelId) {
    final path = 'photos/$hostelId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    return _upload(bytes, path);
  }

  static Future<String> uploadHostelPaper(Uint8List bytes, String hostelId) {
    final path = 'documents/$hostelId-paper-${DateTime.now().millisecondsSinceEpoch}.jpg';
    return _upload(bytes, path);
  }

  static Future<String> _upload(Uint8List bytes, String path) async {
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _client.storage.from(_bucket).getPublicUrl(path);
  }
}
