import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_preferences.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  bool _loading = true;
  String _displayName = 'User';
  String _email = '';
  String _bio = '';
  String? _avatarUrl;
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
    _loadProfile();
    _loadStats();
  }

  Future<void> _loadProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    try {
      final profile = await _client
          .from('profiles')
          .select('display_name,email,avatar_url,bio')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _displayName =
            (profile?['display_name'] as String?) ??
            (user.email?.split('@').first ?? 'User');
        _email = (profile?['email'] as String?) ?? (user.email ?? '');
        _avatarUrl = profile?['avatar_url'] as String?;
        if (_avatarUrl != null) {
          _avatarUrl = '$_avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}';
        }
        _bio = (profile?['bio'] as String?) ?? '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _displayName = user.email?.split('@').first ?? 'User';
        _email = user.email ?? '';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStats() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final userId = user.id;

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

      final allTasks = <String, String>{};
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
      debugPrint('Error loading profile stats: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppPreferences.tr('Trang cá nhân', 'Profile')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: Colors.blueAccent.withOpacity(0.15),
                        backgroundImage: _avatarUrl != null
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: _avatarUrl == null
                            ? Text(
                                _displayName.isEmpty
                                    ? 'U'
                                    : _displayName[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _displayName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                _infoCard(
                  icon: Icons.mail_outline_rounded,
                  title: AppPreferences.tr('Liên hệ', 'Contact'),
                  value: _email,
                  subtitle: AppPreferences.tr(
                    'Email đã xác minh từ tài khoản',
                    'Verified account email',
                  ),
                ),
                const SizedBox(height: 12),
                _infoCard(
                  icon: Icons.badge_outlined,
                  title: AppPreferences.tr('Thông tin tài khoản', 'Account info'),
                  value: _displayName,
                  subtitle: 'ID: ${_client.auth.currentUser?.id ?? ""}',
                ),
                if (_bio.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _infoCard(
                    icon: Icons.notes_rounded,
                    title: AppPreferences.tr('Mô tả bản thân', 'Bio'),
                    value: _bio.trim(),
                  ),
                ],
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/settings');
                          await _loadProfile();
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(
                          AppPreferences.tr('Chỉnh sửa hồ sơ', 'Edit profile'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
                        fontSize: 26,
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
}
