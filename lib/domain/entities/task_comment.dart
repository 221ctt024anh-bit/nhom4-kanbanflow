class TaskComment {
  final String id;
  final String taskId;
  final String userId;
  final String content;
  final String createdAt;

  const TaskComment({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });
}
