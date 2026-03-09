class FriendRequest {
  final String id;
  final String senderId;
  final String recipientId;
  final String status;
  final String createdAt;
  final String? respondedAt;
  final String senderEmail;
  final String? senderDisplayName;
  final String? senderAvatarUrl;

  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.status,
    required this.createdAt,
    required this.respondedAt,
    required this.senderEmail,
    required this.senderDisplayName,
    this.senderAvatarUrl,
  });
}
