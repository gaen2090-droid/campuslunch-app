import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class UserProfile {
  final String id;
  final String? email;
  final String nickname;
  final String role;

  const UserProfile({
    required this.id,
    this.email,
    required this.nickname,
    this.role = 'user',
  });
}

class ProfileRepository {
  ProfileRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<UserProfile?> fetch(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return null;
      return UserProfile(
        id: row['id'] as String,
        email: row['email'] as String?,
        nickname: row['nickname'] as String? ?? '사용자',
        role: row['role'] as String? ?? 'user',
      );
    } catch (e, st) {
      debugPrint('[Profile] fetch failed: $e\n$st');
      return null;
    }
  }

  Future<void> upsertFromAuthUser(User user) async {
    final meta = user.userMetadata;
    final nickname = meta?['nickname'] as String? ?? '사용자';
    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'nickname': nickname,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e, st) {
      debugPrint('[Profile] upsert failed: $e\n$st');
    }
  }
}
