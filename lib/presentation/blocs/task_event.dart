abstract class TaskEvent {}

class LoadTasksEvent extends TaskEvent {}

class AddTaskEvent extends TaskEvent {
  final String title;
  final String status;

  AddTaskEvent({required this.title, required this.status});
}
