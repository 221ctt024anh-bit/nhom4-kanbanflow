import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:kanban_flow/features/kanban/domain/entities/column_entity.dart';
import 'package:kanban_flow/features/kanban/domain/entities/task_entity.dart';
import 'package:kanban_flow/features/kanban/domain/usecases/kanban_usecases.dart';
import 'task_event.dart';
import 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final GetColumns getColumns;
  final GetTasks getTasks;
  final CreateColumn createColumn;
  final DeleteColumn deleteColumn;
  final CreateTask createTask;
  final UpdateTask updateTask;
  final DeleteTask deleteTask;
  final SearchTasks searchTasks;

  String? currentBoardId;

  TaskBloc({
    required this.getColumns,
    required this.getTasks,
    required this.createColumn,
    required this.deleteColumn,
    required this.createTask,
    required this.updateTask,
    required this.deleteTask,
    required this.searchTasks,
  }) : super(TaskInitial()) {
    on<LoadTasksEvent>(_onLoadTasks);
    on<AddColumnEvent>(_onAddColumn);
    on<DeleteColumnEvent>(_onDeleteColumn);
    on<AddTaskEvent>(_onAddTask);
    on<UpdateTaskEvent>(_onUpdateTask);
    on<DeleteTaskEvent>(_onDeleteTask);
    on<MoveTaskEvent>(_onMoveTask);
    on<SearchTasksEvent>(_onSearchTasks);
  }

  Future<void> _onLoadTasks(
    LoadTasksEvent event,
    Emitter<TaskState> emit,
  ) async {
    emit(TaskLoading());
    currentBoardId = event.boardId;
    final columnResult = await getColumns(event.boardId);

    await columnResult.fold(
      (failure) async => emit(TaskError(failure.message)),
      (columns) async {
        final Map<String, List<TaskEntity>> tasksMap = {};
        for (final column in columns) {
          final taskResult = await getTasks(column.id);
          taskResult.fold(
            (failure) => {}, // Skip error loading specific column tasks
            (tasks) => tasksMap[column.id] = tasks,
          );
        }
        emit(TaskLoaded(columns: columns, tasks: tasksMap));
      },
    );
  }

  Future<void> _onAddColumn(
    AddColumnEvent event,
    Emitter<TaskState> emit,
  ) async {
    final column = ColumnEntity(
      id: const Uuid().v4(),
      title: event.title,
      boardId: event.boardId,
      order: 0, // Should be calculated
    );
    final result = await createColumn(column);
    result.fold(
      (failure) => emit(TaskError(failure.message)),
      (_) => add(LoadTasksEvent(event.boardId)),
    );
  }

  Future<void> _onDeleteColumn(
    DeleteColumnEvent event,
    Emitter<TaskState> emit,
  ) async {
    final result = await deleteColumn(event.columnId);
    result.fold(
      (failure) => emit(TaskError(failure.message)),
      (_) =>
          currentBoardId != null ? add(LoadTasksEvent(currentBoardId!)) : null,
    );
  }

  Future<void> _onAddTask(AddTaskEvent event, Emitter<TaskState> emit) async {
    final task = TaskEntity(
      id: const Uuid().v4(),
      title: event.title,
      description: event.description,
      columnId: event.columnId,
      order: 0, // Should be calculated
      createdAt: DateTime.now(),
    );
    final result = await createTask(task);
    result.fold(
      (failure) => emit(TaskError(failure.message)),
      (_) =>
          currentBoardId != null ? add(LoadTasksEvent(currentBoardId!)) : null,
    );
  }

  Future<void> _onUpdateTask(
    UpdateTaskEvent event,
    Emitter<TaskState> emit,
  ) async {
    final result = await updateTask(event.task);
    result.fold(
      (failure) => emit(TaskError(failure.message)),
      (_) =>
          currentBoardId != null ? add(LoadTasksEvent(currentBoardId!)) : null,
    );
  }

  Future<void> _onDeleteTask(
    DeleteTaskEvent event,
    Emitter<TaskState> emit,
  ) async {
    final result = await deleteTask(event.taskId);
    result.fold(
      (failure) => emit(TaskError(failure.message)),
      (_) =>
          currentBoardId != null ? add(LoadTasksEvent(currentBoardId!)) : null,
    );
  }

  Future<void> _onMoveTask(MoveTaskEvent event, Emitter<TaskState> emit) async {
    if (state is TaskLoaded) {
      final loadedState = state as TaskLoaded;
      // Optimistic update logic could go here, but for now let's just make it simple.
      // We need to fetch the task first to update its columnId and order.
      // But we don't have getTaskById usecase.
      // Let's assume we have access to it from board state.

      TaskEntity? taskToMove;
      for (final list in loadedState.tasks.values) {
        for (final t in list) {
          if (t.id == event.taskId) {
            taskToMove = t;
            break;
          }
        }
        if (taskToMove != null) break;
      }

      if (taskToMove != null) {
        final updatedTask = TaskEntity(
          id: taskToMove.id,
          title: taskToMove.title,
          description: taskToMove.description,
          columnId: event.newColumnId, // Change column
          order: event.newOrder, // Change order
          createdAt: taskToMove.createdAt,
        );
        final result = await updateTask(updatedTask);
        result.fold(
          (failure) => emit(TaskError(failure.message)),
          (_) => currentBoardId != null
              ? add(LoadTasksEvent(currentBoardId!))
              : null,
        );
      }
    }
  }

  Future<void> _onSearchTasks(
    SearchTasksEvent event,
    Emitter<TaskState> emit,
  ) async {
    if (event.query.isEmpty) {
      if (state is TaskLoaded) {
        emit((state as TaskLoaded).copyWith(searchResults: []));
      }
      return;
    }

    final result = await searchTasks(event.query);
    result.fold((failure) => emit(TaskError(failure.message)), (tasks) {
      if (state is TaskLoaded) {
        emit((state as TaskLoaded).copyWith(searchResults: tasks));
      }
    });
  }
}
