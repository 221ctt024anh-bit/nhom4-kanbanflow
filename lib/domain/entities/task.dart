class ChecklistItem {
  final String id;
  final String title;
  final bool isDone;

  const ChecklistItem({
    required this.id,
    required this.title,
    this.isDone = false,
  });

  ChecklistItem copyWith({String? id, String? title, bool? isDone}) {
    return ChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'isDone': isDone};

  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    return ChecklistItem(
      id: map['id'] as String,
      title: map['title'] as String,
      isDone: map['isDone'] as bool? ?? false,
    );
  }
}

class Task {
  final String id;
  final String boardId;
  final String title;
  final String description;
  final String status; // Trạng thái: 'todo', 'doing', 'done'
  final List<String> assigneeIds;
  final String? creatorId;
  final DateTime? dueAt;
  final String createdAt;
  final List<ChecklistItem> checklist;
  final bool hasAttachments;
  final String? taskType;

  const Task({
    required this.id,
    required this.boardId,
    required this.title,
    required this.description,
    required this.status,
    this.assigneeIds = const [],
    this.creatorId,
    this.dueAt,
    required this.createdAt,
    this.checklist = const [],
    this.hasAttachments = false,
    this.taskType = 'text',
  });
}
