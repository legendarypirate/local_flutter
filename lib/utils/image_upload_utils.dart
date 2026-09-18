import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resize/compress camera photos before multipart upload (avoids HD upload failures).
class ImageUploadUtils {
  static const int maxSide = 1280;
  static const int initialQuality = 72;
  static const int maxUploadBytes = 900 * 1024;

  static Future<File?> compressForUpload(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return file;

      var width = decoded.width;
      var height = decoded.height;
      if (width > maxSide || height > maxSide) {
        if (width >= height) {
          height = (height * maxSide / width).round();
          width = maxSide;
        } else {
          width = (width * maxSide / height).round();
          height = maxSide;
        }
      }

      final resized = img.copyResize(
        decoded,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      );

      var quality = initialQuality;
      Uint8List jpegBytes = Uint8List.fromList(
        img.encodeJpg(resized, quality: quality),
      );

      for (var attempt = 0; attempt < 5; attempt++) {
        debugPrint(
          'Compressed image attempt $attempt: '
          '${(jpegBytes.length / 1024).toStringAsFixed(1)} KB (q=$quality)',
        );
        if (jpegBytes.length <= maxUploadBytes) break;
        quality = (quality - 12).clamp(40, 95);
        jpegBytes = Uint8List.fromList(
          img.encodeJpg(resized, quality: quality),
        );
      }

      final dir = await getTemporaryDirectory();
      final targetPath = p.join(
        dir.path,
        'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final out = File(targetPath);
      await out.writeAsBytes(jpegBytes, flush: true);
      return out;
    } catch (e, st) {
      debugPrint('compressForUpload failed: $e\n$st');
      return file;
    }
  }
}
