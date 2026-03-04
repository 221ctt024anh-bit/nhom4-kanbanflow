
part of 'task_bloc.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();

  @override
  List<Object> get props => [];
}

class LoadTasks extends TaskEvent {}

class AddNewTask extends TaskEvent {
  final Task task;
  const AddNewTask(this.task);
}

class UpdateExistingTask extends TaskEvent {
  final Task task;
  const UpdateExistingTask(this.task);
}

class DeleteExistingTask extends TaskEvent {
  final int id;
  const DeleteExistingTask(this.id);
}

class SearchTasksEvent extends TaskEvent {
  final String keyword;
  const SearchTasksEvent(this.keyword);
}