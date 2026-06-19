import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reward.dart';

class RewardRepository {
  final SupabaseClient _client;

  RewardRepository(this._client);

  Future<UserReward> fetchMyReward() async {
    try {
      final raw = await _client.rpc('get_my_rewards');
      if (raw is Map) {
        return UserReward.fromJson(Map<String, dynamic>.from(raw));
      }
      return UserReward.empty;
    } catch (e) {
      debugPrint('[Reward] fetchMyReward failed: $e');
      return UserReward.empty;
    }
  }

  Future<List<Gifticon>> fetchMyGifticons() async {
    try {
      final uid = _client.auth.currentUser?.id;
      final rows = await _client
          .from('gifticons')
          .select()
          .inFilter('status', ['assigned', 'used'])
          .eq('assigned_user_id', uid ?? '')
          .order('assigned_at', ascending: false);
      final list = <Gifticon>[];
      for (final r in rows as List) {
        final map = Map<String, dynamic>.from(r as Map);
        map['image_url'] = await _resolveImageUrl(map['image_url'] as String?);
        list.add(Gifticon.fromJson(map));
      }
      return list;
    } catch (e) {
      debugPrint('[Reward] fetchMyGifticons failed: $e');
      return [];
    }
  }

  /// image_url이 storage path면 signed URL로 변환, 아니면 그대로 반환
  Future<String> _resolveImageUrl(String? raw) async {
    if (raw == null || raw.isEmpty) return '';
    // storage path 형식: "gifticons/filename.jpg" (http로 시작하지 않음)
    if (raw.startsWith('http')) return raw;
    try {
      return await _client.storage
          .from('gifticons')
          .createSignedUrl(raw, 3600); // 1시간 유효
    } catch (e) {
      debugPrint('[Reward] createSignedUrl failed: $e');
      return '';
    }
  }

  /// 쿠폰 교환. 반환: (result, gifticon)
  Future<(RedeemResult, Gifticon?)> redeemGifticon() async {
    try {
      final raw = await _client.rpc('redeem_gifticon');
      if (raw is! Map) return (RedeemResult.error, null);
      final map = Map<String, dynamic>.from(raw);
      final status = map['status'] as String?;
      if (status == 'ok') {
        final gifticonMap = Map<String, dynamic>.from(map);
        gifticonMap['id'] = map['gifticon_id'];
        gifticonMap['created_at'] ??= DateTime.now().toIso8601String();
        gifticonMap['image_url'] = await _resolveImageUrl(gifticonMap['image_url'] as String?);
        return (RedeemResult.ok, Gifticon.fromJson(gifticonMap));
      } else if (status == 'sold_out') {
        return (RedeemResult.soldOut, null);
      } else {
        return (RedeemResult.notEnough, null);
      }
    } catch (e) {
      debugPrint('[Reward] redeemGifticon failed: $e');
      return (RedeemResult.error, null);
    }
  }

  Future<String?> markGifticonUsed(String gifticonId) async {
    try {
      final raw = await _client.rpc(
        'mark_gifticon_used',
        params: {'p_gifticon_id': gifticonId},
      );
      if (raw is Map && raw['status'] == 'ok') return null;
      return '쿠폰을 사용 처리할 수 없어요.';
    } catch (e) {
      debugPrint('[Reward] markGifticonUsed failed: $e');
      return '쿠폰을 사용 처리할 수 없어요.';
    }
  }

  // ── 어드민 ──

  Future<List<Gifticon>> adminListGifticons() async {
    try {
      final raw = await _client.rpc('admin_list_gifticons');
      if (raw == null) return [];
      final list = <Gifticon>[];
      for (final r in raw as List) {
        final map = Map<String, dynamic>.from(r as Map);
        map['image_url'] = await _resolveImageUrl(map['image_url'] as String?);
        list.add(Gifticon.fromJson(map));
      }
      return list;
    } catch (e) {
      debugPrint('[Reward] adminListGifticons failed: $e');
      return [];
    }
  }

  Future<String?> adminRegisterGifticon({
    required String brand,
    required String productName,
    required String imageUrl,
    DateTime? expiresAt,
  }) async {
    try {
      await _client.rpc('admin_register_gifticon', params: {
        'p_brand': brand,
        'p_product_name': productName,
        'p_image_url': imageUrl,
        if (expiresAt != null)
          'p_expires_at': expiresAt.toIso8601String().substring(0, 10),
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<(int, String?)> adminBulkRegisterGifticons(
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      final raw = await _client.rpc(
        'admin_bulk_register_gifticons',
        params: {'p_rows': rows},
      );
      if (raw is Map) {
        final inserted = (raw['inserted'] as num?)?.toInt() ?? 0;
        return (inserted, null);
      }
      return (0, '등록에 실패했어요.');
    } catch (e) {
      return (0, e.toString());
    }
  }

  /// 어드민: 기프티콘 이미지를 Supabase Storage private 버킷에 업로드
  /// 반환값: storage path (DB에 저장). 표시 시 _resolveImageUrl로 signed URL 변환.
  Future<String?> uploadGifticonImage(
      String fileName, Uint8List bytes) async {
    try {
      final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final path = 'gifticons/$uniqueName';
      await _client.storage
          .from('gifticons')
          .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: false));
      return path; // storage path를 반환 (URL 아님)
    } catch (e) {
      debugPrint('[Reward] uploadGifticonImage failed: $e');
      return null;
    }
  }
}
