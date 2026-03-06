import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/task_bloc.dart';
import '../blocs/task_event.dart';
import '../blocs/task_state.dart';
import '../blocs/board_bloc.dart';
import '../blocs/board_event.dart';
import '../blocs/board_state.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/board.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  String? selectedBoardId;
  String selectedLandscapeStatus = 'todo';
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();
  final PageController _pageController = PageController(viewportFraction: 0.88);

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (selectedBoardId != null) {
      context.read<TaskBloc>().add(
            LoadTasks(boardId: selectedBoardId, query: searchController.text),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BoardBloc, BoardState>(
          listener: (context, state) {
            if (state is BoardLoaded) {
              if (state.boards.isEmpty) {
                setState(() {
                  selectedBoardId = null;
                });
              } else {
                final isBoardCurrentSelectedExists =
                    state.boards.any((b) => b.id == selectedBoardId);

                if (selectedBoardId == null || !isBoardCurrentSelectedExists) {
                  _selectBoard(state.boards.last.id);
                }
              }
            }
          },
        ),
        BlocListener<TaskBloc, TaskState>(
          listener: (context, state) {
            if (state is TaskLoaded && isSearching && state.tasks.isNotEmpty) {
              if (selectedLandscapeStatus != state.tasks.first.status) {
                setState(() {
                  selectedLandscapeStatus = state.tasks.first.status;
                });
              }
            }
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: isSearching
              ? TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm công việc...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey[400]),
                  ),
                  style: const TextStyle(color: Colors.black87, fontSize: 18),
                  autofocus: true,
                )
              : const Text(
                  'KanbanFlow',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
          centerTitle: !isSearching,
          actions: [
            IconButton(
              icon: Icon(isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  if (isSearching) {
                    isSearching = false;
                    searchController.clear();
                  } else {
                    isSearching = true;
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                if (selectedBoardId != null) {
                  context.read<TaskBloc>().add(
                        LoadTasks(
                          boardId: selectedBoardId,
                          query: searchController.text,
                        ),
                      );
                }
              },
            ),
            const SizedBox(width: 8),
          ],
          leading: selectedBoardId != null
              ? IconButton(
                  icon: const Icon(Icons.home_rounded),
                  tooltip: 'Về trang chủ',
                  onPressed: () {
                    setState(() {
                      selectedBoardId = null;
                      isSearching = false;
                      searchController.clear();
                    });
                  },
                )
              : null,
        ),
        drawer: selectedBoardId == null ? _buildDrawer(context) : null,
        body: selectedBoardId == null
            ? DashboardView(
                onBoardSelected: _selectBoard,
                onAddBoard: () => _showAddBoardDialog(context),
              )
            : _buildBoardContent(context),
        floatingActionButton: selectedBoardId == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showAddTaskDialog(context),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Thêm thẻ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: Colors.blueAccent,
                elevation: 4,
              ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(
              top: 60,
              bottom: 30,
              left: 24,
              right: 24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.lightBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.view_kanban, color: Colors.white, size: 36),
                SizedBox(width: 16),
                Text(
                  'Các Bảng',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
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
                } else if (state is BoardLoaded) {
                  final boards = state.boards;
                  if (boards.isEmpty) {
                    return const Center(
                      child: Text(
                        'Chưa có Bảng nào.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: boards.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 24, endIndent: 24),
                    itemBuilder: (context, index) {
                      final board = boards[index];
                      final isSelected = board.id == selectedBoardId;
                      return ListTile(
                        leading: Icon(
                          isSelected
                              ? Icons.dashboard
                              : Icons.dashboard_outlined,
                          color:
                              isSelected ? Colors.blueAccent : Colors.black54,
                        ),
                        title: Text(
                          board.title,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color:
                                isSelected ? Colors.blueAccent : Colors.black87,
                          ),
                        ),
                        selected: isSelected,
                        selectedTileColor: Colors.blue.withOpacity(0.05),
                        onTap: () {
                          _selectBoard(board.id);
                          Navigator.pop(context); // Close drawer
                        },
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () =>
                              _showDeleteBoardDialog(context, board),
                        ),
                      );
                    },
                  );
                } else if (state is BoardError) {
                  return Center(child: Text('Lỗi: ${state.message}'));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showAddBoardDialog(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Thêm Bảng Mới'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.blue.withOpacity(0.1),
                foregroundColor: Colors.blueAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectBoard(String id) {
    setState(() {
      selectedBoardId = id;
    });
    context.read<TaskBloc>().add(
          LoadTasks(boardId: id, query: searchController.text),
        );
  }

  Widget _buildBoardContent(BuildContext context) {
    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        if (state is TaskLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is TaskLoaded) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 600 ||
                  MediaQuery.of(context).orientation == Orientation.landscape;

              if (isWideScreen) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 250,
                      color: Colors.white,
                      child: Column(
                        children: [
                          _buildMenuItem(
                            'Cần làm',
                            'todo',
                            Colors.blueAccent,
                            state.tasks,
                          ),
                          _buildMenuItem(
                            'Đang làm',
                            'doing',
                            Colors.orangeAccent,
                            state.tasks,
                          ),
                          _buildMenuItem(
                            'Hoàn thành',
                            'done',
                            Colors.teal,
                            state.tasks,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      color: Colors.grey.withOpacity(0.2),
                    ),
                    Expanded(
                      child: Container(
                        color: Colors.grey[50],
                        child: _buildLandscapeTaskContent(
                          context,
                          state.tasks,
                          selectedLandscapeStatus,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildColumn(
                      context,
                      'Cần làm',
                      'todo',
                      state.tasks,
                      Colors.blueAccent,
                    ),
                    const SizedBox(height: 24),
                    _buildColumn(
                      context,
                      'Đang làm',
                      'doing',
                      state.tasks,
                      Colors.orangeAccent,
                    ),
                    const SizedBox(height: 24),
                    _buildColumn(
                      context,
                      'Hoàn thành',
                      'done',
                      state.tasks,
                      Colors.teal,
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              );
            },
          );
        } else if (state is TaskError) {
          return Center(child: Text('Lỗi: ${state.message}'));
        }
        return const Center(child: Text('Chưa có dữ liệu'));
      },
    );
  }

  Widget _buildMenuItem(
    String title,
    String status,
    Color accentColor,
    List<Task> allTasks,
  ) {
    final isSelected = selectedLandscapeStatus == status;
    final tasksCount = allTasks.where((t) => t.status == status).length;

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) {
        final droppedTask = details.data;
        final updatedTask = Task(
          id: droppedTask.id,
          boardId: droppedTask.boardId,
          title: droppedTask.title,
          description: droppedTask.description,
          status: status,
          createdAt: droppedTask.createdAt,
        );
        context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return InkWell(
          onTap: () {
            setState(() {
              selectedLandscapeStatus = status;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: isHovering
                  ? accentColor.withOpacity(0.2)
                  : (isSelected
                      ? accentColor.withOpacity(0.1)
                      : Colors.transparent),
              border: Border(
                left: BorderSide(
                  color: isHovering || isSelected
                      ? accentColor
                      : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isHovering || isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 16,
                      color: isHovering || isSelected
                          ? accentColor
                          : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$tasksCount',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLandscapeTaskContent(
    BuildContext context,
    List<Task> allTasks,
    String status,
  ) {
    final tasks = allTasks.where((t) => t.status == status).toList();
    Color accentColor = status == 'todo'
        ? Colors.blueAccent
        : (status == 'doing' ? Colors.orangeAccent : Colors.teal);

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) {
        final droppedTask = details.data;
        final updatedTask = Task(
          id: droppedTask.id,
          boardId: droppedTask.boardId,
          title: droppedTask.title,
          description: droppedTask.description,
          status: status,
          createdAt: droppedTask.createdAt,
        );
        context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color:
              isHovering ? accentColor.withOpacity(0.05) : Colors.transparent,
          child: tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có công việc nào',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 140,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Draggable<Task>(
                      data: task,
                      feedback: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 380,
                          child: Opacity(
                            opacity: 0.9,
                            child: _buildTaskCard(task, accentColor, context),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _buildTaskCard(task, accentColor, context),
                      ),
                      child: _buildTaskCard(task, accentColor, context),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildColumn(
    BuildContext context,
    String title,
    String status,
    List<Task> allTasks,
    Color accentColor,
  ) {
    final tasks = allTasks.where((t) => t.status == status).toList();

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) {
        final droppedTask = details.data;
        final updatedTask = Task(
          id: droppedTask.id,
          boardId: droppedTask.boardId,
          title: droppedTask.title,
          description: droppedTask.description,
          status: status,
          createdAt: droppedTask.createdAt,
        );
        context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHovering
                  ? accentColor.withOpacity(0.8)
                  : Colors.grey.withOpacity(0.1),
              width: isHovering ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovering
                    ? accentColor.withOpacity(0.2)
                    : Colors.black.withOpacity(0.03),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              colorScheme: ColorScheme.light(primary: accentColor),
            ),
            child: ExpansionTile(
              initiallyExpanded: true,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              title: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (tasks.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Danh sách trống',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                else
                  ...tasks.map((task) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Draggable<Task>(
                        data: task,
                        feedback: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.transparent,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width - 64,
                            child: Opacity(
                              opacity: 0.9,
                              child: _buildTaskCard(task, accentColor, context),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _buildTaskCard(task, accentColor, context),
                        ),
                        child: _buildTaskCard(task, accentColor, context),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskCard(Task task, Color accentColor, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showTaskDetail(context, task, accentColor),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: accentColor, width: 4)),
                gradient: LinearGradient(
                  colors: [Colors.white, accentColor.withOpacity(0.02)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => context.read<TaskBloc>().add(
                              DeleteTaskEvent(task.id),
                            ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.redAccent,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      task.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatDate(task.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  void _showTaskDetail(BuildContext context, Task task, Color accentColor) {
    showDialog(
      context: context,
      builder: (context) =>
          TaskDetailDialog(task: task, accentColor: accentColor),
    );
  }

  void _showAddBoardDialog(BuildContext context) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Center(
        child: SingleChildScrollView(
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Thêm Bảng mới',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 400,
              child: TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Tên Bảng',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                autofocus: true,
              ),
            ),
            actionsPadding: const EdgeInsets.all(16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) return;
                  final board = Board(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text.trim(),
                    createdAt: DateTime.now().toIso8601String(),
                  );
                  context.read<BoardBloc>().add(AddBoardEvent(board));
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Thêm'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteBoardDialog(BuildContext context, Board board) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xác nhận xóa',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.redAccent,
          ),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa bảng "${board.title}"?\nTất cả công việc trong bảng sẽ bị xóa vĩnh viễn.',
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              context.read<BoardBloc>().add(DeleteBoardEvent(board.id));
              if (selectedBoardId == board.id) {
                setState(() {
                  selectedBoardId = null;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Xóa Bảng'),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Center(
        child: SingleChildScrollView(
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Thêm công việc mới',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Tiêu đề',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(
                      labelText: 'Mô tả (không bắt buộc)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.all(16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty ||
                      selectedBoardId == null) {
                    return;
                  }
                  final task = Task(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    boardId: selectedBoardId!,
                    title: titleController.text.trim(),
                    description: descController.text.trim(),
                    status: 'todo',
                    createdAt: DateTime.now().toIso8601String(),
                  );
                  context.read<TaskBloc>().add(AddTaskEvent(task));
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.blueAccent.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Thêm công việc'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  final Function(String) onBoardSelected;
  final VoidCallback onAddBoard;

  const DashboardView({
    super.key,
    required this.onBoardSelected,
    required this.onAddBoard,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BoardBloc, BoardState>(
      builder: (context, state) {
        List<Board> boards = [];
        if (state is BoardLoaded) {
          boards = state.boards;
        }

        return Container(
          color: const Color(0xFFF8FAFC),
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        SizedBox(
                          height: 250,
                          width: double.infinity,
                          child: ClipRRect(
                            child: Image.network(
                              'https://images.unsplash.com/photo-1497366216548-37526070297c?q=80&w=1200&auto=format&fit=crop',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Container(
                          height: 250,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.1),
                                Colors.white.withOpacity(0.95),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 30,
                          left: 24,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Không Gian Làm Việc',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E3A8A),
                                  letterSpacing: -1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 60,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 48,
                          right: 24,
                          child: Row(
                            children: [
                              _buildHeaderIconButton(
                                Icons.notifications_outlined,
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E3A8A),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'HA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'DỰ ÁN CỦA BẠN',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF64748B),
                              letterSpacing: 2,
                            ),
                          ),
                          _buildSortBadge(),
                        ],
                      ),
                    ),
                  ),
                  if (boards.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome_motion_rounded,
                              size: 80,
                              color: Colors.grey[200],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Chưa có dự án nào khả dụng',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 24,
                          mainAxisExtent: 240,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildProjectCard(context, boards[index]),
                          childCount: boards.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
              Positioned(bottom: 32, right: 32, child: _buildFAB()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectCard(BuildContext context, Board board) {
    final List<Color> cardColors = [
      Colors.indigo,
      Colors.teal,
      Colors.deepOrange,
      Colors.purple,
      Colors.blue,
    ];
    final color = cardColors[board.id.hashCode % cardColors.length];

    return GestureDetector(
      onTap: () => onBoardSelected(board.id),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: -20,
              right: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.grid_view_rounded,
                          color: color,
                          size: 26,
                        ),
                      ),
                      Icon(
                        Icons.more_vert_rounded,
                        color: Colors.grey[300],
                        size: 24,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    board.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_filled_rounded,
                        size: 14,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Cập nhật: ${_timeAgo(board.createdAt)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onAddBoard,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_box_rounded,
                  color: Color(0xFF1E3A8A),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Thêm Dự Án',
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: const Color(0xFF1E3A8A), size: 24),
    );
  }

  Widget _buildSortBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: const Row(
        children: [
          Text(
            'Mới nhất',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  String _timeAgo(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'vừa xong';
      if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
      if (diff.inHours < 24) return '${diff.inHours} giờ trước';
      return '${diff.inDays} ngày trước';
    } catch (e) {
      return 'mới đây';
    }
  }
}

class TaskDetailDialog extends StatelessWidget {
  final Task task;
  final Color accentColor;

  const TaskDetailDialog({
    super.key,
    required this.task,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    String statusText = '';
    switch (task.status) {
      case 'todo':
        statusText = 'Cần làm';
        break;
      case 'doing':
        statusText = 'Đang làm';
        break;
      case 'done':
        statusText = 'Hoàn thành';
        break;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.15),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor,
                          accentColor.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Opacity(
                      opacity: 0.6,
                      child: Image.network(
                        'https://images.unsplash.com/photo-1484480974693-6ca0a78fb36b?q=80&w=1000&auto=format&fit=crop',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: accentColor.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tạo lúc: ${_formatFullDate(task.createdAt)}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'CHI TIẾT CÔNG VIỆC',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.blueAccent,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        task.description.isNotEmpty
                            ? task.description
                            : 'Chưa có mô tả chi tiết cho nhiệm vụ này.',
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFF334155),
                          height: 1.7,
                          fontStyle: task.description.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey[200]!),
                              ),
                            ),
                            child: const Text(
                              'Đóng cửa sổ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('Chỉnh sửa'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: accentColor.withOpacity(0.4),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
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
    );
  }

  String _formatFullDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return '${date.day} Tháng ${date.month}, ${date.year} lúc ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }
}
