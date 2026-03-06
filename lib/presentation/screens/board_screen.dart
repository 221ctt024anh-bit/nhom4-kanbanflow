import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widget_previews.dart';
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
                // Tự động chọn Bảng nếu chưa chọn, hoặc nếu Bảng đang chọn đã bị xóa
                final isBoardCurrentSelectedExists = state.boards.any(
                  (b) => b.id == selectedBoardId,
                );

                if (selectedBoardId == null || !isBoardCurrentSelectedExists) {
                  // Mặc định chọn Bảng mới nhất (nằm ở cuối list)
                  _selectBoard(state.boards.last.id);
                }
              }
            }
          },
        ),
        BlocListener<TaskBloc, TaskState>(
          listener: (context, state) {
            if (state is TaskLoaded && isSearching && state.tasks.isNotEmpty) {
              // Khi đang tìm kiếm, tự động Focus vào Tab chứa kết quả đầu tiên ở màn hình ngang
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
        ),
        drawer: _buildDrawer(context),
        body: selectedBoardId == null
            ? EmptyDashboardView(
                onAddBoard: () => _showAddBoardDialog(context),
                onOpenMenu: () => Scaffold.of(context).openDrawer(),
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
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 24, endIndent: 24),
                    itemBuilder: (context, index) {
                      final board = boards[index];
                      final isSelected = board.id == selectedBoardId;
                      return ListTile(
                        leading: Icon(
                          isSelected
                              ? Icons.dashboard
                              : Icons.dashboard_outlined,
                          color: isSelected
                              ? Colors.blueAccent
                              : Colors.black54,
                        ),
                        title: Text(
                          board.title,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.blueAccent
                                : Colors.black87,
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
              final isWideScreen =
                  constraints.maxWidth > 600 ||
                  MediaQuery.of(context).orientation == Orientation.landscape;

              if (isWideScreen) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cột Menu bên trái
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
                    // Kẻ dọc phân cách
                    Container(width: 1, color: Colors.grey.withOpacity(0.2)),
                    // Khu vực chứa thẻ bên phải
                    Expanded(
                      child: Container(
                        color: Colors.grey[50], // Nền nhạt cho khu vực thẻ
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

              // Mặc định: Giao diện dọc (Portrait) - Menu sổ xuống
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: double.infinity),
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
                        const SizedBox(height: 60), // Space for FAB
                      ],
                    ),
                  ),
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
        );
        context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: isHovering
              ? accentColor.withOpacity(0.05)
              : Colors.transparent,
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
                    mainAxisExtent: 140, // Fixed height for task cards
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
        );
        context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovering
                  ? accentColor.withOpacity(0.8)
                  : Colors.grey.withOpacity(0.2),
              width: isHovering ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovering
                    ? accentColor.withOpacity(0.15)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
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
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: accentColor, width: 3)),
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
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => context.read<TaskBloc>().add(
                          DeleteTaskEvent(task.id),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.close,
                            color: Colors.black26,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      task.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
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
              width: 400, // Định hình chiều rộng tối đa
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
              width: 400, // Cố định chiều rộng để form không bị bóp méo
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
                  );
                  context.read<TaskBloc>().add(AddTaskEvent(task));
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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

@Preview(name: 'Full Dashboard')
Widget previewEmptyDashboardView() {
  return Scaffold(
    body: EmptyDashboardView(onAddBoard: () {}, onOpenMenu: () {}),
  );
}

class EmptyDashboardView extends StatelessWidget {
  final VoidCallback onAddBoard;
  final VoidCallback onOpenMenu;

  const EmptyDashboardView({
    super.key,
    required this.onAddBoard,
    required this.onOpenMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Biểu tượng tổng quan
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.dashboard_customize_rounded,
                  size: 70,
                  color: Colors.blueAccent.shade400,
                ),
              ),
              const SizedBox(height: 32),
              // Tiêu đề
              const Text(
                'Tổng Quan KanbanFlow',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              // Mô tả
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Không gian làm việc của bạn đang trống. Hãy bắt đầu kiến tạo quy trình làm việc thông minh ngay bây giờ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // Mạng lưới các nút tương tác (Action Cards)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    // Nút: Tạo Bảng Mới
                    DashboardActionCard(
                      title: 'Tạo Bảng Mới',
                      subtitle: 'Bắt đầu dự án mới ngay',
                      icon: Icons.add_chart_rounded,
                      gradientColors: const [
                        Colors.blueAccent,
                        Colors.lightBlue,
                      ],
                      onTap: onAddBoard,
                    ),
                    // Nút: Mở Menu Bảng
                    DashboardActionCard(
                      title: 'Quản Lý Bảng',
                      subtitle: 'Xem các bảng hiện tại',
                      icon: Icons.menu_open_rounded,
                      gradientColors: const [
                        Colors.indigo,
                        Colors.indigoAccent,
                      ],
                      onTap: onOpenMenu,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60), // Khoảng trống dưới cùng
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const DashboardActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          splashColor: gradientColors.first.withOpacity(0.1),
          highlightColor: gradientColors.first.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
