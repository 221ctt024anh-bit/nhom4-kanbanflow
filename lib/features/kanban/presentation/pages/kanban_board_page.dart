import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../domain/entities/board_entity.dart';
import '../../domain/entities/column_entity.dart';
import '../../domain/entities/task_entity.dart';
import '../blocs/task/task_bloc.dart';
import '../blocs/task/task_event.dart';
import '../blocs/task/task_state.dart';

class KanbanBoardPage extends StatefulWidget {
  final BoardEntity board;
  const KanbanBoardPage({super.key, required this.board});

  @override
  State<KanbanBoardPage> createState() => _KanbanBoardPageState();
}

class _KanbanBoardPageState extends State<KanbanBoardPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<TaskBloc>().add(LoadTasksEvent(widget.board.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: 80,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.board.title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'ĐANG HOẠT ĐỘNG',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: SizedBox(
              width: 180,
              child: SearchBar(
                controller: _searchController,
                elevation: const WidgetStatePropertyAll(0),
                backgroundColor: WidgetStatePropertyAll(
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                ),
                hintText: 'Tìm công việc...',
                hintStyle: WidgetStatePropertyAll(
                  GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
                ),
                leading: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Colors.grey,
                ),
                onChanged: (value) {
                  context.read<TaskBloc>().add(SearchTasksEvent(value));
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.add_box_rounded,
              size: 32,
              color: theme.colorScheme.primary,
            ),
            onPressed: () => _showAddColumnDialog(context),
            tooltip: 'Thêm cột',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: BlocBuilder<TaskBloc, TaskState>(
        builder: (context, state) {
          if (state is TaskLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is TaskLoaded) {
            if (state.columns.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.view_column_rounded,
                      size: 120,
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Bảng này chưa có cột nào.',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hãy bắt đầu bằng cách thêm một cột mới (VD: Việc cần làm)',
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAddColumnDialog(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Thêm Cột Đầu Tiền'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn().scale(duration: 500.ms),
              );
            }

            if (_searchController.text.isNotEmpty) {
              return _buildSearchList(state.searchResults);
            }

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.surface,
                    theme.colorScheme.primary.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: state.columns.length,
                itemBuilder: (context, index) {
                  final column = state.columns[index];
                  final tasks = state.tasks[column.id] ?? [];
                  return _KanbanColumn(
                    column: column,
                    tasks: tasks,
                    index: index,
                  );
                },
              ).animate().fadeIn(duration: 800.ms),
            );
          } else if (state is TaskError) {
            return Center(child: Text('Lỗi: ${state.message}'));
          }
          return Container();
        },
      ),
    );
  }

  Widget _buildSearchList(List<TaskEntity> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy kết quả phù hợp',
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: results.length,
      itemBuilder: (context, index) => _TaskCard(
        task: results[index],
        accentColor: Colors.indigo,
      ).animate().fadeIn(delay: (index * 50).ms).slideX(),
    );
  }

  void _showAddColumnDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Thêm Cột Mới',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Tên cột (VD: Đang làm, Hoàn thành)',
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
                context.read<TaskBloc>().add(
                  AddColumnEvent(widget.board.id, controller.text),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Thêm Cột'),
          ),
        ],
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final ColumnEntity column;
  final List<TaskEntity> tasks;
  final int index;

  const _KanbanColumn({
    required this.column,
    required this.tasks,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = _getColumnColor(column.title);

    return Container(
          width: 320,
          margin: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              column.title.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                fontSize: 16,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tasks.length.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton(
                      icon: const Icon(Icons.more_horiz_rounded, size: 24),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'add',
                          child: Row(
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 20,
                                color: accentColor,
                              ),
                              const SizedBox(width: 8),
                              const Text('Thêm việc'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: Colors.red,
                              ),
                              SizedBox(width: 8),
                              Text('Xóa cột'),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (val) {
                        if (val == 'add') {
                          _showAddTaskDialog(context, column.id);
                        }
                        if (val == 'delete') {
                          _confirmDeleteColumn(context, column.id);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: InkWell(
                  onTap: () => _showAddTaskDialog(context, column.id),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.2),
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, size: 18, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            'THÊM VIỆC',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: DragTarget<String>(
                  onWillAcceptWithDetails: (details) => true,
                  onAcceptWithDetails: (details) {
                    final taskId = details.data;
                    context.read<TaskBloc>().add(
                      MoveTaskEvent(
                        taskId: taskId,
                        newColumnId: column.id,
                        newOrder: tasks.length,
                      ),
                    );
                  },
                  builder: (context, candidateData, rejectedData) {
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return Draggable<String>(
                          data: task.id,
                          feedback: SizedBox(
                            width: 290,
                            child: _TaskCard(
                              task: task,
                              accentColor: accentColor,
                              isDragging: true,
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: _TaskCard(
                              task: task,
                              accentColor: accentColor,
                            ),
                          ),
                          child: _TaskCard(
                            task: task,
                            accentColor: accentColor,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (index * 150).ms, duration: 600.ms)
        .slideX(begin: 0.2, end: 0);
  }

  Color _getColumnColor(String title) {
    final t = title.toLowerCase();
    if (t.contains('todo') || t.contains('việc') || t.contains('đầu')) {
      return Colors.indigo;
    }
    if (t.contains('doing') || t.contains('đang')) {
      return Colors.orange.shade700;
    }
    if (t.contains('done') || t.contains('hoàn') || t.contains('xong')) {
      return const Color(0xFF10B981); // Emerald
    }
    if (t.contains('test') || t.contains('thử')) {
      return Colors.purple;
    }
    return Colors.blueGrey;
  }

  void _showAddTaskDialog(BuildContext context, String columnId) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Thêm Công Việc',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(hintText: 'Tên công việc'),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                hintText: 'Mô tả chi tiết (không bắt buộc)',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                context.read<TaskBloc>().add(
                  AddTaskEvent(
                    columnId: columnId,
                    title: titleController.text,
                    description: descController.text,
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Lưu Công Việc'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteColumn(BuildContext context, String columnId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa cột này?'),
        content: const Text(
          'Tất cả công việc trong cột cũng sẽ bị xóa vĩnh viễn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              context.read<TaskBloc>().add(DeleteColumnEvent(columnId));
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

class _TaskCard extends StatelessWidget {
  final TaskEntity task;
  final Color accentColor;
  final bool isDragging;

  const _TaskCard({
    required this.task,
    required this.accentColor,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDragging ? 0.3 : 0.06),
            blurRadius: isDragging ? 25 : 8,
            offset: Offset(0, isDragging ? 12 : 4),
          ),
        ],
        border: Border.all(color: accentColor.withValues(alpha: 0.1), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'TASK',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.short_text_rounded,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  task.title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.description,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: accentColor.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.person,
                            size: 12,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Anh Hau',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.attachment_rounded,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9));
  }
}
