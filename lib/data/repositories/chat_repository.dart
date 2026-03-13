import 'dart:typed_data';

import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/direct_message.dart';

class ChatRepository {
  static const String chatImagesBucket = 'chat-images';

  final SupabaseClient _client;

  ChatRepository({
    SupabaseClient? client,
  }) : _client = client ?? Supabase.instance.client;

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Ban can dang nhap de dung chat.');
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
              .map(
                (row) => DirectMessage(
                  id: row['id'] as String,
                  conversationId: row['conversation_id'] as String,
                  senderId: row['sender_id'] as String,
                  recipientId: row['recipient_id'] as String,
                  content: row['content'] as String,
                  createdAt: row['created_at'] as String,
                  isRead: (row['is_read'] as bool?) ?? false,
                  readAt: row['read_at'] as String?,
                  messageType: (row['message_type'] as String?) ?? 'text',
                ),
              )
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

    await _insertDirectMessage(
      friendId: friendId,
      senderId: currentUserId,
      content: cleaned,
      messageType: 'text',
    );
  }

  Future<void> markConversationRead(String friendId) async {
    final currentUserId = _requireUserId();
    final conversationId = buildConversationId(currentUserId, friendId);
    await _client
        .from('direct_messages')
        .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('recipient_id', currentUserId)
        .eq('is_read', false);
  }

  Future<String> uploadChatImage({
    required String friendId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final currentUserId = _requireUserId();
    final conversationId = buildConversationId(currentUserId, friendId);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final filePath = '$conversationId/${timestamp}_$safeName';
    final contentType = lookupMimeType(fileName) ?? 'image/jpeg';

    await _client.storage.from(chatImagesBucket).uploadBinary(
      filePath,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        cacheControl: '3600',
        upsert: false,
      ),
    );

    return _client.storage.from(chatImagesBucket).getPublicUrl(filePath);
  }

  Future<void> sendImageMessage({
    required String friendId,
    required String imageUrl,
  }) async {
    final currentUserId = _requireUserId();
    await _insertDirectMessage(
      friendId: friendId,
      senderId: currentUserId,
      content: imageUrl,
      messageType: 'image',
    );
  }

  Future<void> _insertDirectMessage({
    required String friendId,
    required String senderId,
    required String content,
    required String messageType,
  }) async {
    final payload = {
      'conversation_id': buildConversationId(senderId, friendId),
      'sender_id': senderId,
      'recipient_id': friendId,
      'content': content,
      'message_type': messageType,
    };

    try {
      await _client.from('direct_messages').insert(payload);
    } on PostgrestException catch (error) {
      // Backward-compatible fallback if the server has not added message_type yet.
      if (error.code == 'PGRST204' &&
          error.message.contains('message_type column')) {
        final fallbackPayload = Map<String, dynamic>.from(payload)
          ..remove('message_type');
        await _client.from('direct_messages').insert(fallbackPayload);
        return;
      }
      rethrow;
    }
  }
}
