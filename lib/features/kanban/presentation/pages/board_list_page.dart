import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../blocs/board/board_bloc.dart';
import '../blocs/board/board_event.dart';
import '../blocs/board/board_state.dart';
import 'kanban_board_page.dart';

class BoardListPage extends StatelessWidget {
  const BoardListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Không Gian Làm Việc',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.indigo.shade900,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1497215728101-856f4ea42174?q=80&w=2070&auto=format&fit=crop',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          isDark
                              ? Colors.black
                              : Colors.white.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {},
              ),
              const CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(
                  'https://ui-avatars.com/api/?name=Hau&background=0D47A1&color=fff',
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DỰ ÁN CỦA BẠN',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Mới nhất',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          BlocBuilder<BoardBloc, BoardState>(
            builder: (context, state) {
              if (state is BoardLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              } else if (state is BoardLoaded) {
                if (state.boards.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            size: 100,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có dự án nào.\nHãy tạo bảng mới để bắt đầu!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: () => _showAddBoardDialog(context),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Tạo Dự Án Mới'),
                          ),
                        ],
                      ).animate().fadeIn(duration: 600.ms).moveY(begin: 30, end: 0),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.5,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final board = state.boards[index];
                      return _BoardCard(board: board, index: index);
                    }, childCount: state.boards.length),
                  ),
                );
              } else if (state is BoardError) {
                return SliverFillRemaining(
                  child: Center(child: Text('Lỗi: ${state.message}')),
                );
              }
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
            onPressed: () => _showAddBoardDialog(context),
            label: const Text('Thêm Dự Án'),
            icon: const Icon(Icons.add_to_photos),
            elevation: 4,
          ).animate().scale(
            delay: 500.ms,
            begin: const Offset(0, 0),
            end: const Offset(1, 1),
            curve: Curves.elasticOut,
          ),
    );
  }

  void _showAddBoardDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Dự Án Mới',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Nhập tên bảng (VD: Mobile App UI)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<BoardBloc>().add(AddBoardEvent(controller.text));
                Navigator.pop(context);
              }
            },
            child: const Text('Tạo Ngay'),
          ),
        ],
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final dynamic board;
  final int index;
  const _BoardCard({required this.board, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<Color> cardColors = [
      Colors.indigo,
      Colors.deepOrange,
      Colors.teal,
      Colors.purple,
      Colors.pink,
    ];
    final Color accentColor = cardColors[index % cardColors.length];

    return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => KanbanBoardPage(board: board),
              ),
            );
          },
          borderRadius: BorderRadius.circular(28),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: accentColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  Positioned(
                    bottom: -20,
                    right: -20,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                Icons.dashboard_customize_rounded,
                                color: accentColor,
                                size: 24,
                              ),
                            ),
                            PopupMenuButton(
                              icon: const Icon(Icons.more_vert_rounded),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Xóa dự án'),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (val) {
                                if (val == 'delete') {
                                  _confirmDelete(context, board.id);
                                }
                              },
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          board.title,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Cập nhật: 1 phút trước',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (index * 100).ms, duration: 500.ms)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic);
  }

  void _confirmDelete(BuildContext context, String boardId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa dự án?'),
        content: const Text(
          'Thao tác này sẽ xóa vĩnh viễn bảng và tất cả công việc bên trong.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Quay lại'),
          ),
          TextButton(
            onPressed: () {
              context.read<BoardBloc>().add(DeleteBoardEvent(boardId));
              Navigator.pop(context);
            },
            child: const Text(
              'Đồng ý xóa',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
