import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class FeedbackRepository {
  FeedbackRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  /// app_feedback insert. RPC 키: category, content, user_id
  Future<void> submit({
    required String category,
    required String content,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('not_signed_in');
    }
    try {
      await _client.from('app_feedback').insert({
        'category': category,
        'content': content,
        'user_id': user.id,
      });
    } catch (e, st) {
      debugPrint('[Feedback] submit: $e\n$st');
      rethrow;
    }
  }
}
