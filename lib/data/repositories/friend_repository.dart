import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/friend_request.dart';
import '../../domain/entities/friend_user.dart';
import '../repositories/notification_repository.dart';

class FriendRepository {
  final NotificationRepository notificationRepository;
  final SupabaseClient _client;

  FriendRepository({
    SupabaseClient? client,
    required this.notificationRepository,
  }) : _client = client ?? Supabase.instance.client;

  String _requireUserId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw Exception('Bạn cần đăng nhập để thực hiện thao tác này.');
    }
    return id;
  }

  bool _isMissingColumnError(Object error) {
    return error is PostgrestException && error.code == '42703';
  }

  Future<T> _retry<T>(Future<T> Function() task, {int maxAttempts = 3}) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        return await task();
      } catch (e) {
        final isNetworkError =
            e.toString().contains('SocketException') ||
            e.toString().contains('ClientException') ||
            e.toString().contains('Connection reset by peer');

        if (attempts >= maxAttempts || !isNetworkError) {
          rethrow;
        }
        await Future.delayed(
          Duration(seconds: attempts),
        ); // Exponential backoff
      }
    }
  }

  Future<void> sendFriendRequestByEmail(String email) async {
    return _retry(() async {
      final currentUserId = _requireUserId();
      final normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail.isEmpty) {
        throw Exception('Email không hợp lệ.');
      }

      final recipientProfile = await _client
          .from('profiles')
          .select('id, email')
          .eq('email', normalizedEmail)
          .maybeSingle();

      if (recipientProfile == null) {
        throw Exception('Không tìm thấy người dùng với email này.');
      }

      final recipientId = recipientProfile['id'] as String;
      if (recipientId == currentUserId) {
        throw Exception('Bạn không thể kết bạn với chính mình.');
      }

      final friendship = await _client
          .from('friendships')
          .select('user_id')
          .eq('user_id', currentUserId)
          .eq('friend_id', recipientId)
          .maybeSingle();
      if (friendship != null) {
        throw Exception('Hai bạn đã là bạn bè.');
      }

      final existingOutgoing = await _client
          .from('friend_requests')
          .select('id')
          .eq('sender_id', currentUserId)
          .eq('recipient_id', recipientId)
          .eq('status', 'pending')
          .maybeSingle();
      if (existingOutgoing != null) {
        throw Exception('Bạn đã gửi lời mời trước đó.');
      }

      final existingIncoming = await _client
          .from('friend_requests')
          .select('id')
          .eq('sender_id', recipientId)
          .eq('recipient_id', currentUserId)
          .eq('status', 'pending')
          .maybeSingle();
      if (existingIncoming != null) {
        throw Exception(
          'Người này đã gửi lời mời cho bạn. Hãy chấp nhận lời mời.',
        );
      }

      await _client.from('friend_requests').insert({
        'sender_id': currentUserId,
        'recipient_id': recipientId,
        'status': 'pending',
      });

      // Notification logic
      try {
        final senderProfile = await _client
            .from('profiles')
            .select('display_name, email')
            .eq('id', currentUserId)
            .maybeSingle();

        final senderName =
            (senderProfile?['display_name'] as String?) ??
            ((senderProfile?['email'] as String?)?.split('@').first ?? 'Ai đó');

        await notificationRepository.createNotification(
          userId: recipientId,
          title: 'Lời mời kết bạn mới',
          message: '$senderName đã gửi cho bạn một lời mời kết bạn.',
        );
      } catch (_) {
        // ignore
      }
    });
  }

  Future<List<FriendUser>> getFriends() async {
    return _retry(() async {
      final currentUserId = _requireUserId();

      final response = await _client
          .from('friendships')
          .select('friend_id')
          .eq('user_id', currentUserId);
      final rows = response as List;
      if (rows.isEmpty) return [];

      final friendIds = rows
          .map((item) => (item as Map<String, dynamic>)['friend_id'] as String)
          .toList();

      List profiles;
      try {
        final response = await _client
            .from('profiles')
            .select(
              'id, email, display_name, avatar_url, bio, is_online, last_seen_at',
            )
            .filter('id', 'in', friendIds);
        profiles = response as List;
      } catch (e) {
        if (!_isMissingColumnError(e)) rethrow;
        final response = await _client
            .from('profiles')
            .select(
              'id, email, display_name, avatar_url, is_online, last_seen_at',
            )
            .filter('id', 'in', friendIds);
        profiles = response as List;
      }

      return profiles.map((p) {
        final map = p as Map<String, dynamic>;
        return FriendUser(
          id: map['id'] as String,
          email: (map['email'] as String?) ?? '',
          displayName: map['display_name'] as String?,
          avatarUrl: map['avatar_url'] as String?,
          bio: map['bio'] as String?,
          isOnline: (map['is_online'] as bool?) ?? false,
          lastSeenAt: map['last_seen_at'] != null
              ? DateTime.tryParse(map['last_seen_at'] as String)
              : null,
        );
      }).toList();
    });
  }

  Future<List<FriendRequest>> getIncomingRequests() async {
    return _retry(() async {
      final currentUserId = _requireUserId();

      final response = await _client
          .from('friend_requests')
          .select()
          .eq('recipient_id', currentUserId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final rows = response as List;
      if (rows.isEmpty) return [];

      final senderIds = rows
          .map((item) => (item as Map<String, dynamic>)['sender_id'] as String)
          .toSet()
          .toList();

      final profilesResponse = await _client
          .from('profiles')
          .select('id, email, display_name, avatar_url')
          .filter('id', 'in', senderIds);
      final profilesList = profilesResponse as List;
      final profileMap = <String, Map<String, dynamic>>{};
      for (final p in profilesList) {
        final map = p as Map<String, dynamic>;
        profileMap[map['id'] as String] = map;
      }

      return rows.map((item) {
        final map = item as Map<String, dynamic>;
        final senderId = map['sender_id'] as String;
        final senderProfile = profileMap[senderId];
        return FriendRequest(
          id: map['id'] as String,
          senderId: senderId,
          recipientId: map['recipient_id'] as String,
          status: map['status'] as String,
          createdAt: (map['created_at'] as String?) ?? '',
          respondedAt: map['responded_at'] as String?,
          senderEmail: (senderProfile?['email'] as String?) ?? '',
          senderDisplayName: senderProfile?['display_name'] as String?,
          senderAvatarUrl: senderProfile?['avatar_url'] as String?,
        );
      }).toList();
    });
  }

  Future<void> respondToRequest({
    required String requestId,
    required bool accept,
  }) async {
    _requireUserId();

    // No manual friendship insertion here.
    // The database trigger 'trg_friend_request_accept' handles it automatically
    // when the status is updated to 'accepted'.

    // 3. Cập nhật trạng thái lời mời
    await _client
        .from('friend_requests')
        .update({
          'status': accept ? 'accepted' : 'rejected',
          'responded_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId)
        .eq('status', 'pending');
  }

  Future<void> removeFriend(String friendId) async {
    final currentUserId = _requireUserId();

    // Xóa quan hệ bạn bè cả 2 chiều
    await _client
        .from('friendships')
        .delete()
        .or(
          'and(user_id.eq.$currentUserId,friend_id.eq.$friendId),and(user_id.eq.$friendId,friend_id.eq.$currentUserId)',
        );

    // Cập nhật trạng thái các lời mời kết bạn liên quan thành 'rejected' hoặc xóa đi để có thể kết bạn lại sau này
    // Ở đây ta xóa để sạch database và cho phép gửi lại invitation mới
    await _client
        .from('friend_requests')
        .delete()
        .or(
          'and(sender_id.eq.$currentUserId,recipient_id.eq.$friendId),and(sender_id.eq.$friendId,recipient_id.eq.$currentUserId)',
        );
  }

  Future<void> updateMyPresence({required bool isOnline}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('profiles')
        .update({
          'is_online': isOnline,
          'last_seen_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);
  }
}
