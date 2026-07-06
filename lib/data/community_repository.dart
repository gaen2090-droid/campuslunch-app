import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community_comment.dart';
import '../models/community_post.dart';
import '../services/supabase_service.dart';

class CommunityRepository {
  CommunityRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<CommunityPost>> fetchFeed({DateTime? before, int limit = 20}) async {
    final rows = await _client.rpc('community_feed', params: {
      'p_limit': limit,
      'p_before': before?.toIso8601String(),
    });
    return (rows as List<dynamic>)
        .map((e) => CommunityPost.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CommunityComment>> fetchComments(String postId) async {
    final rows = await _client.rpc('community_comments_for_post', params: {
      'p_post_id': postId,
    });
    return (rows as List<dynamic>)
        .map((e) => CommunityComment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createPost({
    required String content,
    List<String> imageUrls = const [],
    String? restaurantId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    await _client.from('community_posts').insert({
      'user_id': uid,
      'content': content,
      'image_urls': imageUrls,
      'restaurant_id': restaurantId,
    });
  }

  Future<void> updatePost({
    required String postId,
    required String content,
    List<String> imageUrls = const [],
    String? restaurantId,
  }) async {
    await _client.from('community_posts').update({
      'content': content,
      'image_urls': imageUrls,
      'restaurant_id': restaurantId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', postId);
  }

  Future<void> deletePost(String postId) async {
    await _client.from('community_posts').delete().eq('id', postId);
  }

  Future<void> addComment(String postId, String content) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    await _client.from('community_comments').insert({
      'post_id': postId,
      'user_id': uid,
      'content': content,
    });
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('community_comments').delete().eq('id', commentId);
  }

  Future<void> toggleLike(String postId, bool currentlyLiked) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    if (currentlyLiked) {
      await _client
          .from('community_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
    } else {
      await _client.from('community_likes').insert({
        'post_id': postId,
        'user_id': uid,
      });
    }
  }

  Future<void> report({String? postId, String? commentId, String? reason}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    await _client.from('community_reports').insert({
      'reporter_id': uid,
      'post_id': postId,
      'comment_id': commentId,
      'reason': reason,
    });
  }

  Future<String> uploadImage(Uint8List bytes, String ext) async {
    const bucket = 'community';
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<List<String>> fetchBannedWords() async {
    final rows = await _client.from('community_banned_words').select('word');
    return (rows as List<dynamic>)
        .map((e) => (e as Map<String, dynamic>)['word'] as String)
        .toList();
  }
}
