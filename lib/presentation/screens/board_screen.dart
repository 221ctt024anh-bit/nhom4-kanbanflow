import 'dart:async';
import 'dart:typed_data';

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
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '../widgets/board_member_dialog.dart';
import '../widgets/board_member_select_dialog.dart';
import '../widgets/user_avatar.dart';
import '../widgets/expandable_fab.dart';
import 'workspace_menu_screen.dart';
import '../../app_preferences.dart';
import '../../injection_container.dart';
import '../../data/repositories/task_interaction_repository.dart';
import '../widgets/board/board_utils.dart';
import '../widgets/board/board_overview.dart';
import '../widgets/board/quick_filter_chips.dart';
import '../widgets/board/board_column.dart';
import '../widgets/board/landscape_board_widgets.dart';
import '../widgets/notification_dialog.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final NotificationRepository _notificationRepository =
      sl<NotificationRepository>();
  String? selectedBoardId;
  String selectedLandscapeStatus = 'todo';
  String _quickFilter = 'all';
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();
  final PageController _pageController = PageController(viewportFraction: 0.88);
  Timer? _taskReloadDebounce;
  int _unreadNotificationCount = 0;
  bool _loadingNotifications = false;
  List<AppNotification> _notifications = [];
  bool _inAppNotificationsEnabled = true;
  final Set<String> _notifiedOverdueIds = {};
  RealtimeChannel? _notificationChannel;
  RealtimeChannel? _tasksChannel;

  @override
  void initState() {
    super.initState();
    searchController.addListener(_onSearchChanged);
    _initNotificationFlow();
    _subscribeToNotifications();
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    _pageController.dispose();
    _taskReloadDebounce?.cancel();
    _unsubscribeFromNotifications();
    _unsubscribeFromTasks();
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
    if (mounted) {
      setState(() {
        _loadingNotifications = true;
      });
    }
    try {
      final results = await Future.wait([
        _notificationRepository.getUnreadCount(),
        _notificationRepository.getNotifications(),
      ]);
      final unread = results[0] as int;
      final notifications = results[1] as List<AppNotification>;

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

  void _subscribeToNotifications() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _notificationChannel = Supabase.instance.client
        .channel('public:user_notifications:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _refreshNotifications();
          },
        )
        .subscribe();
  }

  void _unsubscribeFromNotifications() {
    if (_notificationChannel != null) {
      Supabase.instance.client.removeChannel(_notificationChannel!);
      _notificationChannel = null;
    }
  }

  void _subscribeToTasks(String boardId) {
    _unsubscribeFromTasks(); // Hủy sub cũ trước khi sub mới

    _tasksChannel = Supabase.instance.client
        .channel('public:tasks:board_id=eq.$boardId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'board_id',
            value: boardId,
          ),
          callback: (_) => _scheduleTaskReload(boardId),
        )
        .subscribe();
  }

  void _unsubscribeFromTasks() {
    _taskReloadDebounce?.cancel();
    _taskReloadDebounce = null;
    if (_tasksChannel != null) {
      Supabase.instance.client.removeChannel(_tasksChannel!);
      _tasksChannel = null;
    }
  }

  void _scheduleTaskReload(String boardId) {
    _taskReloadDebounce?.cancel();
    _taskReloadDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || selectedBoardId != boardId) return;
      context.read<TaskBloc>().add(
        LoadTasks(boardId: boardId, query: searchController.text),
      );
    });
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return NotificationDialog(
          notifications: _notifications,
          repository: _notificationRepository,
          onRefresh: _refreshNotifications,
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
    return BoardUtils.applyQuickFilter(tasks, _quickFilter);
  }

  void _checkOverdueNotifications(List<Task> tasks) {
    if (!_inAppNotificationsEnabled) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    for (final task in tasks) {
      if (BoardUtils.isOverdueTask(task) && !_notifiedOverdueIds.contains(task.id)) {
        // Only notify if user is involved
        if (task.assigneeIds.contains(userId) ||
            (task.assigneeIds.isEmpty && task.creatorId == userId)) {
          _notifiedOverdueIds.add(task.id);

          _notificationRepository
              .createNotification(
                userId: userId,
                taskId: task.id,
                title: AppPreferences.tr('Công việc quá hạn', 'Overdue Task'),
                message: AppPreferences.tr(
                  'Công việc "${task.title}" đã quá hạn!',
                  'Task "${task.title}" is overdue!',
                ),
              )
              .then((_) => _refreshNotifications());
        }
      }
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
      child: PopScope(
        canPop: selectedBoardId == null,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;

          if (selectedBoardId != null) {
            setState(() {
              selectedBoardId = null;
              isSearching = false;
              searchController.clear();
            });
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.person_outline_rounded),
              tooltip: AppPreferences.tr('Trang cá nhân', 'My profile'),
              onPressed: () {
                setState(() {
                  selectedBoardId = null;
                  isSearching = false;
                  searchController.dispose();
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
                      final currentRole = state.getRole(selectedBoardId!);
                      // Note: 'owner' is usually the creator, but our RBAC logic treats owners/admins similarly for management
                      if (currentRole != 'owner' && currentRole != 'admin') {
                        return const SizedBox.shrink();
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
              : BlocBuilder<BoardBloc, BoardState>(
                  builder: (context, state) {
                    if (state is BoardLoaded) {
                      final role = state.getRole(selectedBoardId!);
                      if (role == 'viewer') {
                        return const SizedBox.shrink();
                      }
                    }
                    return ExpandableFab(
                      distance: 60.0,
                      onClose: () {},
                      children: [
                        ActionButton(
                          onPressed: _pickAudio,
                          icon: const Icon(Icons.mic_none),
                          label: AppPreferences.tr('Âm thanh', 'Audio'),
                        ),
                        ActionButton(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image_outlined),
                          label: AppPreferences.tr(
                            'Ảnh & Video',
                            'Image & Video',
                          ),
                        ),
                        ActionButton(
                          onPressed: () => _showAddTaskDialog(context),
                          icon: const Icon(Icons.text_fields),
                          label: AppPreferences.tr('Văn bản', 'Text'),
                        ),
                      ],
                    );
                  },
                ),
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
    _subscribeToTasks(id);
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
    return BlocListener<TaskBloc, TaskState>(
      listener: (context, state) {
        if (state is TaskError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppPreferences.tr(
                  'Lỗi: ${state.message}',
                  'Error: ${state.message}',
                ),
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      child: BlocBuilder<BoardBloc, BoardState>(
        builder: (context, boardState) {
          return BlocBuilder<TaskBloc, TaskState>(
            builder: (context, state) {
              if (state is TaskLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is TaskLoaded) {
                final visibleTasks = _applyQuickFilter(state.tasks);
                _checkOverdueNotifications(state.tasks);
                final currentRole = boardState is BoardLoaded
                    ? boardState.getRole(selectedBoardId!)
                    : null;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideScreen =
                        constraints.maxWidth > 600 ||
                        MediaQuery.of(context).orientation ==
                            Orientation.landscape;
                    final visibleStatuses = _quickFilter == 'mine'
                        ? <String>['todo']
                        : (BoardUtils.isSingleStatusFilter(_quickFilter)
                            ? <String>[_quickFilter]
                            : BoardUtils.defaultStatuses());

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
                                    (status) => BoardMenuItem(
                                      title: BoardUtils.getStatusTitle(status),
                                      status: status,
                                      accentColor: BoardUtils.getStatusColor(status),
                                      allTasks: visibleTasks,
                                      isSelected: selectedLandscapeStatus == status,
                                      onTap: (newStatus) {
                                        setState(() {
                                          selectedLandscapeStatus = newStatus;
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                          // Kẻ dọc phân cách
                          Container(
                            width: 1,
                            color: Colors.grey.withOpacity(0.2),
                          ),
                          // Khu vực chứa thẻ bên phải
                          Expanded(
                            child: Container(
                              color:
                                  Colors.grey[50], // Nền nhạt cho khu vực thẻ
                              child: LandscapeTaskContent(
                                allTasks: visibleTasks,
                                status: selectedLandscapeStatus,
                                role: currentRole,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // Mặc định: Giao diện dọc (Portrait) - Menu sổ xuống
                    var portraitStatuses = List<String>.from(visibleStatuses);

                    // Tự động ẩn cột Quá hạn nếu không có việc và không bị lọc cứng
                    if (_quickFilter != 'overdue' &&
                        portraitStatuses.contains('overdue')) {
                      final hasOverdue = visibleTasks.any(BoardUtils.isOverdueTask);
                      if (!hasOverdue) {
                        portraitStatuses.remove('overdue');
                      }
                    }

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 24,
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: double.infinity,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BoardOverview(
                                tasks: visibleTasks,
                                allTasks: state.tasks,
                                visibleStatuses: portraitStatuses,
                              ),
                              const SizedBox(height: 12),
                              QuickFilterChips(
                                currentFilter: _quickFilter,
                                onFilterChanged: (value) {
                                  setState(() {
                                    _quickFilter = value;
                                    if (BoardUtils.isSingleStatusFilter(value)) {
                                      selectedLandscapeStatus = value;
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 18),
                              for (
                                var i = 0;
                                i < portraitStatuses.length;
                                i++
                              ) ...[
                                BoardColumn(
                                  title: BoardUtils.getStatusTitle(portraitStatuses[i]),
                                  status: portraitStatuses[i],
                                  allTasks: visibleTasks,
                                  accentColor: BoardUtils.getStatusColor(portraitStatuses[i]),
                                  role: currentRole,
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 64,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppPreferences.tr(
                            'Lỗi kết nối hoặc dữ liệu',
                            'Connection or Data Error',
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
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
                          icon: const Icon(Icons.refresh),
                          label: Text(AppPreferences.tr('Thử lại', 'Retry')),
                        ),
                      ],
                    ),
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
        },
      ),
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
                      id: Uuid().v4(),
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

  void _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (mounted) {
        _showAddTaskDialog(
          context,
          initialAttachmentName: file.name,
          initialAttachmentBytes: file.bytes,
          taskType: 'image',
        );
      }
    }
  }

  void _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (mounted) {
        _showAddTaskDialog(
          context,
          initialAttachmentName: file.name,
          initialAttachmentBytes: file.bytes,
          taskType: 'audio',
        );
      }
    }
  }

  void _showAddTaskDialog(
    BuildContext context, {
    String? initialAttachmentName,
    Uint8List? initialAttachmentBytes,
    List<ChecklistItem>? initialChecklist,
    String taskType = 'text',
  }) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? selectedDueAt;
    List<String> selectedAssigneeIds = [];
    Uint8List? currentAttachmentBytes = initialAttachmentBytes;
    String? currentAttachmentName = initialAttachmentName;
    String currentTaskType = taskType;
    if (initialChecklist != null) currentTaskType = 'checklist';
    bool _isUploading = false;

    // Determine form type and colors
    String dialogTitle = AppPreferences.tr('Thêm công việc', 'Add Task');
    IconData headerIcon = Icons.auto_awesome_rounded;
    Color themeColor = Colors.blueAccent;

    void _updateDialogTheme(Uint8List? bytes, String? name) {
      if (bytes != null) {
        if (name?.endsWith('.png') == true &&
            name?.contains('drawing_') == true) {
          dialogTitle = AppPreferences.tr('Bản vẽ mới', 'New Drawing');
          headerIcon = Icons.gesture_rounded;
          themeColor = Colors.orangeAccent;
        } else if (lookupMimeType(name ?? '')?.startsWith('image/') == true) {
          dialogTitle = AppPreferences.tr(
            'Thêm ảnh & video',
            'Add Image & Video',
          );
          headerIcon = Icons.image_rounded;
          themeColor = Colors.purpleAccent;
        } else if (lookupMimeType(name ?? '')?.startsWith('audio/') == true) {
          dialogTitle = AppPreferences.tr('Thêm âm thanh', 'Add Audio');
          headerIcon = Icons.keyboard_voice_rounded;
          themeColor = Colors.redAccent;
        } else {
          dialogTitle = AppPreferences.tr('Thêm tài liệu', 'Add Document');
          headerIcon = Icons.description_rounded;
          themeColor = Colors.teal;
        }
      } else if (initialChecklist != null) {
        dialogTitle = AppPreferences.tr('Danh sách mới', 'New Checklist');
        headerIcon = Icons.checklist_rtl_rounded;
        themeColor = Colors.greenAccent;
      } else {
        dialogTitle = AppPreferences.tr('Thêm công việc', 'Add Task');
        headerIcon = Icons.auto_awesome_rounded;
        themeColor = Colors.blueAccent;
      }
    }

    _updateDialogTheme(currentAttachmentBytes, currentAttachmentName);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setDialogState) => Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                width: 440,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium Header with dynamic color
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.05),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: themeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              headerIcon,
                              color: themeColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dialogTitle,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  AppPreferences.tr(
                                    'Điền thông tin cho thẻ của bạn',
                                    'Fill in the details for your task',
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Enhanced Preview Card
                          if (initialAttachmentBytes != null ||
                              initialChecklist != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: themeColor.withOpacity(0.1),
                                ),
                                color: const Color(0xFFF8FAFC),
                              ),
                              child: Column(
                                children: [
                                  if (currentAttachmentBytes != null)
                                    if (lookupMimeType(
                                          currentAttachmentName ?? '',
                                        )?.startsWith('image/') ==
                                        true)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Image.memory(
                                          currentAttachmentBytes!,
                                          height: 160,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.05),
                                                    blurRadius: 10,
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                lookupMimeType(
                                                          currentAttachmentName ??
                                                              '',
                                                        )?.startsWith(
                                                          'audio/',
                                                        ) ==
                                                        true
                                                    ? Icons.audio_file_rounded
                                                    : Icons.description_rounded,
                                                color:
                                                    lookupMimeType(
                                                          currentAttachmentName ??
                                                              '',
                                                        )?.startsWith(
                                                          'audio/',
                                                        ) ==
                                                        true
                                                    ? Colors.redAccent
                                                    : Colors.teal,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                currentAttachmentName ??
                                                    'file.dat',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF334155),
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                setDialogState(() {
                                                  currentAttachmentBytes = null;
                                                  currentAttachmentName = null;
                                                  _updateDialogTheme(
                                                    null,
                                                    null,
                                                  );
                                                });
                                              },
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                size: 20,
                                              ),
                                              color: Colors.grey,
                                            ),
                                          ],
                                        ),
                                      )
                                  else if (initialChecklist != null)
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.list_alt_rounded,
                                                size: 18,
                                                color: Colors.green,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${initialChecklist.length} tasks in list',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          ...initialChecklist
                                              .take(3)
                                              .map(
                                                (item) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 6,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 4,
                                                        height: 4,
                                                        decoration:
                                                            BoxDecoration(
                                                              color: Colors
                                                                  .green
                                                                  .withOpacity(
                                                                    0.5,
                                                                  ),
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          item.title,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                color: Color(
                                                                  0xFF475569,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          if (initialChecklist.length > 3)
                                            Text(
                                              '+ ${initialChecklist.length - 3} more...',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[500],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),

                          // Styled Inputs
                          _buildModernTextField(
                            controller: titleController,
                            hint: AppPreferences.tr(
                              'Tiêu đề thẻ',
                              'Task Title',
                            ),
                            icon: Icons.edit_note_rounded,
                            enabled: !_isUploading,
                            autofocus: true,
                          ),
                          const SizedBox(height: 16),
                          _buildModernTextField(
                            controller: descController,
                            hint: AppPreferences.tr(
                              'Ghi chú thêm (tùy chọn)',
                              'Additional notes (optional)',
                            ),
                            icon: Icons.notes_rounded,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),

                          // Add Attachment Button inside UI
                          if (currentAttachmentBytes == null &&
                              initialChecklist == null)
                            InkWell(
                              onTap: () async {
                                final result = await FilePicker.platform
                                    .pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: [
                                        'doc',
                                        'docx',
                                        'ppt',
                                        'pptx',
                                        'xls',
                                        'xlsx',
                                        'pdf',
                                        'png',
                                        'jpg',
                                        'jpeg',
                                      ],
                                      withData: true,
                                    );
                                if (result != null && result.files.isNotEmpty) {
                                  final file = result.files.first;
                                  setDialogState(() {
                                    currentAttachmentBytes = file.bytes;
                                    currentAttachmentName = file.name;
                                    _updateDialogTheme(
                                      currentAttachmentBytes,
                                      currentAttachmentName,
                                    );
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.attach_file_rounded,
                                      size: 20,
                                      color: themeColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppPreferences.tr(
                                        'Thêm tệp đính kèm',
                                        'Add attachment',
                                      ),
                                      style: TextStyle(
                                        color: themeColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Modern Date Picker
                          InkWell(
                            onTap: _isUploading
                                ? null
                                : () async {
                                    final now = DateTime.now();
                                    final pickedDate = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDueAt ?? now,
                                      firstDate: DateTime(now.year - 1, 1, 1),
                                      lastDate: DateTime(now.year + 5, 12, 31),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: ColorScheme.light(
                                              primary: themeColor,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (pickedDate == null) return;

                                    if (!context.mounted) return;
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
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selectedDueAt == null
                                      ? Colors.transparent
                                      : themeColor.withOpacity(0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 20,
                                    color: selectedDueAt == null
                                        ? const Color(0xFF94A3B8)
                                        : themeColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      selectedDueAt == null
                                          ? AppPreferences.tr(
                                              'Đặt hạn hoàn thành',
                                              'Set due date',
                                            )
                                          : _formatDueAt(selectedDueAt!),
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: selectedDueAt == null
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF1E293B),
                                        fontWeight: selectedDueAt == null
                                            ? FontWeight.w500
                                            : FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (selectedDueAt != null && !_isUploading)
                                    IconButton(
                                      onPressed: () => setDialogState(
                                        () => selectedDueAt = null,
                                      ),
                                      icon: const Icon(Icons.close_rounded),
                                      iconSize: 18,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      color: const Color(0xFF94A3B8),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Multi-Assignee Selection in Add Task Dialog
                          InkWell(
                            onTap: _isUploading
                                ? null
                                : () async {
                                    final result =
                                        await showDialog<List<String>>(
                                          context: context,
                                          builder: (context) =>
                                              BoardMemberSelectDialog(
                                                boardId: selectedBoardId!,
                                                currentAssigneeIds:
                                                    selectedAssigneeIds,
                                              ),
                                        );
                                    if (result != null) {
                                      setDialogState(() {
                                        selectedAssigneeIds = result;
                                      });
                                    }
                                  },
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selectedAssigneeIds.isEmpty
                                      ? Colors.transparent
                                      : themeColor.withOpacity(0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.people_outline_rounded,
                                    size: 20,
                                    color: selectedAssigneeIds.isEmpty
                                        ? const Color(0xFF94A3B8)
                                        : themeColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      selectedAssigneeIds.isEmpty
                                          ? AppPreferences.tr(
                                              'Giao cho thành viên',
                                              'Assign to members',
                                            )
                                          : AppPreferences.tr(
                                              'Đã chọn ${selectedAssigneeIds.length} người',
                                              'Selected ${selectedAssigneeIds.length} members',
                                            ),
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: selectedAssigneeIds.isEmpty
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF1E293B),
                                        fontWeight: selectedAssigneeIds.isEmpty
                                            ? FontWeight.w500
                                            : FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (selectedAssigneeIds.isNotEmpty)
                                    SizedBox(
                                      height: 24,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (
                                            int i = 0;
                                            i <
                                                (selectedAssigneeIds.length > 3
                                                    ? 3
                                                    : selectedAssigneeIds
                                                          .length);
                                            i++
                                          )
                                            Align(
                                              widthFactor: 0.6,
                                              child: UserAvatar(
                                                userId: selectedAssigneeIds[i],
                                                radius: 12,
                                              ),
                                            ),
                                          if (selectedAssigneeIds.length > 3)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 4,
                                              ),
                                              child: Text(
                                                '+${selectedAssigneeIds.length - 3}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: themeColor,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: _isUploading
                                      ? null
                                      : () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    AppPreferences.tr('Thoát', 'Exit'),
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: _isUploading
                                      ? null
                                      : () async {
                                          if (titleController.text
                                                  .trim()
                                                  .isEmpty ||
                                              selectedBoardId == null) {
                                            return;
                                          }

                                          final authBloc = context
                                              .read<AuthBloc>();
                                          final taskBloc = context
                                              .read<TaskBloc>();
                                          final navigator = Navigator.of(
                                            context,
                                          );

                                          setDialogState(
                                            () => _isUploading = true,
                                          );

                                          final authState = authBloc.state;
                                          final userId =
                                              authState is Authenticated
                                              ? authState.user.id
                                              : null;

                                          if (userId == null) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  AppPreferences.tr(
                                                    'Vui lòng đăng nhập để tạo thẻ',
                                                    'Please login to create task',
                                                  ),
                                                ),
                                                backgroundColor:
                                                    Colors.redAccent,
                                              ),
                                            );
                                            setDialogState(
                                              () => _isUploading = false,
                                            );
                                            return;
                                          }

                                          try {
                                            final task = Task(
                                              id: Uuid().v4(),
                                              boardId: selectedBoardId!,
                                              title: titleController.text
                                                  .trim(),
                                              description: descController.text
                                                  .trim(),
                                              status: 'todo',
                                              creatorId: userId,
                                              createdAt: DateTime.now()
                                                  .toIso8601String(),
                                              dueAt: selectedDueAt,
                                              assigneeIds: selectedAssigneeIds,
                                              checklist: initialChecklist ?? [],
                                              hasAttachments:
                                                  currentAttachmentBytes !=
                                                  null,
                                              taskType: currentTaskType,
                                            );

                                            taskBloc.add(AddTaskEvent(task));

                                            if (initialAttachmentBytes !=
                                                    null &&
                                                initialAttachmentName != null) {
                                              try {
                                                final repo =
                                                    sl<
                                                      TaskInteractionRepository
                                                    >();
                                                await repo.uploadAttachment(
                                                  boardId: selectedBoardId!,
                                                  taskId: task.id,
                                                  fileName:
                                                      initialAttachmentName,
                                                  bytes: initialAttachmentBytes,
                                                  uploaderId: userId,
                                                  contentType: lookupMimeType(
                                                    initialAttachmentName,
                                                  ),
                                                );
                                              } catch (e) {
                                                debugPrint('Upload error: $e');
                                              }
                                            }

                                            taskBloc.add(
                                              LoadTasks(
                                                boardId: selectedBoardId!,
                                              ),
                                            );
                                            navigator.pop();
                                          } catch (e) {
                                            debugPrint('Create task error: $e');
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    AppPreferences.tr(
                                                      'Lỗi khi tạo thẻ: $e',
                                                      'Error creating task: $e',
                                                    ),
                                                  ),
                                                  backgroundColor:
                                                      Colors.redAccent,
                                                ),
                                              );
                                              setDialogState(
                                                () => _isUploading = false,
                                              );
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    elevation: 8,
                                    shadowColor: themeColor.withOpacity(0.4),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    backgroundColor: themeColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isUploading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Text(
                                          AppPreferences.tr(
                                            'Tạo thẻ ngay',
                                            'Create Now',
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
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
          ),
        ),
      ),
    );
  }

  String _formatDueAt(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool autofocus = false,
    bool enabled = true,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.transparent),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        enabled: enabled,
        maxLines: maxLines,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
