import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../../app_preferences.dart';
import '../../domain/repositories/task_repository.dart';
import '../../domain/repositories/board_repository.dart';
import '../../injection_container.dart' as di;

class EmptyDashboardView extends StatefulWidget {
  final VoidCallback onAddBoard;
  final VoidCallback onOpenMenu;

  const EmptyDashboardView({
    super.key,
    required this.onAddBoard,
    required this.onOpenMenu,
  });

  @override
  State<EmptyDashboardView> createState() => _EmptyDashboardViewState();
}

class _EmptyDashboardViewState extends State<EmptyDashboardView> {
  final SupabaseClient _client = Supabase.instance.client;
  bool _loading = true;

  String _displayName = AppPreferences.tr('Người dùng', 'User');
  String _email = '';
  String _bio = '';
  String? _avatarUrl;

  int _ownedBoards = 0;
  int _joinedBoards = 0;
  int _createdTasks = 0;
  int _assignedTasks = 0;
  int _doneTasks = 0;
  int _totalRelevantTasks = 0;
  int _friendCount = 0;
  RealtimeChannel? _tasksChannel;
  RealtimeChannel? _profileChannel;
  RealtimeChannel? _boardsChannel;
  RealtimeChannel? _membersChannel;
  RealtimeChannel? _assigneesChannel;
  RealtimeChannel? _friendsChannel;
  String _avatarCacheKey = DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _subscribeToTasks();
    _subscribeToProfile();
    _subscribeToBoards();
    _subscribeToMembers();
    _subscribeToAssignees();
    _subscribeToFriends();
  }

  @override
  void dispose() {
    _unsubscribeFromTasks();
    _unsubscribeFromProfile();
    _unsubscribeFromBoards();
    _unsubscribeFromMembers();
    _unsubscribeFromAssignees();
    _unsubscribeFromFriends();
    super.dispose();
  }

  void _subscribeToTasks() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    _tasksChannel = _client
        .channel('public:tasks:stats')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          callback: (payload) {
            // Cập nhật thống kê thôi, không cần ép tải lại ảnh
            _loadProfileData(forceRefreshAvatar: false);
          },
        )
        .subscribe();
  }

  void _unsubscribeFromTasks() {
    if (_tasksChannel != null) {
      _client.removeChannel(_tasksChannel!);
      _tasksChannel = null;
    }
  }

  void _subscribeToProfile() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    _profileChannel = _client
        .channel('public:profiles:id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            debugPrint('DEBUG: Dashboard - Profile updated realtime, reloading...');
            _loadProfileData(forceRefreshAvatar: true);
          },
        )
        .subscribe();
  }

  void _unsubscribeFromProfile() {
    if (_profileChannel != null) {
      _client.removeChannel(_profileChannel!);
      _profileChannel = null;
    }
  }

  void _subscribeToBoards() {
    _boardsChannel = _client
        .channel('public:boards:stats')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'boards',
          callback: (payload) => _loadProfileData(forceRefreshAvatar: false),
        )
        .subscribe();
  }

  void _unsubscribeFromBoards() {
    if (_boardsChannel != null) {
      _client.removeChannel(_boardsChannel!);
      _boardsChannel = null;
    }
  }

  void _subscribeToMembers() {
    _membersChannel = _client
        .channel('public:board_members:stats')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'board_members',
          callback: (payload) => _loadProfileData(forceRefreshAvatar: false),
        )
        .subscribe();
  }

  void _unsubscribeFromMembers() {
    if (_membersChannel != null) {
      _client.removeChannel(_membersChannel!);
      _membersChannel = null;
    }
  }

  void _subscribeToAssignees() {
    _assigneesChannel = _client
        .channel('public:task_assignees:stats')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'task_assignees',
          callback: (payload) => _loadProfileData(forceRefreshAvatar: false),
        )
        .subscribe();
  }

  void _unsubscribeFromAssignees() {
    if (_assigneesChannel != null) {
      _client.removeChannel(_assigneesChannel!);
      _assigneesChannel = null;
    }
  }

  void _subscribeToFriends() {
    _friendsChannel = _client
        .channel('public:friendships:stats')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (payload) => _loadProfileData(forceRefreshAvatar: false),
        )
        .subscribe();
  }

  void _unsubscribeFromFriends() {
    if (_friendsChannel != null) {
      _client.removeChannel(_friendsChannel!);
      _friendsChannel = null;
    }
  }

  Future<void> _loadProfileData({bool forceRefreshAvatar = false}) async {
    if (forceRefreshAvatar) {
      _avatarCacheKey = DateTime.now().millisecondsSinceEpoch.toString();
    }
    final currentUser = _client.auth.currentUser;
    final authState = context.read<AuthBloc>().state;
    final userId =
        currentUser?.id ??
        (authState is Authenticated ? authState.user.id : null);
    final authEmail =
        currentUser?.email ??
        (authState is Authenticated ? authState.user.email : null);

    if (userId == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    if (mounted) {
      setState(() {
        _displayName = (authEmail ?? AppPreferences.tr('Người dùng', 'User'))
            .split('@')
            .first;
        _email = authEmail ?? '';
      });
    }

    try {
      // Đảm bảo dữ liệu offline được đẩy lên trước khi đếm
      await di.sl<BoardRepository>().syncPendingBoards();
      await di.sl<TaskRepository>().syncPendingTasks();
      
      // Chạy tất cả các query đồng thời để tối ưu hiệu năng.
      final results = await Future.wait<dynamic>([
        // 0. Profile fetch
        _client
            .from('profiles')
            .select('display_name,email,avatar_url,bio')
            .eq('id', userId)
            .maybeSingle()
            .catchError((e) {
              debugPrint('Error fetching profile: $e');
              return null;
            }),
        // 1. Owned boards count
        _client.from('boards').select('id').eq('owner_id', userId).catchError((e) {
          debugPrint('Error fetching owned boards: $e');
          return [];
        }),
        // 2. Joined boards count
        _client.from('board_members').select('board_id').eq('user_id', userId).catchError((e) {
          debugPrint('Error fetching joined boards: $e');
          return [];
        }),
        // 3. Tasks created by me
        _client
            .from('tasks')
            .select('id, status')
            .eq('creator_id', userId)
            .catchError((e) {
              debugPrint('Error fetching created tasks: $e');
              return [];
            }),
        // 4. Tasks assigned to me
        _client
            .from('task_assignees')
            .select('task_id, tasks(id, status, creator_id)')
            .eq('user_id', userId)
            .catchError((e) {
              debugPrint('Error fetching assigned tasks: $e');
              return [];
            }),
        // 5. Friendships count
        _client
            .from('friendships')
            .select('user_id, friend_id')
            .or('user_id.eq.$userId,friend_id.eq.$userId')
            .catchError((e) {
              debugPrint('Error fetching friendships: $e');
              return [];
            }),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final ownedBoardsList = results[1] as List;
      final joinedBoardsList = results[2] as List;
      final createdTasks = results[3] as List;
      final assignedTasksJoin = results[4] as List;
      final friendshipsList = results[5] as List;

      debugPrint('DEBUG: Dashboard - UserId: $userId');
      debugPrint('DEBUG: Dashboard - Owned Boards: ${ownedBoardsList.length}');
      debugPrint('DEBUG: Dashboard - Joined Boards: ${joinedBoardsList.length}');
      debugPrint('DEBUG: Dashboard - Created Tasks: ${createdTasks.length}');
      debugPrint('DEBUG: Dashboard - Assigned Tasks (Join): ${assignedTasksJoin.length}');
      debugPrint('DEBUG: Dashboard - Friendships: ${friendshipsList.length}');

      // Xử lý logic gộp Task (tránh trùng lặp nếu vừa là creator vừa là assignee)
      final allRelevantTasks = <String, String>{}; // Map<TaskId, Status>
      
      for (final t in createdTasks) {
        final task = t as Map<String, dynamic>;
        allRelevantTasks[task['id'].toString()] = task['status'].toString();
      }
      
      for (final a in assignedTasksJoin) {
        final join = a as Map<String, dynamic>;
        final task = join['tasks'] as Map<String, dynamic>?;
        if (task != null) {
          allRelevantTasks[task['id'].toString()] = task['status'].toString();
        }
      }

      // Tính toán kết quả
      final ownedBoardsCount = ownedBoardsList.length;
      final joinedBoardsCount = joinedBoardsList.length > ownedBoardsCount
          ? joinedBoardsList.length - ownedBoardsCount
          : 0;
      
      final createdTasksCount = createdTasks.length;
      int assignedFromOthersCount = 0;
      for (final a in assignedTasksJoin) {
        final join = a as Map<String, dynamic>;
        final task = join['tasks'] as Map<String, dynamic>?;
        if (task != null && task['creator_id'] != userId) {
          assignedFromOthersCount++;
        }
      }
      
      final assignedTasksCount = assignedFromOthersCount;
      final doneTasksCount = allRelevantTasks.values.where((status) => status == 'done').length;

      final uniqueFriends = <String>{};
      for (final item in friendshipsList) {
        final m = item as Map<String, dynamic>;
        if (m['user_id'] != userId) uniqueFriends.add(m['user_id'] as String);
        if (m['friend_id'] != userId)
          uniqueFriends.add(m['friend_id'] as String);
      }

      if (!mounted) return;
      setState(() {
        _displayName =
            (profile?['display_name'] as String?) ??
            ((profile?['email'] as String?)?.split('@').first ?? _displayName);
        _email = (profile?['email'] as String?) ?? _email;
        _bio = (profile?['bio'] as String?) ?? '';
        _avatarUrl = profile?['avatar_url'] as String?;
        if (_avatarUrl != null) {
          _avatarUrl = '$_avatarUrl?t=$_avatarCacheKey';
        }

        _ownedBoards = ownedBoardsCount;
        _joinedBoards = joinedBoardsCount;
        _createdTasks = createdTasksCount;
        _assignedTasks = assignedTasksCount;
        _doneTasks = doneTasksCount;
        _totalRelevantTasks = allRelevantTasks.length;
        _friendCount = uniqueFriends.length;
      });
    } catch (e) {
      debugPrint('DEBUG: EmptyDashboardView._loadProfileData - Error: $e');
      // Keep fallback values
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadProfileData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildStatsGrid(),
          const SizedBox(height: 14),
          _buildCompletionChartCard(),
          const SizedBox(height: 20),
          _buildQuickActions(),
          const SizedBox(height: 20),
          _buildAccountActions(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.blueAccent.withOpacity(0.12),
            child: ClipOval(
              child: _avatarUrl != null
                  ? Image.network(
                      _avatarUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded) return child;
                        return AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          child: child,
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
                    )
                  : _buildDefaultAvatar(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email.isEmpty
                      ? AppPreferences.tr('Chưa có email', 'No email')
                      : _email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                if (_bio.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF475569)),
                  ),
                ],
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3, // Điều chỉnh tỉ lệ để thẻ không quá dài hoặc quá ngắn
      children: [
        _statCard(
          AppPreferences.tr('Bảng sở hữu', 'Owned Boards'),
          _ownedBoards.toString(),
          Icons.dashboard_customize,
        ),
        _statCard(
          AppPreferences.tr('Bảng tham gia', 'Joined Boards'),
          _joinedBoards.toString(),
          Icons.group_outlined,
        ),
        _statCard(
          AppPreferences.tr('Thẻ đã tạo', 'Created Tasks'),
          _createdTasks.toString(),
          Icons.add_task_outlined,
        ),
        _statCard(
          AppPreferences.tr('Thẻ được giao', 'Assigned Tasks'),
          _assignedTasks.toString(),
          Icons.task_alt_outlined,
        ),
        _statCard(
          AppPreferences.tr('Thẻ hoàn thành', 'Completed Tasks'),
          _doneTasks.toString(),
          Icons.check_circle_outline,
        ),
        _statCard(
          AppPreferences.tr('Số bạn bè', 'Total Friends'),
          _friendCount.toString(),
          Icons.people_outline_rounded,
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      // width: 165, // Đã xóa chiều rộng cố định để GridView tự căn chỉnh
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueAccent),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionChartCard() {
    final progress = _totalRelevantTasks == 0
        ? 0.0
        : (_doneTasks / _totalRelevantTasks).clamp(0.0, 1.0);
    final percentText = '${(progress * 100).round()}%';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  backgroundColor: const Color(0xFFE2E8F0),
                  strokeCap: StrokeCap.round,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF2563EB),
                  ),
                ),
                Container(
                  width: 94,
                  height: 94,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      percentText,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Xong',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppPreferences.tr(
                    'Tỉ lệ hoàn thành công việc',
                    'Task Completion Rate',
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  AppPreferences.tr(
                    'Tính theo thẻ được giao và đã xong',
                    'Based on assigned and finished tasks',
                  ),
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppPreferences.tr('Hành động nhanh', 'Quick Actions'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onAddBoard,
                  icon: const Icon(Icons.add),
                  label: Text(AppPreferences.tr('Tạo bảng', 'Create Board')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onOpenMenu,
                  icon: const Icon(Icons.menu_open),
                  label: Text(AppPreferences.tr('Mở menu', 'Open Menu')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/my-tasks'),
              icon: const Icon(Icons.assignment_ind_outlined),
              label: Text(AppPreferences.tr('Công việc của tôi', 'My Tasks')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppPreferences.tr('Tài khoản', 'Account'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_outlined),
            title: Text(AppPreferences.tr('Cài đặt', 'Settings')),
            onTap: () async {
              await Navigator.pushNamed(context, '/settings');
              await _loadProfileData(forceRefreshAvatar: true);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.group_outlined),
            title: Text(AppPreferences.tr('Bạn bè', 'Friends')),
            onTap: () async {
              await Navigator.pushNamed(context, '/friends');
              await _loadProfileData(forceRefreshAvatar: true);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: Text(
              AppPreferences.tr('Đăng xuất', 'Logout'),
              style: const TextStyle(color: Colors.redAccent),
            ),
            onTap: () => context.read<AuthBloc>().add(SignOutRequested()),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Text(
      _displayName.isEmpty ? 'U' : _displayName[0].toUpperCase(),
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.blueAccent,
      ),
    );
  }
}
