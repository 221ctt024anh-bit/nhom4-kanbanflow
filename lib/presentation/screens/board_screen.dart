import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/entities/app_notification.dart';
import '../blocs/task_bloc.dart';
import '../blocs/task_event.dart';
import '../blocs/task_state.dart';
import '../blocs/board_bloc.dart';
import '../blocs/board_event.dart';
import '../blocs/board_state.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/board.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../widgets/empty_dashboard_view.dart';
import '../widgets/task_card.dart';
import '../widgets/board_member_dialog.dart';
import 'workspace_menu_screen.dart';
import '../../app_preferences.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final NotificationRepository _notificationRepository =
      NotificationRepository();
  String? selectedBoardId;
  String selectedLandscapeStatus = 'todo';
  String _quickFilter = 'all';
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();
  final PageController _pageController = PageController(viewportFraction: 0.88);
  Timer? _notificationTimer;
  int _unreadNotificationCount = 0;
  bool _loadingNotifications = false;
  List<AppNotification> _notifications = [];
  bool _inAppNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
    _initNotificationFlow();
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _pageController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshNotifications() async {
    if (!_inAppNotificationsEnabled) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = 0;
          _notifications = [];
        });
      }
      return;
    }
    if (_loadingNotifications) return;
    setState(() {
      _loadingNotifications = true;
    });
    try {
      final unread = await _notificationRepository.getUnreadCount();
      final notifications = await _notificationRepository.getNotifications();
      if (!mounted) return;
      setState(() {
        _unreadNotificationCount = unread;
        _notifications = notifications;
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) {
        setState(() {
          _loadingNotifications = false;
        });
      }
    }
  }

  Future<void> _initNotificationFlow() async {
    await _loadNotificationSetting();
    if (!_inAppNotificationsEnabled) return;
    await _refreshNotifications();
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshNotifications(),
    );
  }

  Future<void> _loadNotificationSetting() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _inAppNotificationsEnabled = true;
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('user_settings')
          .select('in_app_notifications')
          .eq('user_id', userId)
          .maybeSingle();
      final enabled = (response?['in_app_notifications'] as bool?) ?? true;
      if (!mounted) return;
      setState(() {
        _inAppNotificationsEnabled = enabled;
      });
    } catch (_) {
      _inAppNotificationsEnabled = true;
    }
  }

  Future<void> _markAllNotificationsRead() async {
    await _notificationRepository.markAllAsRead();
    await _refreshNotifications();
  }

  Future<void> _markNotificationRead(String id) async {
    await _notificationRepository.markAsRead(id);
    await _refreshNotifications();
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(AppPreferences.tr('Thông báo', 'Notifications')),
              ),
              TextButton(
                onPressed: _notifications.isEmpty
                    ? null
                    : _markAllNotificationsRead,
                child: Text(
                  AppPreferences.tr('Đánh dấu đã đọc', 'Mark all as read'),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: _loadingNotifications
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                ? Text(
                    AppPreferences.tr(
                      'Chưa có thông báo nào',
                      'No notifications yet',
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(item.message),
                        trailing: item.isRead
                            ? const Icon(
                                Icons.done_all,
                                size: 18,
                                color: Colors.green,
                              )
                            : TextButton(
                                onPressed: () => _markNotificationRead(item.id),
                                child: Text(
                                  AppPreferences.tr('Đã đọc', 'Read'),
                                ),
                              ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppPreferences.tr('Đóng', 'Close')),
            ),
          ],
        );
      },
    );
  }

  void _onSearchChanged() {
    if (selectedBoardId != null) {
      context.read<TaskBloc>().add(
        LoadTasks(boardId: selectedBoardId, query: searchController.text),
      );
    }
  }

  List<Task> _applyQuickFilter(List<Task> tasks) {
    if (_quickFilter == 'all') return tasks;
    if (_quickFilter == 'mine') {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return [];
      return tasks.where((t) => t.assigneeId == userId).toList();
    }
    if (_quickFilter == 'overdue') {
      final now = DateTime.now();
      return tasks
          .where(
            (t) =>
                t.dueAt != null && t.status != 'done' && t.dueAt!.isBefore(now),
          )
          .toList();
    }
    return tasks.where((t) => t.status == _quickFilter).toList();
  }

  bool _isOverdueTask(Task task) {
    return task.dueAt != null &&
        task.status != 'done' &&
        task.dueAt!.isBefore(DateTime.now());
  }

  List<Task> _tasksByStatus(List<Task> allTasks, String status) {
    if (status == 'overdue') {
      return allTasks.where(_isOverdueTask).toList();
    }
    return allTasks.where((t) => t.status == status).toList();
  }

  Color _statusColor(String status) {
    if (status == 'todo') return Colors.blueAccent;
    if (status == 'doing') return Colors.orangeAccent;
    if (status == 'done') return Colors.teal;
    if (status == 'overdue') return Colors.redAccent;
    return Colors.blueGrey;
  }

  bool _isSingleStatusFilter(String value) {
    return value == 'todo' ||
        value == 'doing' ||
        value == 'done' ||
        value == 'overdue';
  }

  String _statusTitle(String status) {
    if (status == 'todo') return AppPreferences.tr('Cần làm', 'To Do');
    if (status == 'doing') return AppPreferences.tr('Đang làm', 'Doing');
    if (status == 'done') return AppPreferences.tr('Hoàn thành', 'Completed');
    if (status == 'overdue') return AppPreferences.tr('Quá hạn', 'Overdue');
    return status;
  }

  List<String> _defaultStatuses() => <String>['todo', 'doing', 'done'];

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

                if (selectedBoardId != null && !isBoardCurrentSelectedExists) {
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
          leading: IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: AppPreferences.tr('Trang cá nhân', 'My profile'),
            onPressed: () {
              setState(() {
                selectedBoardId = null;
                isSearching = false;
                searchController.clear();
              });
            },
          ),
          title: isSearching
              ? TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: AppPreferences.tr(
                      'Tìm kiếm công việc...',
                      'Search tasks...',
                    ),
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey[400]),
                  ),
                  style: const TextStyle(color: Colors.black87, fontSize: 18),
                  autofocus: true,
                )
              : const Text(
                  'TaskMate',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
          centerTitle: !isSearching,
          actions: [
            IconButton(
              tooltip: AppPreferences.tr('Thông báo', 'Notifications'),
              onPressed: () async {
                await _loadNotificationSetting();
                if (!_inAppNotificationsEnabled) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppPreferences.tr(
                          'Thông báo trong ứng dụng đang tắt trong Cài đặt',
                          'In-app notifications are disabled in Settings',
                        ),
                      ),
                    ),
                  );
                  return;
                }
                await _refreshNotifications();
                if (!mounted) return;
                _showNotificationsDialog();
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none),
                  if (_unreadNotificationCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 14,
                        ),
                        child: Text(
                          _unreadNotificationCount > 99
                              ? '99+'
                              : _unreadNotificationCount.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (selectedBoardId != null)
              BlocBuilder<BoardBloc, BoardState>(
                builder: (context, state) {
                  if (state is BoardLoaded) {
                    if (state.boards.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    Board currentBoard = state.boards.first;
                    for (final board in state.boards) {
                      if (board.id == selectedBoardId) {
                        currentBoard = board;
                        break;
                      }
                    }
                    return IconButton(
                      icon: const Icon(Icons.group_add_outlined),
                      tooltip: AppPreferences.tr('Thành viên', 'Members'),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => BoardMemberDialog(
                            boardId: currentBoard.id,
                            ownerId: currentBoard.ownerId,
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
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
            PopupMenuButton<String>(
              tooltip: AppPreferences.tr('Bộ lọc nhanh', 'Quick filter'),
              icon: const Icon(Icons.tune_rounded),
              initialValue: _quickFilter,
              onSelected: (value) {
                setState(() {
                  _quickFilter = value;
                  if (_isSingleStatusFilter(value)) {
                    selectedLandscapeStatus = value;
                  }
                });
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'all',
                  child: Text(AppPreferences.tr('Tất cả', 'All')),
                ),
                PopupMenuItem(
                  value: 'mine',
                  child: Text(AppPreferences.tr('Việc của tôi', 'My tasks')),
                ),
                PopupMenuItem(
                  value: 'overdue',
                  child: Text(AppPreferences.tr('Quá hạn', 'Overdue')),
                ),
                PopupMenuItem(
                  value: 'doing',
                  child: Text(AppPreferences.tr('Đang làm', 'Doing')),
                ),
                PopupMenuItem(
                  value: 'done',
                  child: Text(AppPreferences.tr('Hoàn thành', 'Completed')),
                ),
              ],
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
        body: selectedBoardId == null
            ? EmptyDashboardView(
                onAddBoard: () => _showAddBoardDialog(context),
                onOpenMenu: _openWorkspaceMenu,
              )
            : _buildBoardContent(context),
        floatingActionButton: selectedBoardId == null
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _showAddTaskDialog(context),
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text(
                  AppPreferences.tr('Thêm thẻ', 'Add card'),
                  style: const TextStyle(
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

  void _selectBoard(String id) {
    setState(() {
      selectedBoardId = id;
    });
    context.read<TaskBloc>().add(
      LoadTasks(boardId: id, query: searchController.text),
    );
  }

  Future<void> _openWorkspaceMenu() async {
    final selected = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkspaceMenuScreen(selectedBoardId: selectedBoardId),
      ),
    );
    if (!mounted) return;
    if (selected != null && selected.isNotEmpty) {
      _selectBoard(selected);
    }
  }

  Widget _buildBoardContent(BuildContext context) {
    return BlocBuilder<TaskBloc, TaskState>(
      builder: (context, state) {
        if (state is TaskLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is TaskLoaded) {
          final visibleTasks = _applyQuickFilter(state.tasks);
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen =
                  constraints.maxWidth > 600 ||
                  MediaQuery.of(context).orientation == Orientation.landscape;
              final visibleStatuses = _quickFilter == 'mine'
                  ? <String>['todo']
                  : (_isSingleStatusFilter(_quickFilter)
                        ? <String>[_quickFilter]
                        : _defaultStatuses());

              if (isWideScreen) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cột Menu bên trái
                    Container(
                      width: 250,
                      color: Colors.white,
                      child: Column(
                        children: visibleStatuses
                            .map(
                              (status) => _buildMenuItem(
                                _statusTitle(status),
                                status,
                                _statusColor(status),
                                visibleTasks,
                              ),
                            )
                            .toList(),
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
                          visibleTasks,
                          selectedLandscapeStatus,
                        ),
                      ),
                    ),
                  ],
                );
              }

              // Mặc định: Giao diện dọc (Portrait) - Menu sổ xuống
              final portraitStatuses = visibleStatuses;

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
                        _buildBoardOverview(visibleTasks),
                        const SizedBox(height: 12),
                        _buildQuickFilterChips(),
                        const SizedBox(height: 18),
                        for (var i = 0; i < portraitStatuses.length; i++) ...[
                          _buildColumn(
                            context,
                            _statusTitle(portraitStatuses[i]),
                            portraitStatuses[i],
                            visibleTasks,
                            _statusColor(portraitStatuses[i]),
                          ),
                          if (i != portraitStatuses.length - 1)
                            const SizedBox(height: 24),
                        ],
                        const SizedBox(height: 60), // Space for FAB
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        } else if (state is TaskError) {
          return Center(
            child: Text(
              '${AppPreferences.tr('Lỗi', 'Error')}: ${state.message}',
            ),
          );
        }
        return Center(
          child: Text(
            AppPreferences.tr('Chưa có dữ liệu', 'No data available'),
          ),
        );
      },
    );
  }

  Widget _buildQuickFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('all', AppPreferences.tr('Tất cả', 'All')),
          const SizedBox(width: 8),
          _filterChip('mine', AppPreferences.tr('Việc của tôi', 'My tasks')),
          const SizedBox(width: 8),
          _filterChip('overdue', AppPreferences.tr('Quá hạn', 'Overdue')),
          const SizedBox(width: 8),
          _filterChip('doing', AppPreferences.tr('Đang làm', 'Doing')),
          const SizedBox(width: 8),
          _filterChip('done', AppPreferences.tr('Hoàn thành', 'Completed')),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _quickFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _quickFilter = value;
        if (_isSingleStatusFilter(value)) {
          selectedLandscapeStatus = value;
        }
      }),
      selectedColor: Colors.blueAccent.withOpacity(0.16),
      labelStyle: TextStyle(
        color: selected ? Colors.blueAccent : Colors.black87,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Widget _buildBoardOverview(List<Task> tasks) {
    final total = tasks.length;
    final done = tasks.where((t) => t.status == 'done').length;
    final doing = tasks.where((t) => t.status == 'doing').length;
    final todo = tasks.where((t) => t.status == 'todo').length;
    final overdue = tasks.where(_isOverdueTask).length;
    final progress = total == 0 ? 0.0 : done / total;
    final percentText = '${(progress * 100).round()}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 9,
                  strokeCap: StrokeCap.round,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF2563EB),
                  ),
                ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      percentText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      AppPreferences.tr('Xong', 'Done'),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _miniStat(
                  AppPreferences.tr('Tổng', 'Total'),
                  total,
                  const Color(0xFF334155),
                ),
                _miniStat(
                  _quickFilter == 'mine'
                      ? AppPreferences.tr('Việc của tôi', 'My tasks')
                      : AppPreferences.tr('Cần làm', 'To Do'),
                  _quickFilter == 'mine' ? total : todo,
                  Colors.blueAccent,
                ),
                _miniStat(
                  AppPreferences.tr('Đang làm', 'Doing'),
                  doing,
                  Colors.orangeAccent,
                ),
                _miniStat(
                  AppPreferences.tr('Hoàn thành', 'Completed'),
                  done,
                  Colors.teal,
                ),
                _miniStat(
                  AppPreferences.tr('Quá hạn', 'Overdue'),
                  overdue,
                  Colors.redAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    String title,
    String status,
    Color accentColor,
    List<Task> allTasks,
  ) {
    final isSelected = selectedLandscapeStatus == status;
    final tasksCount = _tasksByStatus(allTasks, status).length;

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) =>
          status != 'overdue' && details.data.status != status,
      onAcceptWithDetails: (details) {
        if (status == 'overdue') return;
        final droppedTask = details.data;
        final updatedTask = Task(
          id: droppedTask.id,
          boardId: droppedTask.boardId,
          title: droppedTask.title,
          description: droppedTask.description,
          status: status == 'overdue' ? droppedTask.status : status,
          assigneeId: droppedTask.assigneeId,
          creatorId: droppedTask.creatorId,
          dueAt: droppedTask.dueAt,
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
    final tasks = _tasksByStatus(allTasks, status);
    final accentColor = _statusColor(status);

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) =>
          status != 'overdue' && details.data.status != status,
      onAcceptWithDetails: (details) {
        if (status == 'overdue') return;
        final droppedTask = details.data;
        final updatedTask = Task(
          id: droppedTask.id,
          boardId: droppedTask.boardId,
          title: droppedTask.title,
          description: droppedTask.description,
          status: status == 'overdue' ? droppedTask.status : status,
          assigneeId: droppedTask.assigneeId,
          creatorId: droppedTask.creatorId,
          dueAt: droppedTask.dueAt,
          createdAt: droppedTask.createdAt,
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
                            child: TaskCard(
                              task: task,
                              accentColor: accentColor,
                            ),
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: TaskCard(task: task, accentColor: accentColor),
                      ),
                      child: TaskCard(task: task, accentColor: accentColor),
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
    final tasks = _tasksByStatus(allTasks, status);

    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) =>
          status != 'overdue' && details.data.status != status,
      onAcceptWithDetails: (details) {
        if (status == 'overdue') return;
        final droppedTask = details.data;
        final updatedTask = Task(
          id: droppedTask.id,
          boardId: droppedTask.boardId,
          title: droppedTask.title,
          description: droppedTask.description,
          status: status == 'overdue' ? droppedTask.status : status,
          assigneeId: droppedTask.assigneeId,
          creatorId: droppedTask.creatorId,
          dueAt: droppedTask.dueAt,
          createdAt: droppedTask.createdAt,
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
                              child: TaskCard(
                                task: task,
                                accentColor: accentColor,
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: TaskCard(task: task, accentColor: accentColor),
                        ),
                        child: TaskCard(task: task, accentColor: accentColor),
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

  void _showAddBoardDialog(BuildContext context) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Center(
        child: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
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
                    final authState = context.read<AuthBloc>().state;
                    final userId = authState is Authenticated
                        ? authState.user.id
                        : '';
                    final board = Board(
                      id: const Uuid().v4(),
                      title: titleController.text.trim(),
                      ownerId: userId,
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
    DateTime? selectedDueAt;

    showDialog(
      context: context,
      builder: (context) => Center(
        child: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setDialogState) => Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                width: 420,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.task_alt_rounded,
                            color: Colors.blueAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Them cong viec moi',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: 'Tieu de',
                        prefixIcon: const Icon(Icons.title_rounded, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Mo ta (khong bat buoc)',
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDueAt ?? now,
                          firstDate: DateTime(now.year - 1, 1, 1),
                          lastDate: DateTime(now.year + 5, 12, 31),
                        );
                        if (pickedDate == null) return;

                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            selectedDueAt ?? now,
                          ),
                        );

                        setDialogState(() {
                          selectedDueAt = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime?.hour ?? 23,
                            pickedTime?.minute ?? 59,
                          );
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedDueAt == null
                                ? const Color(0xFFE2E8F0)
                                : Colors.blueAccent.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 20,
                              color: selectedDueAt == null
                                  ? const Color(0xFF64748B)
                                  : Colors.blueAccent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedDueAt == null
                                    ? 'Han hoan thanh (khong bat buoc)'
                                    : 'Han: '
                                          '${selectedDueAt!.day.toString().padLeft(2, '0')}/'
                                          '${selectedDueAt!.month.toString().padLeft(2, '0')}/'
                                          '${selectedDueAt!.year} '
                                          '${selectedDueAt!.hour.toString().padLeft(2, '0')}:'
                                          '${selectedDueAt!.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: selectedDueAt == null
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF1E293B),
                                  fontWeight: selectedDueAt == null
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            if (selectedDueAt != null)
                              InkWell(
                                onTap: () =>
                                    setDialogState(() => selectedDueAt = null),
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Huy',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            if (titleController.text.trim().isEmpty ||
                                selectedBoardId == null) {
                              return;
                            }
                            final authState = context.read<AuthBloc>().state;
                            final userId = authState is Authenticated
                                ? authState.user.id
                                : null;
                            final task = Task(
                              id: const Uuid().v4(),
                              boardId: selectedBoardId!,
                              title: titleController.text.trim(),
                              description: descController.text.trim(),
                              status: 'todo',
                              creatorId: userId,
                              createdAt: DateTime.now().toIso8601String(),
                              dueAt: selectedDueAt,
                            );
                            context.read<TaskBloc>().add(AddTaskEvent(task));
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Them cong viec',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
