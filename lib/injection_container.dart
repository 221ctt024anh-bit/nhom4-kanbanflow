import 'package:get_it/get_it.dart';
import 'core/util/hive_helper.dart';
import 'features/kanban/data/datasources/kanban_local_datasource.dart';
import 'features/kanban/data/repositories/kanban_repository_impl.dart';
import 'features/kanban/domain/repositories/kanban_repository.dart';
import 'features/kanban/domain/usecases/board_usecases.dart';
import 'features/kanban/domain/usecases/kanban_usecases.dart';
import 'features/kanban/presentation/blocs/board/board_bloc.dart';
import 'features/kanban/presentation/blocs/task/task_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Blocs
  sl.registerFactory(
    () => BoardBloc(getBoards: sl(), createBoard: sl(), deleteBoard: sl()),
  );
  sl.registerFactory(
    () => TaskBloc(
      getColumns: sl(),
      getTasks: sl(),
      createColumn: sl(),
      deleteColumn: sl(),
      createTask: sl(),
      updateTask: sl(),
      deleteTask: sl(),
      searchTasks: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetBoards(sl()));
  sl.registerLazySingleton(() => CreateBoard(sl()));
  sl.registerLazySingleton(() => DeleteBoard(sl()));
  sl.registerLazySingleton(() => GetColumns(sl()));
  sl.registerLazySingleton(() => GetTasks(sl()));
  sl.registerLazySingleton(() => CreateColumn(sl()));
  sl.registerLazySingleton(() => DeleteColumn(sl()));
  sl.registerLazySingleton(() => CreateTask(sl()));
  sl.registerLazySingleton(() => UpdateTask(sl()));
  sl.registerLazySingleton(() => DeleteTask(sl()));
  sl.registerLazySingleton(() => SearchTasks(sl()));

  // Repository
  sl.registerLazySingleton<KanbanRepository>(
    () => KanbanRepositoryImpl(localDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<KanbanLocalDataSource>(
    () => KanbanLocalDataSourceImpl(),
  );

  // Core (Local Persistence)
  await HiveHelper.init();
}
