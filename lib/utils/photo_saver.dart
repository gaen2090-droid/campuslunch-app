import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

/// 사진(URL 또는 data:image/ URI)을 기기 사진 앨범에 저장.
/// 성공하면 null, 실패하면 사용자에게 보여줄 메시지를 돌려준다.
class PhotoSaver {
  static Future<String?> save(String url) async {
    if (url.isEmpty) return '저장할 이미지가 없어요.';
    if (kIsWeb) return '앱에서만 사진을 저장할 수 있어요.';

    try {
      final Uint8List bytes;
      if (url.startsWith('data:image/')) {
        bytes = base64Decode(url.substring(url.indexOf(',') + 1));
      } else {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) return '이미지를 불러올 수 없어요.';
        bytes = response.bodyBytes;
      }

      // addOnly 권한만 사용 (NSPhotoLibraryAddUsageDescription)
      await Gal.putImageBytes(bytes);
      return null;
    } on GalException catch (e) {
      debugPrint('[PhotoSaver] GalException: $e');
      if (e.type == GalExceptionType.accessDenied) {
        return '사진 앨범 접근 권한이 필요해요.\n휴대폰 설정에서 허용해 주세요.';
      }
      return '사진 저장에 실패했어요.';
    } catch (e, st) {
      debugPrint('[PhotoSaver] failed: $e\n$st');
      return '사진 저장에 실패했어요.';
    }
  }
}
