import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../app_preferences.dart';

import '../../domain/entities/board.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/board_bloc.dart';
import '../blocs/board_event.dart';
import '../blocs/board_state.dart';

class WorkspaceMenuScreen extends StatelessWidget {
  final String? selectedBoardId;

  const WorkspaceMenuScreen({super.key, required this.selectedBoardId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppPreferences.tr('Không gian làm việc', 'Workspace'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddBoardDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        AppPreferences.tr('Tạo bảng mới', 'Create new board'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<BoardBloc, BoardState>(
                builder: (context, state) {
                  if (state is BoardLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is BoardError) {
                    return Center(
                      child: Text(
                        '${AppPreferences.tr('Lỗi', 'Error')}: ${state.message}',
                      ),
                    );
                  }
                  if (state is! BoardLoaded) {
                    return const SizedBox.shrink();
                  }

                  final boards = state.boards;
                  if (boards.isEmpty) {
                    return Center(
                      child: Text(
                        AppPreferences.tr(
                          'Chưa có bảng nào. Tạo bảng mới để bắt đầu.',
                          'No boards yet. Create a new one to start.',
                        ),
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: boards.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final board = boards[index];
                      final selected = board.id == selectedBoardId;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pop(context, board.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.blueAccent.withOpacity(0.12)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? Colors.blueAccent.withOpacity(0.45)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.blueAccent.withOpacity(0.18)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.dashboard_outlined,
                                  color: selected
                                      ? Colors.blueAccent
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  board.title,
                                  style: TextStyle(
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    fontSize: 15,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: AppPreferences.tr('Xóa', 'Delete'),
                                onPressed: () =>
                                    _showDeleteBoardDialog(context, board),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<AuthBloc>().add(SignOutRequested());
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: Text(
                  AppPreferences.tr('Đăng xuất', 'Logout'),
                  style: const TextStyle(color: Colors.redAccent),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.35)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBoardDialog(BuildContext context) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppPreferences.tr('Tạo bảng mới', 'Create new board')),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppPreferences.tr('Tên bảng', 'Board title'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppPreferences.tr('Hủy', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              final authState = context.read<AuthBloc>().state;
              final userId = authState is Authenticated
                  ? authState.user.id
                  : '';
              context.read<BoardBloc>().add(
                AddBoardEvent(
                  Board(
                    id: const Uuid().v4(),
                    title: title,
                    ownerId: userId,
                    createdAt: DateTime.now().toIso8601String(),
                  ),
                ),
              );
              Navigator.pop(context);
            },
            child: Text(AppPreferences.tr('Tạo', 'Create')),
          ),
        ],
      ),
    );
  }

  void _showDeleteBoardDialog(BuildContext context, Board board) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppPreferences.tr('Xác nhận xóa', 'Confirm delete')),
        content: Text(
          AppPreferences.tr(
            'Bạn có chắc muốn xóa bảng "${board.title}"?',
            'Are you sure you want to delete board "${board.title}"?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppPreferences.tr('Hủy', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<BoardBloc>().add(DeleteBoardEvent(board.id));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(AppPreferences.tr('Xóa', 'Delete')),
          ),
        ],
      ),
    );
  }
}
