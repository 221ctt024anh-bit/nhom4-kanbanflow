import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/app_notification.dart';

class NotificationRepository {
  final SupabaseClient _client;

  NotificationRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<int> getUnreadCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final response = await _client
        .from('user_notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (response as List).length;
  }

  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('user_notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List).map((item) {
      final map = item as Map<String, dynamic>;
      return AppNotification(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        senderId: map['sender_id'] as String?,
        taskId: map['task_id'] as String?,
        commentId: map['comment_id'] as String?,
        title: (map['title'] as String?) ?? '',
        message: (map['message'] as String?) ?? '',
        isRead: (map['is_read'] as bool?) ?? false,
        createdAt: (map['created_at'] as String?) ?? '',
      );
    }).toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('user_notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('user_notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<void> createNotification({
    required String userId,
    String? taskId,
    String? commentId,
    required String title,
    required String message,
  }) async {
    await _client.from('user_notifications').insert({
      'user_id': userId,
      'task_id': taskId,
      'comment_id': commentId,
      'title': title,
      'message': message,
      'is_read': false,
    });
  }
}
