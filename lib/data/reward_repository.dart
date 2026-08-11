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

  /// 반환: (status, message) — status: ok | invalid_code | self_referral | already_used | referrer_daily_limit | error
  Future<(String, String?)> applyReferralCode(String code) async {
    try {
      final raw = await _client.rpc(
        'apply_referral_code',
        params: {'p_code': code},
      );
      if (raw is! Map) return ('error', '잠시 후 다시 시도해주세요.');
      final status = raw['status'] as String? ?? 'error';
      return (status, null);
    } catch (e) {
      debugPrint('[Reward] applyReferralCode failed: $e');
      return ('error', '잠시 후 다시 시도해주세요.');
    }
  }

  /// 반환: (my_referral_code, 이번 사이클 referrer 건수, 이번 사이클 referred 건수,
  ///        누적 referrer 건수, 누적 referred 건수)
  Future<(String, int, int, int, int)> fetchMyReferralHistory() async {
    try {
      final raw = await _client.rpc('get_my_referral_history');
      if (raw is! Map) return ('', 0, 0, 0, 0);
      final code = raw['my_referral_code'] as String? ?? '';
      final events = raw['events'] as List? ?? const [];
      var cycleReferrerCount = 0;
      var cycleReferredCount = 0;
      var totalReferrerCount = 0;
      var totalReferredCount = 0;
      for (final e in events) {
        if (e is! Map) continue;
        final isReferrer = e['role'] == 'referrer';
        final inCycle = e['in_current_cycle'] == true;
        if (isReferrer) {
          totalReferrerCount++;
          if (inCycle) cycleReferrerCount++;
        } else {
          totalReferredCount++;
          if (inCycle) cycleReferredCount++;
        }
      }
      return (
        code,
        cycleReferrerCount,
        cycleReferredCount,
        totalReferrerCount,
        totalReferredCount,
      );
    } catch (e) {
      debugPrint('[Reward] fetchMyReferralHistory failed: $e');
      return ('', 0, 0, 0, 0);
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
  Future<String> resolveGifticonImageUrl(String? raw) => _resolveImageUrl(raw);

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

  Future<String?> adminDeleteGifticon(String gifticonId) async {
    try {
      final raw = await _client.rpc(
        'admin_delete_gifticon',
        params: {'p_gifticon_id': gifticonId},
      );
      if (raw is! Map || raw['status'] != 'ok') {
        return '삭제에 실패했어요.';
      }
      final imageUrl = raw['image_url'] as String?;
      if (imageUrl != null &&
          imageUrl.isNotEmpty &&
          !imageUrl.startsWith('http')) {
        try {
          await _client.storage.from('gifticons').remove([imageUrl]);
        } catch (e) {
          debugPrint('[Reward] gifticon storage remove failed: $e');
        }
      }
      return null;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('배정되었거나')) return '배정·사용 완료된 기프티콘은 삭제할 수 없어요.';
      if (msg.contains('찾을 수 없')) return '기프티콘을 찾을 수 없어요.';
      debugPrint('[Reward] adminDeleteGifticon failed: $e');
      return '삭제에 실패했어요.';
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
