import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class LegalConsentRepository {
  LegalConsentRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<void> recordConsent({
    required String termId,
    required String termLabel,
    required bool agreed,
  }) async {
    if (!SupabaseService.isReady) return;
    if (_client.auth.currentUser == null) return;
    try {
      await _client.rpc(
        'record_legal_consent',
        params: {
          'p_term_id': termId,
          'p_term_label': termLabel,
          'p_agreed': agreed,
        },
      );
    } catch (e, st) {
      debugPrint('[LegalConsent] recordConsent($termId): $e\n$st');
    }
  }
}
