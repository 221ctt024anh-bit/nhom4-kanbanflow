import 'package:get_it/get_it.dart';
import 'data/datasources/local_database.dart';
import 'data/repositories/task_repository_impl.dart';
import 'data/repositories/notification_repository.dart';
import 'domain/repositories/task_repository.dart';
import 'domain/usecases/task_usecases.dart';
import 'presentation/blocs/task_bloc.dart';

import 'data/repositories/board_repository_impl.dart';
import 'domain/repositories/board_repository.dart';
import 'domain/usecases/board_usecases.dart';
import 'presentation/blocs/board_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/repositories/task_interaction_repository.dart';
import 'data/repositories/friend_repository.dart';
import 'data/repositories/chat_repository.dart';

import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'core/services/ai_service.dart';

// (Nhớ check lại đường dẫn import file task_bloc của bạn cho chuẩn nhé)

final sl = GetIt.instance; // sl viết tắt của Service Locator

Future<void> init() async {
  // 0. Khởi tạo core (Supabase)
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  sl.registerLazySingleton<LocalDatabase>(() => LocalDatabase());
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepository(client: sl()),
  );
  sl.registerLazySingleton<AiService>(() => AiService());

  // 1. Khởi tạo BLoC (Factory: mỗi lần gọi tạo 1 instance mới)
  sl.registerFactory(() => AuthBloc(authRepository: sl()));
  sl.registerFactory(
    () => TaskBloc(
      getTasks: sl(),
      addTask: sl(),
      updateTask: sl(),
      deleteTask: sl(),
    ),
  );
  sl.registerFactory(
    () => BoardBloc(
      getBoards: sl(),
      addBoard: sl(),
      updateBoard: sl(),
      deleteBoard: sl(),
      watchBoards: sl(),
    ),
  );

  // 2. Khởi tạo Use cases (LazySingleton: chỉ tạo 1 lần duy nhất khi cần)
  sl.registerLazySingleton(() => GetTasks(sl()));
  sl.registerLazySingleton(() => AddTask(sl()));
  sl.registerLazySingleton(() => UpdateTask(sl()));
  sl.registerLazySingleton(() => DeleteTask(sl()));

  sl.registerLazySingleton(() => GetBoards(sl()));
  sl.registerLazySingleton(() => AddBoard(sl()));
  sl.registerLazySingleton(() => UpdateBoard(sl()));
  sl.registerLazySingleton(() => DeleteBoard(sl()));
  sl.registerLazySingleton(() => WatchBoardsUseCase(sl()));

  // 3. Khởi tạo Repository
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(supabaseClient: sl()),
  );
  sl.registerLazySingleton<TaskRepository>(
    () => TaskRepositoryImpl(
      supabaseClient: sl(),
      localDatabase: sl(),
      notificationRepository: sl(),
    ),
  );
  sl.registerLazySingleton<BoardRepository>(
    () => BoardRepositoryImpl(supabaseClient: sl(), localDatabase: sl()),
  );
  sl.registerLazySingleton<TaskInteractionRepository>(
    () => TaskInteractionRepository(client: sl(), notificationRepository: sl()),
  );
  sl.registerLazySingleton<FriendRepository>(
    () => FriendRepository(client: sl(), notificationRepository: sl()),
  );
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepository(client: sl(), notificationRepository: sl()),
  );
}
