import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

/// رفع صور الإعلان لـbucket listing-images العام — anon عنده insert (قاعدة
/// Storage بـCLAUDE.md). الضغط قبل الرفع مطلوب صراحة بخطة المشروع.
class StorageRepo {
  static const _bucket = 'listing-images';

  static Future<String> uploadListingPhoto(String localPath, int index) async {
    final compressed = await FlutterImageCompress.compressWithFile(
      localPath,
      quality: 75,
      minWidth: 1600,
      minHeight: 1600,
      format: CompressFormat.jpeg,
    );
    final bytes = compressed ?? await File(localPath).readAsBytes();
    final path = 'owner-uploads/${DateTime.now().microsecondsSinceEpoch}-$index.jpg';
    await supabase.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return supabase.storage.from(_bucket).getPublicUrl(path);
  }
}
