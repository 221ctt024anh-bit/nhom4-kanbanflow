import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'injection_container.dart' as di;
import 'features/kanban/presentation/blocs/board/board_bloc.dart';
import 'features/kanban/presentation/blocs/board/board_event.dart';
import 'features/kanban/presentation/blocs/task/task_bloc.dart';
import 'features/kanban/presentation/pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  runApp(const KanbanApp());
}

class KanbanApp extends StatelessWidget {
  const KanbanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<BoardBloc>()..add(LoadBoardsEvent())),
        BlocProvider(create: (_) => di.sl<TaskBloc>()),
      ],
      child: MaterialApp(
        title: 'Quản Lý Công Việc',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.outfitTextTheme(),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          ),
          textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
          cardTheme: CardThemeData(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        home: const LoginPage(),
      ),
    );
  }
}
