import 'package:equatable/equatable.dart';
import '../../../domain/entities/task_entity.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();
  @override
  List<Object> get props => [];
}

class LoadTasksEvent extends TaskEvent {
  final String boardId;
  const LoadTasksEvent(this.boardId);
  @override
  List<Object> get props => [boardId];
}

class AddColumnEvent extends TaskEvent {
  final String boardId;
  final String title;
  const AddColumnEvent(this.boardId, this.title);
  @override
  List<Object> get props => [boardId, title];
}

class DeleteColumnEvent extends TaskEvent {
  final String columnId;
  const DeleteColumnEvent(this.columnId);
  @override
  List<Object> get props => [columnId];
}

class AddTaskEvent extends TaskEvent {
  final String columnId;
  final String title;
  final String description;
  const AddTaskEvent({
    required this.columnId,
    required this.title,
    required this.description,
  });
  @override
  List<Object> get props => [columnId, title, description];
}

class UpdateTaskEvent extends TaskEvent {
  final TaskEntity task;
  const UpdateTaskEvent(this.task);
  @override
  List<Object> get props => [task];
}

class DeleteTaskEvent extends TaskEvent {
  final String taskId;
  const DeleteTaskEvent(this.taskId);
  @override
  List<Object> get props => [taskId];
}

class MoveTaskEvent extends TaskEvent {
  final String taskId;
  final String newColumnId;
  final int newOrder;
  const MoveTaskEvent({
    required this.taskId,
    required this.newColumnId,
    required this.newOrder,
  });
  @override
  List<Object> get props => [taskId, newColumnId, newOrder];
}

class SearchTasksEvent extends TaskEvent {
  final String query;
  const SearchTasksEvent(this.query);
  @override
  List<Object> get props => [query];
}
