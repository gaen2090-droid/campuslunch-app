import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/collection.dart';
import '../models/community_comment.dart';
import '../models/community_inbox_notification.dart';
import '../models/community_notice.dart';
import '../models/community_post.dart';
import '../services/supabase_service.dart';

class CommunityRepository {
  CommunityRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<CommunityPost>> fetchFeed({
    DateTime? before,
    int limit = 20,
    String? query,
  }) async {
    final rows = await _client.rpc('community_feed', params: {
      'p_limit': limit,
      'p_before': before?.toIso8601String(),
      'p_query': (query == null || query.trim().isEmpty) ? null : query.trim(),
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

  Future<List<CommunityComment>> fetchCollectionComments(String collectionId) async {
    final rows = await _client.rpc('collection_comments_for_collection', params: {
      'p_collection_id': collectionId,
    });
    return (rows as List<dynamic>)
        .map((e) => CommunityComment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addCollectionComment(String collectionId, String content) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    await _client.from('collection_comments').insert({
      'collection_id': collectionId,
      'user_id': uid,
      'content': content,
    });
  }

  Future<void> deleteCollectionComment(String commentId) async {
    await _client.from('collection_comments').delete().eq('id', commentId);
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

  Future<void> addComment(
    String postId,
    String content, {
    String? parentCommentId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    await _client.rpc('add_community_comment', params: {
      'p_post_id': postId,
      'p_content': content,
      'p_parent_comment_id': parentCommentId,
    });
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('community_comments').delete().eq('id', commentId);
  }

  Future<void> toggleCommentLike(String commentId, bool currentlyLiked) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    if (currentlyLiked) {
      await _client
          .from('community_comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', uid);
    } else {
      await _client.from('community_comment_likes').insert({
        'comment_id': commentId,
        'user_id': uid,
      });
    }
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

  Future<List<RestaurantCollection>> fetchCollections() async {
    final rows = await _client.rpc('collections_with_likes');
    return (rows as List<dynamic>)
        .map((e) => RestaurantCollection.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> toggleCollectionLike(String collectionId, bool currentlyLiked) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    if (currentlyLiked) {
      await _client
          .from('collection_likes')
          .delete()
          .eq('collection_id', collectionId)
          .eq('user_id', uid);
    } else {
      await _client.from('collection_likes').insert({
        'collection_id': collectionId,
        'user_id': uid,
      });
    }
  }

  Future<CommunityNotice?> fetchActiveNotice() async {
    final rows = await _client
        .from('community_notices')
        .select('id, content')
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1);
    final list = rows as List<dynamic>;
    if (list.isEmpty) return null;
    return CommunityNotice.fromMap(list.first as Map<String, dynamic>);
  }

  Future<List<CommunityPost>> fetchMyPosts() async {
    final rows = await _client.rpc('community_my_posts');
    return (rows as List<dynamic>)
        .map((e) => CommunityPost.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CommunityPost>> fetchMyCommentedPosts() async {
    final rows = await _client.rpc('community_my_commented_posts');
    return (rows as List<dynamic>)
        .map((e) => CommunityPost.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> isSubscribed(String postId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final rows = await _client
        .from('community_post_subscriptions')
        .select('post_id')
        .eq('post_id', postId)
        .eq('user_id', uid)
        .limit(1);
    return (rows as List<dynamic>).isNotEmpty;
  }

  Future<void> setSubscribed(String postId, bool subscribed) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    if (subscribed) {
      await _client.from('community_post_subscriptions').insert({
        'post_id': postId,
        'user_id': uid,
      });
    } else {
      await _client
          .from('community_post_subscriptions')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
    }
  }

  Future<List<CommunityInboxNotification>> fetchInboxNotifications() async {
    final rows = await _client.rpc('community_inbox_notifications');
    return (rows as List<dynamic>)
        .map((e) => CommunityInboxNotification.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<CommunityPost?> fetchPostById(String postId) async {
    final rows = await _client.rpc('community_post_by_id', params: {
      'p_post_id': postId,
    });
    final list = rows as List<dynamic>;
    if (list.isEmpty) return null;
    return CommunityPost.fromMap(list.first as Map<String, dynamic>);
  }

  Future<List<CollectionItem>> fetchCollectionItems(String collectionId) async {
    final rows = await _client
        .from('collection_items')
        .select('id, restaurant_id, note, sort_order')
        .eq('collection_id', collectionId)
        .order('sort_order', ascending: true);
    return (rows as List<dynamic>)
        .map((e) => CollectionItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
