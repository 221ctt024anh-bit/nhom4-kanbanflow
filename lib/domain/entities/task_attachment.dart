class TaskAttachment {
  final String id;
  final String taskId;
  final String fileName;
  final String filePath;
  final String publicUrl;
  final String uploaderId;
  final String createdAt;

  const TaskAttachment({
    required this.id,
    required this.taskId,
    required this.fileName,
    required this.filePath,
    required this.publicUrl,
    required this.uploaderId,
    required this.createdAt,
  });
}
