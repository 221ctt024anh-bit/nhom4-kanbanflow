class DirectMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String recipientId;
  final String content;
  final String createdAt;
  final bool isRead;
  final String? readAt;

  const DirectMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.createdAt,
    required this.isRead,
    this.readAt,
  });
}
