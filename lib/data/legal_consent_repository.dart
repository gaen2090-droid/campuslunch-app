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

  /// 서버에 필수 약관 5종이 동의로 남아 있으면 true.
  /// RPC 실패 시 null (로컬 폴백).
  Future<bool?> fetchHasRequiredConsents() async {
    if (!SupabaseService.isReady) return null;
    if (_client.auth.currentUser == null) return false;
    try {
      final result = await _client.rpc('has_required_legal_consents');
      return result as bool? ?? false;
    } catch (e, st) {
      debugPrint('[LegalConsent] fetchHasRequiredConsents: $e\n$st');
      return null;
    }
  }

  Future<bool> fetchMarketingConsent() async {
    if (!SupabaseService.isReady) return false;
    if (_client.auth.currentUser == null) return false;
    try {
      final result = await _client.rpc('fetch_marketing_consent');
      return result as bool? ?? false;
    } catch (e, st) {
      debugPrint('[LegalConsent] fetchMarketingConsent: $e\n$st');
      return false;
    }
  }
}
