import 'package:get_it/get_it.dart';

import 'data/datasources/local_database.dart';
import 'data/repositories/task_repository_impl.dart';
import 'domain/repositories/task_repository.dart';
import 'domain/usecases/task_usecases.dart';
import 'presentation/blocs/task_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  /// DataSource
  sl.registerLazySingleton<LocalDatabase>(() => LocalDatabase());

  /// Repository
  sl.registerLazySingleton<TaskRepository>(() => TaskRepositoryImpl(sl()));

  /// UseCases
  sl.registerLazySingleton<TaskUseCases>(() => TaskUseCases(sl()));

  /// Bloc
  sl.registerFactory<TaskBloc>(() => TaskBloc(sl()));
}
