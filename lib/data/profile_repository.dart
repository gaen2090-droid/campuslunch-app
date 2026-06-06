import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

/// public.users 테이블 (이 DB에는 profiles 없음)
class UserProfile {
  final String id;
  final String? email;
  final String nickname;
  final String role;
  final String authProvider;
  final String? kakaoUserId;
  final String? avatarUrl;

  const UserProfile({
    required this.id,
    this.email,
    required this.nickname,
    this.role = 'user',
    this.authProvider = 'email',
    this.kakaoUserId,
    this.avatarUrl,
  });
}

class ProfileRepository {
  ProfileRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  static const _table = 'users';

  Future<UserProfile?> fetch(String userId) async {
    try {
      final row = await _client
          .from(_table)
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      return UserProfile(
        id: row['id'] as String,
        email: row['email'] as String?,
        nickname: row['nickname'] as String? ?? '사용자',
        role: row['role'] as String? ?? 'user',
        authProvider: row['provider'] as String? ?? 'email',
        kakaoUserId: row['kakao_user_id'] as String?,
        avatarUrl: row['avatar_url'] as String?,
      );
    } catch (e, st) {
      debugPrint('[Profile] fetch failed: $e\n$st');
      return null;
    }
  }

  /// 다른 사용자가 쓰는 닉네임인지 (RPC 미배포 시 null → 앱에서 true로 간주)
  Future<bool?> isNicknameAvailable(String nickname) async {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) return false;
    try {
      final result = await _client.rpc(
        'is_nickname_available',
        params: {'p_nickname': trimmed},
      );
      if (result is bool) return result;
      return result == true;
    } catch (e, st) {
      debugPrint('[Profile] isNicknameAvailable failed: $e\n$st');
      return null;
    }
  }

  /// public.users 닉네임 즉시 반영 (RLS: 본인 row만)
  Future<bool> updateNickname(String userId, String nickname) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      final rows = await _client
          .from(_table)
          .update({
            'nickname': nickname,
            'updated_at': now,
          })
          .eq('id', userId)
          .select('id');
      return rows.isNotEmpty;
    } catch (e, st) {
      debugPrint('[Profile] updateNickname failed: $e\n$st');
      rethrow;
    }
  }

  /// public.users role 즉시 반영 (RLS: 본인 row만)
  Future<bool> updateRole(String userId, String role) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      final rows = await _client
          .from(_table)
          .update({
            'role': role,
            'updated_at': now,
          })
          .eq('id', userId)
          .select('id');
      return rows.isNotEmpty;
    } catch (e, st) {
      debugPrint('[Profile] updateRole failed: $e\n$st');
      rethrow;
    }
  }

  static String _resolveRole(String? existing, String? metaRole) {
    if (metaRole == 'owner' || metaRole == 'admin') return metaRole!;
    if (existing == 'owner' || existing == 'admin') return existing!;
    return existing ?? metaRole ?? 'user';
  }

  /// users row가 없을 때 닉네임 저장용 (기존 role 유지)
  Future<void> upsertNickname(User user, String nickname) async {
    final existing = await fetch(user.id);
    final meta = user.userMetadata;
    final provider = meta?['auth_provider'] as String? ??
        user.appMetadata['provider'] as String? ??
        existing?.authProvider ??
        'email';
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await _client.from(_table).upsert({
        'id': user.id,
        'email': user.email,
        'nickname': nickname,
        'role': _resolveRole(existing?.role, meta?['role'] as String?),
        'provider': provider,
        if (meta?['kakao_user_id'] != null) 'kakao_user_id': meta!['kakao_user_id'],
        if (meta?['avatar_url'] != null) 'avatar_url': meta!['avatar_url'],
        'updated_at': now,
      });
    } catch (e, st) {
      debugPrint('[Profile] upsertNickname failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> upsertFromAuthUser(User user) async {
    final meta = user.userMetadata;
    final nickname = meta?['nickname'] as String? ?? '사용자';
    final existing = await fetch(user.id);
    final provider = meta?['auth_provider'] as String? ??
        user.appMetadata['provider'] as String? ??
        existing?.authProvider ??
        'email';
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await _client.from(_table).upsert({
        'id': user.id,
        'email': user.email,
        'nickname': nickname,
        'role': _resolveRole(existing?.role, meta?['role'] as String?),
        'provider': provider,
        'kakao_user_id': meta?['kakao_user_id'],
        'avatar_url': meta?['avatar_url'],
        'last_login_at': now,
        'updated_at': now,
      });
    } catch (e, st) {
      debugPrint('[Profile] upsert failed: $e\n$st');
    }
  }

  Future<void> deleteOwnAccount() async {
    await _client.rpc('delete_own_account');
  }
}
