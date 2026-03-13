import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_preferences.dart';

import '../../domain/entities/friend_user.dart';
import '../../data/repositories/friend_repository.dart';
import '../../injection_container.dart';
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
  int _createdTasks = 0;
  int _assignedTasks = 0;
  int _doneTasks = 0;
  int _totalRelevantTasks = 0;
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

  final _friendRepo = sl<FriendRepository>();

  Future<void> _loadStats() async {
    final userId = widget.friend.id;

    try {
      final results = await Future.wait([
        _client.from('boards').select('id').eq('owner_id', userId),
        _client.from('board_members').select('board_id').eq('user_id', userId),
        _client.from('tasks').select('id, status').eq('creator_id', userId),
        _client.from('task_assignees').select('task_id, tasks(id, status, creator_id)').eq('user_id', userId),
        _client.from('friendships').select('user_id, friend_id').or('user_id.eq.$userId,friend_id.eq.$userId'),
      ]);

      final owned = results[0] as List;
      final joined = results[1] as List;
      final created = (results[2] as List).map((e) => e as Map<String, dynamic>);
      final assignedJoin = (results[3] as List).map((e) => e as Map<String, dynamic>);
      final friends = results[4] as List;

      final allTasks = <String, String>{}; // Map<Id, Status>
      for (final t in created) {
        allTasks[t['id'].toString()] = t['status'].toString();
      }

      int assignedFromOthers = 0;
      for (final a in assignedJoin) {
        final task = a['tasks'] as Map<String, dynamic>?;
        if (task != null) {
          allTasks[task['id'].toString()] = task['status'].toString();
          if (task['creator_id'] != userId) {
            assignedFromOthers++;
          }
        }
      }

      final uniqueFriends = <String>{};
      for (final item in friends) {
        final m = item as Map<String, dynamic>;
        if (m['user_id'] != userId) uniqueFriends.add(m['user_id']);
        if (m['friend_id'] != userId) uniqueFriends.add(m['friend_id']);
      }

      if (!mounted) return;
      setState(() {
        _ownedBoards = owned.length;
        _joinedBoards = joined.length > _ownedBoards ? joined.length - _ownedBoards : 0;
        _createdTasks = created.length;
        _assignedTasks = assignedFromOthers;
        _doneTasks = allTasks.values.where((s) => s == 'done').length;
        _totalRelevantTasks = allTasks.length;
        _friendCount = uniqueFriends.length;
      });
    } catch (e) {
      debugPrint('Error loading friend stats: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  Future<void> _removeFriend() async {
    try {
      await _friendRepo.removeFriend(widget.friend.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppPreferences.tr('Đã xóa bạn bè.', 'Friend removed.')),
        ),
      );
      Navigator.pop(context, true); // Trả về true để thông báo cần refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppPreferences.tr('Không thể xóa bạn bè', 'Could not remove friend')}: $e',
          ),
        ),
      );
    }
  }

  void _showRemoveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppPreferences.tr('Xác nhận xóa', 'Confirm removal')),
        content: Text(
          AppPreferences.tr(
            'Bạn có chắc chắn muốn xóa "${widget.friend.displayName ?? widget.friend.email}" khỏi danh sách bạn bè?',
            'Are you sure you want to remove "${widget.friend.displayName ?? widget.friend.email}" from your friends list?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppPreferences.tr('Hủy', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFriend();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(AppPreferences.tr('Xóa', 'Remove')),
          ),
        ],
      ),
    );
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showRemoveDialog(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.person_remove_outlined),
                label: Text(AppPreferences.tr('Xóa bạn bè', 'Remove Friend')),
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
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
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
                  AppPreferences.tr('Thẻ đã tạo', 'Created tasks'),
                  _createdTasks.toString(),
                  Icons.add_task_outlined,
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
    return Container(
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
