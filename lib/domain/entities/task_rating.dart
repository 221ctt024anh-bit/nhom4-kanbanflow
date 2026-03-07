class TaskRating {
  final String id;
  final String taskId;
  final String userId;
  final int rating;
  final String createdAt;
  final String updatedAt;

  const TaskRating({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
  });
}
