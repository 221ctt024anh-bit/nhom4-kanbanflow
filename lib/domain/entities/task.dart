class Task {
  final String id;
  final String boardId;
  final String title;
  final String description;
  final String status; // Trạng thái: 'todo', 'doing', 'done'
  final String createdAt;

  const Task({
    required this.id,
    required this.boardId,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
  });
}
