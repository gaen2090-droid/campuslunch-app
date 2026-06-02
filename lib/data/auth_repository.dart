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
}
