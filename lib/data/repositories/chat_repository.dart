import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/direct_message.dart';

class ChatRepository {
  final SupabaseClient _client;

  ChatRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Bạn cần đăng nhập để dùng chat.');
    }
    return userId;
  }

  static String buildConversationId(String userA, String userB) {
    return userA.compareTo(userB) < 0 ? '${userA}_$userB' : '${userB}_$userA';
  }

  Stream<List<DirectMessage>> streamConversation(String friendId) {
    final currentUserId = _requireUserId();
    final conversationId = buildConversationId(currentUserId, friendId);

    return _client
        .from('direct_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((rows) {
          final messages = rows
              .map((row) => DirectMessage(
                    id: row['id'] as String,
                    conversationId: row['conversation_id'] as String,
                    senderId: row['sender_id'] as String,
                    recipientId: row['recipient_id'] as String,
                    content: row['content'] as String,
                    createdAt: row['created_at'] as String,
                    isRead: (row['is_read'] as bool?) ?? false,
                    readAt: row['read_at'] as String?,
                  ))
              .toList();
          messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return messages;
        });
  }

  Future<void> sendMessage({
    required String friendId,
    required String content,
  }) async {
    final currentUserId = _requireUserId();
    final cleaned = content.trim();
    if (cleaned.isEmpty) return;

    await _client.from('direct_messages').insert({
      'conversation_id': buildConversationId(currentUserId, friendId),
      'sender_id': currentUserId,
      'recipient_id': friendId,
      'content': cleaned,
    });
  }

  Future<void> markConversationRead(String friendId) async {
    final currentUserId = _requireUserId();
    final conversationId = buildConversationId(currentUserId, friendId);
    await _client
        .from('direct_messages')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toIso8601String(),
        })
        .eq('conversation_id', conversationId)
        .eq('recipient_id', currentUserId)
        .eq('is_read', false);
  }
}
