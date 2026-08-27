import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/blocked_user.dart';
import '../models/collection.dart';
import '../models/community_comment.dart';
import '../models/community_inbox_notification.dart';
import '../models/community_notice.dart';
import '../models/community_poll_option.dart';
import '../models/community_post.dart';
import '../services/supabase_service.dart';

class CommunityRepository {
  static CommunityRepository? _shared;

  factory CommunityRepository({SupabaseClient? client}) {
    if (client != null) return CommunityRepository._(client);
    return _shared ??= CommunityRepository._(SupabaseService.client);
  }

  CommunityRepository._(this._client);

  final SupabaseClient _client;

  /// 사장님이 커뮤니티에서 활동할 매장을 설정 (null이면 해제)
  Future<void> setActiveOwnerRestaurant(String? restaurantId) async {
    await _client.rpc('set_active_owner_restaurant', params: {
      'p_restaurant_id': restaurantId,
    });
  }

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

  Future<void> addCollectionComment(
    String collectionId,
    String content, {
    String? parentCommentId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    await _client.rpc('add_collection_comment', params: {
      'p_collection_id': collectionId,
      'p_content': content,
      'p_parent_comment_id': parentCommentId,
    });
  }

  Future<void> deleteCollectionComment(String commentId) async {
    await _client.from('collection_comments').delete().eq('id', commentId);
  }

  Future<void> toggleCollectionCommentLike(String commentId, bool currentlyLiked) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    if (currentlyLiked) {
      await _client
          .from('collection_comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', uid);
    } else {
      await _client.from('collection_comment_likes').insert({
        'comment_id': commentId,
        'user_id': uid,
      });
    }
  }

  Future<void> reportCollectionComment(String commentId, {String? reason}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    await _client.rpc('report_collection_comment', params: {
      'p_comment_id': commentId,
      'p_reason': reason,
    });
  }

  /// [pollOptions]가 있으면(2~5개) 게시글 생성 직후 create_poll_for_post RPC로
  /// 투표를 함께 만든다. 게시 후 옵션은 전혀 수정/삭제할 수 없다(§0).
  Future<void> createPost({
    required String content,
    List<String> imageUrls = const [],
    String? restaurantId,
    List<String>? pollOptions,
    bool pollAllowMultiple = false,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    final row = await _client
        .from('community_posts')
        .insert({
          'user_id': uid,
          'content': content,
          'image_urls': imageUrls,
          'restaurant_id': restaurantId,
        })
        .select('id')
        .single();
    if (pollOptions != null && pollOptions.isNotEmpty) {
      await _client.rpc('create_poll_for_post', params: {
        'p_post_id': row['id'] as String,
        'p_options': pollOptions,
        'p_allow_multiple': pollAllowMultiple,
      });
    }
  }

  /// 투표가 아직 없던 글에 한해 [pollOptions]로 최초 1회 투표를 추가할 수 있다.
  /// 이미 투표가 있는 글은 옵션을 바꿀 수 없으므로 [pollOptions]를 무시한다
  /// (호출측에서 이미 has_poll 여부로 UI 진입점을 막아야 함).
  Future<void> updatePost({
    required String postId,
    required String content,
    List<String> imageUrls = const [],
    String? restaurantId,
    List<String>? pollOptions,
    bool pollAllowMultiple = false,
  }) async {
    await _client.from('community_posts').update({
      'content': content,
      'image_urls': imageUrls,
      'restaurant_id': restaurantId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', postId);
    if (pollOptions != null && pollOptions.isNotEmpty) {
      await _client.rpc('create_poll_for_post', params: {
        'p_post_id': postId,
        'p_options': pollOptions,
        'p_allow_multiple': pollAllowMultiple,
      });
    }
  }

  Future<List<CommunityPollOption>> fetchPollOptions(String postId) async {
    final rows = await _client.rpc('community_poll_options_for_post', params: {
      'p_post_id': postId,
    });
    return (rows as List<dynamic>)
        .map((e) => CommunityPollOption.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> submitPollVote(List<String> optionIds) async {
    await _client.rpc('submit_poll_vote', params: {
      'p_option_ids': optionIds,
    });
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

  /// 사용자 차단. 차단 즉시 해당 사용자의 글·댓글이 피드에서 사라지고
  /// (RPC 안에서) 운영자에게 신고가 접수된다. 신고 기록에는 글 또는 댓글 id가
  /// 있어야 하므로, 차단을 실행한 화면의 대상 id를 함께 넘긴다.
  Future<void> blockUser(
    String userId, {
    String? reason,
    String? postId,
    String? commentId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    await _client.rpc('block_user', params: {
      'p_user_id': userId,
      'p_reason': reason,
      'p_post_id': postId,
      'p_comment_id': commentId,
    });
  }

  Future<void> unblockUser(String userId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception('NOT_AUTHENTICATED');
    await _client.rpc('unblock_user', params: {'p_user_id': userId});
  }

  Future<List<BlockedUser>> fetchBlockedUsers() async {
    final rows = await _client.rpc('my_blocked_users');
    return (rows as List<dynamic>)
        .map((e) => BlockedUser.fromMap(e as Map<String, dynamic>))
        .toList();
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

  Future<List<String>> fetchNicknameBannedWords() async {
    final rows = await _client.from('nickname_banned_words').select('word');
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

  Future<int> myCrowdReportCount() async {
    final result = await _client.rpc('my_crowd_report_count');
    return (result as num?)?.toInt() ?? 0;
  }

  Future<String> createUserCollection({
    required String title,
    String? subtitle,
    required List<String> restaurantIds,
  }) async {
    final id = await _client.rpc('create_user_collection', params: {
      'p_title': title,
      'p_subtitle': subtitle,
      'p_restaurant_ids': restaurantIds,
    });
    return id as String;
  }

  Future<void> updateUserCollection({
    required String collectionId,
    required String title,
    String? subtitle,
    required List<String> restaurantIds,
  }) async {
    await _client.rpc('update_user_collection', params: {
      'p_collection_id': collectionId,
      'p_title': title,
      'p_subtitle': subtitle,
      'p_restaurant_ids': restaurantIds,
    });
  }

  Future<void> reportCollection(String collectionId, {String? reason}) async {
    await _client.rpc('report_collection', params: {
      'p_collection_id': collectionId,
      'p_reason': reason,
    });
  }

  Future<void> deleteCollection(String collectionId) async {
    await _client.from('collections').delete().eq('id', collectionId);
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

  Future<List<CommunityPost>> fetchPinnedPosts() async {
    final rows = await _client.rpc('community_pinned_posts');
    return (rows as List<dynamic>)
        .map((e) => CommunityPost.fromMap(e as Map<String, dynamic>))
        .toList();
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
    final results = await Future.wait([
      _client.rpc('community_inbox_notifications'),
      _client.rpc('collection_inbox_notifications'),
    ]);
    final communityRows = (results[0] as List<dynamic>)
        .map((e) => CommunityInboxNotification.fromMap(e as Map<String, dynamic>))
        .toList();
    final collectionRows = (results[1] as List<dynamic>)
        .map((e) => CommunityInboxNotification.fromMap(
              e as Map<String, dynamic>,
              isCollection: true,
            ))
        .toList();
    final merged = [...communityRows, ...collectionRows]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  /// 커뮤니티 메뉴 → 이용 제한 내역. 알림창과 같은 모델을 재사용하기 위해
  /// my_suspension_history()의 컬럼을 CommunityInboxNotification.fromMap이
  /// 기대하는 형태로 맞춰서 넘긴다.
  Future<List<CommunityInboxNotification>> fetchSuspensionHistory() async {
    final rows = await _client.rpc('my_suspension_history') as List<dynamic>;
    return rows.map((e) {
      final row = e as Map<String, dynamic>;
      return CommunityInboxNotification.fromMap({
        'kind': row['kind'],
        'event_id': row['event_id'],
        'post_id': null,
        'post_content': null,
        'actor_nickname': '캠런관리자',
        'body_text': row['reason'] ?? '',
        'created_at': row['created_at'],
        'is_read': true,
        'suspended_until': row['suspended_until'],
      });
    }).toList();
  }

  /// 홈 화면 진입 시 "정지/해제 이후 아직 팝업으로 확인 안 한" 알림 1건.
  /// 없으면 null.
  Future<CommunityInboxNotification?> fetchPendingSuspensionPopup() async {
    final rows =
        await _client.rpc('my_pending_suspension_popup') as List<dynamic>;
    if (rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    return CommunityInboxNotification.fromMap({
      'kind': row['kind'],
      'event_id': row['event_id'],
      'post_id': null,
      'post_content': null,
      'actor_nickname': '캠런관리자',
      'body_text': row['reason'] ?? '',
      'created_at': row['created_at'],
      'is_read': false,
      'suspended_until': row['suspended_until'],
    });
  }

  Future<void> markSuspensionPopupSeen(String eventId) async {
    await _client.rpc('mark_suspension_popup_seen', params: {
      'p_event_id': eventId,
    });
  }

  Future<bool> hasUnreadInboxNotifications() async {
    final result = await _client.rpc('community_inbox_has_unread');
    return result as bool? ?? false;
  }

  Future<void> markInboxNotificationRead(String eventId) async {
    await _client.rpc('mark_community_inbox_read', params: {
      'p_event_id': eventId,
    });
  }

  Future<void> markInboxSeen() async {
    await _client.rpc('mark_community_inbox_seen');
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
