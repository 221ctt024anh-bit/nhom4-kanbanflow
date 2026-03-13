import '../entities/task.dart';

class AssignedTaskView {
  final Task task;
  final String boardTitle;

  const AssignedTaskView({
    required this.task,
    required this.boardTitle,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssignedTaskView &&
          runtimeType == other.runtimeType &&
          task.id == other.task.id &&
          boardTitle == other.boardTitle;

  @override
  int get hashCode => task.id.hashCode ^ boardTitle.hashCode;
}
