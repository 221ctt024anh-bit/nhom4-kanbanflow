import 'package:equatable/equatable.dart';
import '../../../domain/entities/column_entity.dart';
import '../../../domain/entities/task_entity.dart';

abstract class TaskState extends Equatable {
  const TaskState();
  @override
  List<Object> get props => [];
}

class TaskInitial extends TaskState {}

class TaskLoading extends TaskState {}

class TaskLoaded extends TaskState {
  final List<ColumnEntity> columns;
  final Map<String, List<TaskEntity>> tasks; // columnId -> tasks
  final List<TaskEntity> searchResults;

  const TaskLoaded({
    required this.columns,
    required this.tasks,
    this.searchResults = const [],
  });

  @override
  List<Object> get props => [columns, tasks, searchResults];

  TaskLoaded copyWith({
    List<ColumnEntity>? columns,
    Map<String, List<TaskEntity>>? tasks,
    List<TaskEntity>? searchResults,
  }) {
    return TaskLoaded(
      columns: columns ?? this.columns,
      tasks: tasks ?? this.tasks,
      searchResults: searchResults ?? this.searchResults,
    );
  }
}

class TaskError extends TaskState {
  final String message;
  const TaskError(this.message);
  @override
  List<Object> get props => [message];
}
