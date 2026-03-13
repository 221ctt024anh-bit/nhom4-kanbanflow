import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../app_preferences.dart';

import '../../domain/entities/board.dart';
import '../blocs/auth/auth_bloc.dart';
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.pop(context); // Close menu
                  Navigator.pushNamed(context, '/my-tasks');
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, color: Colors.blueAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppPreferences.tr('Công việc của tôi', 'My Tasks'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
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
          ],
        ),
      ),
    );
  }

  void _showAddBoardDialog(BuildContext context) {
    final titleController = TextEditingController();
    const accentColor = Colors.blueAccent;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.dashboard_customize_rounded,
                  color: accentColor, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              AppPreferences.tr('Tạo bảng mới', 'Create board'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              AppPreferences.tr('Tên bảng', 'Board Title'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              autofocus: true,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: AppPreferences.tr('Nhập tên bảng...', 'Enter title...'),
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: accentColor, width: 2),
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              AppPreferences.tr('Hủy', 'Cancel'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              final authState = context.read<AuthBloc>().state;
              final userId = authState is Authenticated ? authState.user.id : '';
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
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              AppPreferences.tr('Tạo bảng', 'Create'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteBoardDialog(BuildContext context, Board board) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          AppPreferences.tr('Xác nhận xóa', 'Confirm delete'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        content: Text(
          AppPreferences.tr(
            'Bạn có chắc muốn xóa bảng "${board.title}"?',
            'Are you sure you want to delete board "${board.title}"?',
          ),
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF475569),
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
            ),
            child: Text(
              AppPreferences.tr('Hủy', 'Cancel'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              context.read<BoardBloc>().add(DeleteBoardEvent(board.id));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              AppPreferences.tr('Xóa', 'Delete'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
