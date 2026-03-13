import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Thêm để cấu hình thanh trạng thái
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'app_preferences.dart';
import 'core/constants/supabase_constants.dart';
import 'injection_container.dart' as di;
import 'data/repositories/user_settings_repository.dart';
import 'core/services/notification_service.dart';
import 'core/services/supabase_notification_listener.dart';
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/auth/auth_event.dart';
import 'presentation/blocs/auth/auth_state.dart';
import 'presentation/blocs/board_bloc.dart';
import 'presentation/blocs/board_event.dart';
import 'presentation/blocs/task_bloc.dart';
import 'presentation/blocs/task_event.dart';
import 'presentation/screens/board_screen.dart';
import 'presentation/screens/friends_screen.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/my_profile_screen.dart';
import 'presentation/screens/reset_password_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/web_task_view_screen.dart';
import 'presentation/screens/my_tasks_screen.dart';
import 'data/repositories/friend_repository.dart';

Future<void> main() async {
  // 1. Khởi tạo binding của Flutter đầu tiên
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Cấu hình định hướng và giao diện hệ thống cho iOS/Android
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  try {
    // 3. Khởi tạo Supabase với Timeout để tránh treo màn hình trắng do mạng
    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      anonKey: SupabaseConstants.supabaseAnonKey,
    ).timeout(const Duration(seconds: 10));

    // 4. Khởi tạo Database cho Desktop
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // 5. Khởi tạo Dependency Injection & Services
    // Chúng ta dùng try-catch riêng để đảm bảo runApp luôn được gọi
    await di.init();
    await NotificationService.init();

  } catch (e) {
    debugPrint('Critical Initialization Error: $e');
    // Bạn có thể hiện một thông báo lỗi ở đây nếu muốn
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription? _authSubscription;
  bool _openingRecoveryScreen = false;
  
  // Sử dụng delayed initialization cho các repository từ DI
  late final FriendRepository _friendRepository;
  final UserSettingsRepository _settingsRepository = UserSettingsRepository();
  
  Timer? _presenceTimer;
  String? _preferencesLoadedForUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Khởi tạo repository từ service locator
    _friendRepository = di.sl<FriendRepository>();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      _handleAuthStateChange(data);
    });

    unawaited(_syncAppPreferences());
    _startPresenceHeartbeat();
  }

  void _handleAuthStateChange(AuthState data) async {
    unawaited(_syncAppPreferences());
    
    if (data.event == AuthChangeEvent.passwordRecovery && !_openingRecoveryScreen) {
      _openingRecoveryScreen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _navigatorKey.currentState?.pushNamed('/reset-password');
        _openingRecoveryScreen = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _presenceTimer?.cancel();
    unawaited(_setPresence(false));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_setPresence(true));
    } else {
      unawaited(_setPresence(false));
    }
  }

  void _startPresenceHeartbeat() {
    unawaited(_setPresence(true));
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _setPresence(true);
    });
  }

  Future<void> _setPresence(bool isOnline) async {
    try {
      await _friendRepository.updateMyPresence(isOnline: isOnline);
    } catch (e) {
      debugPrint('Presence error: $e');
    }
  }

  Future<void> _syncAppPreferences() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _preferencesLoadedForUserId = null;
      AppPreferences.apply(themeMode: 'system', languageCode: 'vi');
      return;
    }

    if (_preferencesLoadedForUserId == user.id) return;
    try {
      final settings = await _settingsRepository.getSettings(user.id);
      AppPreferences.apply(
        themeMode: settings.themeMode,
        languageCode: settings.languageCode,
      );
      _preferencesLoadedForUserId = user.id;
    } catch (e) {
      debugPrint('Preference sync error: $e');
    }
  }

  // --- THEME DATA ---
  static final _lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
    useMaterial3: true,
    textTheme: GoogleFonts.interTextTheme(),
    scaffoldBackgroundColor: const Color(0xFFF4F7FC),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      centerTitle: true,
    ),
  );

  static final _darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
    useMaterial3: true,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
  );

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => di.sl<AuthBloc>()..add(CheckAuthStatus()),
        ),
        BlocProvider<TaskBloc>(
          create: (_) => di.sl<TaskBloc>()..add(LoadTasks()),
        ),
        BlocProvider<BoardBloc>(
          create: (_) => di.sl<BoardBloc>()..add(LoadBoards()),
        ),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            SupabaseNotificationListener.start(state.user.id);
            context.read<BoardBloc>().add(WatchBoards());
            context.read<TaskBloc>().add(LoadTasks());
            
            // Xóa toàn bộ stack cũ khi login thành công để tránh nút Back quay lại màn Login
            _navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
          } else if (state is Unauthenticated) {
            SupabaseNotificationListener.stop();
            context.read<BoardBloc>().add(ResetBoards());
            context.read<TaskBloc>().add(ResetTasks());
          }
        },
        child: ValueListenableBuilder<AppPreferencesState>(
          valueListenable: AppPreferences.notifier,
          builder: (context, prefs, _) => MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'TaskMate',
            debugShowCheckedModeBanner: false,
            routes: {
              '/reset-password': (_) => const ResetPasswordScreen(),
              '/settings': (_) => const SettingsScreen(),
              '/profile': (_) => const MyProfileScreen(),
              '/friends': (_) => const FriendsScreen(),
              '/my-tasks': (_) => const MyTasksScreen(),
            },
            locale: prefs.locale,
            supportedLocales: const [Locale('vi'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: prefs.themeMode,
            theme: _lightTheme,
            darkTheme: _darkTheme,
            onGenerateRoute: (settings) {
              if (settings.name != null && settings.name!.startsWith('/task/')) {
                final taskId = settings.name!.replaceFirst('/task/', '');
                return MaterialPageRoute(
                  builder: (context) => WebTaskViewScreen(taskId: taskId),
                );
              }
              return null;
            },
            home: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is Authenticated) {
                  unawaited(_syncAppPreferences());
                  return const BoardScreen();
                }
                return null;
              },
              home: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  if (state is Authenticated) {
                    return const BoardScreen();
                  } else if (state is AuthLoading) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator.adaptive()),
                    );
                  }
                  return const LoginScreen();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}