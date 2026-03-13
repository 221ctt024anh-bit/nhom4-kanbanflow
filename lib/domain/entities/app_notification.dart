class AppNotification {
  final String id;
  final String userId;
  final String? senderId;
  final String? taskId;
  final String? commentId;
  final String title;
  final String message;
  final bool isRead;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    this.senderId,
    required this.taskId,
    required this.commentId,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });
}
