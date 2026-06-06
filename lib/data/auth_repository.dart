import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

/// `email_signup_status` RPC 결과
enum EmailSignupStatus {
  available,
  registered,
  pending,
  invalid,
  unknown,
}

/// `oauth_login_email_check` RPC 결과
enum OAuthLoginEmailStatus {
  available,
  sameProvider,
  blockedEmail,
  blockedOther,
  pending,
  invalid,
  unknown,
}

class AuthRepository {
  AuthRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<EmailSignupStatus> checkEmailSignupStatus(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      return EmailSignupStatus.invalid;
    }
    try {
      final raw = await _client.rpc(
        'email_signup_status',
        params: {'p_email': trimmed},
      );
      return _parseStatus(raw?.toString() ?? '');
    } catch (e, st) {
      debugPrint('[Auth] email_signup_status failed: $e\n$st');
      return EmailSignupStatus.unknown;
    }
  }

  EmailSignupStatus _parseStatus(String raw) {
    switch (raw) {
      case 'available':
        return EmailSignupStatus.available;
      case 'registered':
        return EmailSignupStatus.registered;
      case 'pending':
        return EmailSignupStatus.pending;
      case 'invalid':
        return EmailSignupStatus.invalid;
      default:
        return EmailSignupStatus.unknown;
    }
  }

  /// OAuth 로그인 전 이메일 충돌 확인 (이메일 가입 계정과 동일 주소 차단)
  Future<OAuthLoginEmailStatus> checkOAuthLoginEmail(
    String email,
    String provider,
  ) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      return OAuthLoginEmailStatus.invalid;
    }
    try {
      final raw = await _client.rpc(
        'oauth_login_email_check',
        params: {
          'p_email': trimmed,
          'p_provider': provider,
        },
      );
      return _parseOAuthStatus(raw?.toString() ?? '');
    } catch (e, st) {
      debugPrint('[Auth] oauth_login_email_check failed: $e\n$st');
      return OAuthLoginEmailStatus.unknown;
    }
  }

  OAuthLoginEmailStatus _parseOAuthStatus(String raw) {
    switch (raw) {
      case 'available':
        return OAuthLoginEmailStatus.available;
      case 'same_provider':
        return OAuthLoginEmailStatus.sameProvider;
      case 'blocked_email':
        return OAuthLoginEmailStatus.blockedEmail;
      case 'blocked_other':
        return OAuthLoginEmailStatus.blockedOther;
      case 'pending':
        return OAuthLoginEmailStatus.pending;
      case 'invalid':
        return OAuthLoginEmailStatus.invalid;
      default:
        return OAuthLoginEmailStatus.unknown;
    }
  }
}
