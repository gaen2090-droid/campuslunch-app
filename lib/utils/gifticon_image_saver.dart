import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 기프티콘 이미지를 기기 사진 앨범에 저장
class GifticonImageSaver {
  static Future<String?> saveFromUrl(String url) async {
    if (url.isEmpty) return '저장할 이미지가 없어요.';
    if (kIsWeb) return '앱에서만 사진을 저장할 수 있어요.';

    File? tempFile;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        return '이미지를 불러올 수 없어요.';
      }

      final dir = await getTemporaryDirectory();
      final ext = _guessExtension(
        url,
        response.headers['content-type'],
      );
      tempFile = File(
        '${dir.path}/campuslunch_coupon_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await tempFile.writeAsBytes(response.bodyBytes, flush: true);

      // addOnly 권한만 사용 (NSPhotoLibraryAddUsageDescription)
      await Gal.putImage(tempFile.path);
      return null;
    } on GalException catch (e) {
      debugPrint('[GifticonImageSaver] GalException: $e');
      if (e.type == GalExceptionType.accessDenied) {
        return '사진 앨범 접근 권한이 필요해요.\n설정에서 허용해 주세요.';
      }
      return '사진 저장에 실패했어요.';
    } catch (e, st) {
      debugPrint('[GifticonImageSaver] failed: $e\n$st');
      return '사진 저장에 실패했어요.';
    } finally {
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  static String _guessExtension(String url, String? contentType) {
    final lower = url.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.gif')) return 'gif';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';

    final type = contentType?.toLowerCase() ?? '';
    if (type.contains('png')) return 'png';
    if (type.contains('webp')) return 'webp';
    if (type.contains('gif')) return 'gif';
    return 'jpg';
  }
}
