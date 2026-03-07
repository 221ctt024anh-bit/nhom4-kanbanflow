import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_preferences.dart';

import '../../domain/entities/friend_user.dart';
import 'chat_screen.dart';

class FriendProfileScreen extends StatefulWidget {
  final FriendUser friend;

  const FriendProfileScreen({super.key, required this.friend});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _loadingStats = true;
  int _ownedBoards = 0;
  int _joinedBoards = 0;
  int _assignedTasks = 0;
  int _doneTasks = 0;
  int _friendCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  String _statusText() {
    if (widget.friend.isOnline)
      return AppPreferences.tr('Đang trực tuyến', 'Online');
    final lastSeen = widget.friend.lastSeenAt;
    if (lastSeen == null) return AppPreferences.tr('Ngoại tuyến', 'Offline');

    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1)
      return AppPreferences.tr('Vừa hoạt động', 'Just active');
    if (diff.inMinutes < 60) {
      return AppPreferences.tr(
        'Hoạt động ${diff.inMinutes} phút trước',
        'Active ${diff.inMinutes} minutes ago',
      );
    }
    if (diff.inHours < 24) {
      return AppPreferences.tr(
        'Hoạt động ${diff.inHours} giờ trước',
        'Active ${diff.inHours} hours ago',
      );
    }
    return AppPreferences.tr(
      'Hoạt động ${diff.inDays} ngày trước',
      'Active ${diff.inDays} days ago',
    );
  }

  String _lastSeenDetail() {
    final lastSeen = widget.friend.lastSeenAt;
    if (lastSeen == null)
      return AppPreferences.tr('Chưa có dữ liệu', 'No data');

    final local = lastSeen.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  Future<void> _loadStats() async {
    final userId = widget.friend.id;

    try {
      int ownedBoards = 0;
      int joinedBoards = 0;
      int assignedTasks = 0;
      int doneTasks = 0;
      int friendCount = 0;

      try {
        final ownedBoardsResponse = await _client
            .from('boards')
            .select('id')
            .eq('owner_id', userId);
        ownedBoards = (ownedBoardsResponse as List).length;
      } catch (_) {}

      try {
        final joinedBoardsResponse = await _client
            .from('board_members')
            .select('board_id')
            .eq('user_id', userId);
        joinedBoards = (joinedBoardsResponse as List).length;
      } catch (_) {}

      try {
        final assignedTasksResponse = await _client
            .from('tasks')
            .select('id,status')
            .eq('assignee_id', userId);
        final assigned = assignedTasksResponse as List;
        assignedTasks = assigned.length;
        doneTasks = assigned
            .where((item) => (item as Map<String, dynamic>)['status'] == 'done')
            .length;
      } catch (_) {}

      try {
        final friendResponse = await _client
            .from('friendships')
            .select('friend_id')
            .eq('user_id', userId);
        friendCount = (friendResponse as List).length;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _ownedBoards = ownedBoards;
        _joinedBoards = joinedBoards;
        _assignedTasks = assignedTasks;
        _doneTasks = doneTasks;
        _friendCount = friendCount;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.friend.displayName ?? widget.friend.email;
    final statusText = _statusText();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppPreferences.tr('Trang cá nhân', 'Profile')),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 46,
                backgroundColor: Colors.blueAccent.withOpacity(0.15),
                backgroundImage: widget.friend.avatarUrl != null
                    ? NetworkImage(widget.friend.avatarUrl!)
                    : null,
                child: widget.friend.avatarUrl == null
                    ? Text(
                        name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                widget.friend.email,
                style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.friend.isOnline
                        ? Icons.circle
                        : Icons.schedule_rounded,
                    size: 14,
                    color: widget.friend.isOnline
                        ? Colors.green.shade600
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: widget.friend.isOnline
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(friend: widget.friend),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: Text(AppPreferences.tr('Nhắn tin', 'Message')),
              ),
            ),
            const SizedBox(height: 16),
            _infoCard(
              icon: widget.friend.isOnline
                  ? Icons.circle
                  : Icons.schedule_rounded,
              title: AppPreferences.tr(
                'Trạng thái hoạt động',
                'Activity status',
              ),
              value: statusText,
              subtitle: widget.friend.isOnline
                  ? AppPreferences.tr(
                      'Đang hoạt động ngay lúc này',
                      'Currently active',
                    )
                  : '${AppPreferences.tr('Lần cuối', 'Last seen')}: ${_lastSeenDetail()}',
              valueColor: widget.friend.isOnline
                  ? Colors.green.shade700
                  : Colors.grey.shade700,
            ),
            const SizedBox(height: 12),
            _infoCard(
              icon: Icons.mail_outline_rounded,
              title: AppPreferences.tr('Liên hệ', 'Contact'),
              value: widget.friend.email,
              subtitle: AppPreferences.tr(
                'Email đã xác minh từ tài khoản',
                'Verified account email',
              ),
            ),
            const SizedBox(height: 12),
            _infoCard(
              icon: Icons.badge_outlined,
              title: AppPreferences.tr('Thông tin tài khoản', 'Account info'),
              value: widget.friend.displayName?.trim().isNotEmpty == true
                  ? widget.friend.displayName!.trim()
                  : AppPreferences.tr(
                      'Chưa đặt tên hiển thị',
                      'No display name',
                    ),
              subtitle: 'ID: ${widget.friend.id}',
            ),
            if ((widget.friend.bio ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _infoCard(
                icon: Icons.notes_rounded,
                title: AppPreferences.tr('Mô tả bản thân', 'Bio'),
                value: widget.friend.bio!.trim(),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  AppPreferences.tr('Thống kê', 'Statistics'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 8),
                if (_loadingStats)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statCard(
                  AppPreferences.tr('Bảng sở hữu', 'Owned boards'),
                  _ownedBoards.toString(),
                  Icons.dashboard_customize,
                ),
                _statCard(
                  AppPreferences.tr('Bảng tham gia', 'Joined boards'),
                  _joinedBoards.toString(),
                  Icons.group_outlined,
                ),
                _statCard(
                  AppPreferences.tr('Task được giao', 'Assigned tasks'),
                  _assignedTasks.toString(),
                  Icons.task_alt_outlined,
                ),
                _statCard(
                  AppPreferences.tr('Task hoàn thành', 'Completed tasks'),
                  _doneTasks.toString(),
                  Icons.check_circle_outline,
                ),
                _statCard(
                  AppPreferences.tr('Số bạn bè', 'Friends'),
                  _friendCount.toString(),
                  Icons.people_outline_rounded,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _completionChartCard(),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    final width = (MediaQuery.of(context).size.width - 52) / 2;
    return Container(
      width: width,
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

  Widget _completionChartCard() {
    final progress = _assignedTasks == 0
        ? 0.0
        : (_doneTasks / _assignedTasks).clamp(0.0, 1.0);
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
                    Text(
                      AppPreferences.tr('Xong', 'Done'),
                      style: const TextStyle(
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
                    'Tỉ lệ hoàn thành task',
                    'Task completion rate',
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppPreferences.tr(
                    'Tính theo task được giao và task đã xong',
                    'Based on assigned and completed tasks',
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

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2563EB), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? const Color(0xFF0F172A),
                  ),
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
