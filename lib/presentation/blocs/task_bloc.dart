import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/task.dart';
import '../../domain/usecases/task_usecases.dart';

part 'task_event.dart';
part 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final GetTasksUseCase getTasksUseCase;
  final AddTaskUseCase addTaskUseCase;
  final UpdateTaskUseCase updateTaskUseCase;
  final DeleteTaskUseCase deleteTaskUseCase;
  final SearchTasksUseCase searchTasksUseCase;

  TaskBloc({
    required this.getTasksUseCase,
    required this.addTaskUseCase,
    required this.updateTaskUseCase,
    required this.deleteTaskUseCase,
    required this.searchTasksUseCase,
  }) : super(TaskInitial()) {
    on<LoadTasks>(_onLoadTasks);
    on<AddNewTask>(_onAddNewTask);
    on<UpdateExistingTask>(_onUpdateExistingTask);
    on<DeleteExistingTask>(_onDeleteExistingTask);
    on<SearchTasksEvent>(_onSearchTasks);
  }

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TaskState> emit) async {
    emit(TaskLoading());
    try {
      final tasks = await getTasksUseCase();
      emit(TaskLoaded(tasks));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onAddNewTask(AddNewTask event, Emitter<TaskState> emit) async {
    try {
      await addTaskUseCase(event.task);
      add(LoadTasks()); // Refresh list after adding
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onUpdateExistingTask(
    UpdateExistingTask event,
    Emitter<TaskState> emit,
  ) async {
    try {
      await updateTaskUseCase(event.task);
      add(LoadTasks()); // Refresh list after updating
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onDeleteExistingTask(
    DeleteExistingTask event,
    Emitter<TaskState> emit,
  ) async {
    try {
      await deleteTaskUseCase(event.id);
      add(LoadTasks()); // Refresh list after deleting
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }

  Future<void> _onSearchTasks(
    SearchTasksEvent event,
    Emitter<TaskState> emit,
  ) async {
    emit(TaskLoading());
    try {
      final tasks = await searchTasksUseCase(event.keyword);
      emit(TaskLoaded(tasks));
    } catch (e) {
      emit(TaskError(e.toString()));
    }
  }
}
