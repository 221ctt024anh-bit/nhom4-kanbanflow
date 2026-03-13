import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/task_usecases.dart';
import 'task_event.dart';
import 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final GetTasks getTasks;
  final AddTask addTask;
  final UpdateTask updateTask;
  final DeleteTask deleteTask;

  String? currentBoardId;
  String? currentQuery;
  String? currentStatus;

  TaskBloc({
    required this.getTasks,
    required this.addTask,
    required this.updateTask,
    required this.deleteTask,
  }) : super(TaskInitial()) {
    // Đăng ký các hàm xử lý cho từng sự kiện
    on<LoadTasks>(_onLoadTasks);
    on<AddTaskEvent>(_onAddTask);
    on<UpdateTaskEvent>(_onUpdateTask);
    on<DeleteTaskEvent>(_onDeleteTask);
    on<ResetTasks>((event, emit) {
      currentBoardId = null;
      currentQuery = null;
      currentStatus = null;
      emit(TaskInitial());
    });
  }

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TaskState> emit) async {
    currentBoardId = event.boardId ?? currentBoardId;
    currentQuery = event.query ?? currentQuery;
    currentStatus = event.status ?? currentStatus;

    final currentState = state;
    if (currentState is! TaskLoaded) {
      emit(TaskLoading()); // Chỉ hiện loading nếu chưa có dữ liệu nào
    }
    try {
      final tasks = await getTasks.call(
        boardId: currentBoardId,
        query: currentQuery,
        status: currentStatus,
      );
      emit(TaskLoaded(tasks));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onAddTask(AddTaskEvent event, Emitter<TaskState> emit) async {
    debugPrint('DEBUG: TaskBloc._onAddTask - Title: ${event.task.title}');
    try {
      await addTask.call(event.task);
      add(LoadTasks()); // Thêm xong thì tự động gọi sự kiện LoadTasks để làm mới bảng
    } catch (e) {
      debugPrint('DEBUG: TaskBloc._onAddTask - Error: $e');
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onUpdateTask(
    UpdateTaskEvent event,
    Emitter<TaskState> emit,
  ) async {
    try {
      await updateTask.call(event.task);
      add(LoadTasks());
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onDeleteTask(
    DeleteTaskEvent event,
    Emitter<TaskState> emit,
  ) async {
    debugPrint('DEBUG: TaskBloc._onDeleteTask - ID: ${event.id}');
    try {
      await deleteTask.call(event.id);
      debugPrint('DEBUG: TaskBloc._onDeleteTask - Success, calling LoadTasks');
      add(LoadTasks());
    } catch (e) {
      debugPrint('DEBUG: TaskBloc._onDeleteTask - Error: $e');
      emit(TaskError(e.toString()));
    }
  }
}
