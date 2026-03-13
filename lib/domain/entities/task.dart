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
  final String updatedAt;
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
    String? updatedAt,
    this.checklist = const [],
    this.hasAttachments = false,
    this.taskType = 'text',
  }) : updatedAt = updatedAt ?? createdAt;

  Task copyWith({
    String? id,
    String? boardId,
    String? title,
    String? description,
    String? status,
    List<String>? assigneeIds,
    String? creatorId,
    DateTime? dueAt,
    String? createdAt,
    String? updatedAt,
    List<ChecklistItem>? checklist,
    bool? hasAttachments,
    String? taskType,
  }) {
    return Task(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      creatorId: creatorId ?? this.creatorId,
      dueAt: dueAt ?? this.dueAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      checklist: checklist ?? this.checklist,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      taskType: taskType ?? this.taskType,
    );
  }
}
