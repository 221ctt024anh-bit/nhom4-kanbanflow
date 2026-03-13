import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app_preferences.dart';
import '../../domain/entities/board.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/board_bloc.dart';
import '../blocs/board_state.dart';

class BoardDrawer extends StatelessWidget {
  final String? selectedBoardId;
  final ValueChanged<String> onSelectBoard;
  final void Function(BuildContext) onAddBoard;
  final void Function(BuildContext, Board) onDeleteBoard;

  const BoardDrawer({
    super.key,
    required this.selectedBoardId,
    required this.onSelectBoard,
    required this.onAddBoard,
    required this.onDeleteBoard,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A), // Dark Slate Background
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hi-Tech Header
          Container(
            padding: const EdgeInsets.only(
              top: 60,
              bottom: 30,
              left: 24,
              right: 24,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFF1E293B), // Subtle divider
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.space_dashboard_rounded,
                    color: Colors.blueAccent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TASKMATE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppPreferences.tr('KHÔNG GIAN LÀM VIỆC', 'WORKSPACE'),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Projects/Boards List
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 24, bottom: 8),
            child: Text(
              AppPreferences.tr('DỰ ÁN CỦA BẠN', 'YOUR PROJECTS'),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<BoardBloc, BoardState>(
              builder: (context, state) {
                if (state is BoardLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  );
                } else if (state is BoardLoaded) {
                  final boards = state.boards;
                  if (boards.isEmpty) {
                    return Center(
                      child: Text(
                        AppPreferences.tr(
                          'Chưa có dữ liệu bảng.',
                          'No board data available.',
                        ),
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: boards.length,
                    itemBuilder: (context, index) {
                      final board = boards[index];
                      final isSelected = board.id == selectedBoardId;
                      final role = state.getRole(board.id);
                      final canDelete = role == 'owner' || role == 'admin';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1E293B) // Muted blue glow
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF334155)
                                : Colors.transparent,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              onSelectBoard(board.id);
                              Navigator.pop(context); // Close drawer
                            },
                            child: Row(
                              children: [
                                // Glowing active indicator line
                                Container(
                                  width: 4,
                                  height: 24,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF3B82F6) // Neon blue
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(4),
                                      bottomRight: Radius.circular(4),
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF3B82F6,
                                              ).withOpacity(0.6),
                                              blurRadius: 6,
                                            ),
                                          ]
                                        : [],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.folder_copy_rounded,
                                  color: isSelected
                                      ? const Color(0xFF60A5FA)
                                      : const Color(0xFF64748B),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    board.title,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(
                                              0xFF94A3B8,
                                            ), // Light slate
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (canDelete)
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: isSelected
                                          ? Colors.redAccent.withOpacity(0.8)
                                          : const Color(
                                              0xFF475569,
                                            ), // Darker red/grey until hover
                                      size: 20,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    constraints: const BoxConstraints(),
                                    onPressed: () =>
                                        onDeleteBoard(context, board),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else if (state is BoardError) {
                  return Center(
                    child: Text(
                      '${AppPreferences.tr('Lỗi', 'Error')}: ${state.message}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),

          // Add Board Button (Cyberpunk/Dashed style)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                onAddBoard(context);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Color(0xFF60A5FA),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppPreferences.tr('KHỞI TẠO BẢNG', 'CREATE BOARD'),
                      style: const TextStyle(
                        color: Color(0xFF60A5FA),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Nút Đăng xuất
          Padding(
            padding: const EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              bottom: 24.0,
              top: 8.0,
            ),
            child: InkWell(
              onTap: () {
                Navigator.pop(context); // Đóng Drawer
                context.read<AuthBloc>().add(SignOutRequested());
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.redAccent.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppPreferences.tr('ĐĂNG XUẤT', 'LOGOUT'),
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
