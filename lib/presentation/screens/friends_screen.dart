import 'dart:async';

import 'package:flutter/material.dart';
import '../../app_preferences.dart';

import '../../data/repositories/friend_repository.dart';
import '../../domain/entities/friend_request.dart';
import '../../domain/entities/friend_user.dart';
import 'chat_screen.dart';
import 'friend_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _repo = FriendRepository();
  final _emailController = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  List<FriendUser> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refresh();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.getFriends(),
        _repo.getIncomingRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0] as List<FriendUser>;
        _incomingRequests = results[1] as List<FriendRequest>;
      });
    } catch (e) {
      _showSnack(
        '${AppPreferences.tr('Không tải được dữ liệu bạn bè', 'Failed to load friends')}: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendRequest() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack(
        AppPreferences.tr('Vui lòng nhập email.', 'Please enter an email.'),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await _repo.sendFriendRequestByEmail(email);
      _emailController.clear();
      _showSnack(
        AppPreferences.tr('Đã gửi lời mời kết bạn.', 'Friend request sent.'),
      );
      await _refresh();
    } catch (e) {
      _showSnack(
        '${AppPreferences.tr('Không thể gửi lời mời', 'Could not send request')}: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _respond(FriendRequest request, bool accept) async {
    try {
      await _repo.respondToRequest(requestId: request.id, accept: accept);
      _showSnack(
        accept
            ? AppPreferences.tr('Đã chấp nhận lời mời.', 'Accepted invitation.')
            : AppPreferences.tr('Đã từ chối lời mời.', 'Declined invitation.'),
      );
      await _refresh();
    } catch (e) {
      _showSnack(
        '${AppPreferences.tr('Không thể xử lý lời mời', 'Could not process invitation')}: $e',
      );
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppPreferences.tr('Bạn bè', 'Friends')),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: AppPreferences.tr('Làm mới', 'Refresh'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSendRequestCard(),
                const SizedBox(height: 16),
                _buildIncomingRequestsCard(),
                const SizedBox(height: 16),
                _buildFriendsCard(),
              ],
            ),
    );
  }

  Widget _buildSendRequestCard() {
    return _sectionCard(
      title: AppPreferences.tr('Kết bạn bằng email', 'Add friend by email'),
      icon: Icons.person_add_alt_1_rounded,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: AppPreferences.tr(
                  'Nhập email người muốn kết bạn',
                  'Enter email of person to friend',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _sending ? null : _sendRequest,
            child: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppPreferences.tr('Gửi', 'Send')),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestsCard() {
    return _sectionCard(
      title: AppPreferences.tr('Lời mời đang chờ', 'Pending requests'),
      icon: Icons.mark_email_unread_outlined,
      child: _incomingRequests.isEmpty
          ? Text(AppPreferences.tr('Không có lời mời nào.', 'No requests.'))
          : Column(
              children: _incomingRequests.map((request) {
                final display =
                    request.senderDisplayName ?? request.senderEmail;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(display),
                  subtitle: Text(request.senderEmail),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      OutlinedButton(
                        onPressed: () => _respond(request, false),
                        child: Text(AppPreferences.tr('Từ chối', 'Decline')),
                      ),
                      ElevatedButton(
                        onPressed: () => _respond(request, true),
                        child: Text(AppPreferences.tr('Chấp nhận', 'Accept')),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildFriendsCard() {
    return _sectionCard(
      title: AppPreferences.tr('Danh sách bạn bè', 'Friends List'),
      icon: Icons.group_outlined,
      child: _friends.isEmpty
          ? Text(
              AppPreferences.tr(
                'Bạn chưa có bạn bè nào.',
                'You have no friends yet.',
              ),
            )
          : Column(
              children: _friends.map((friend) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FriendProfileScreen(friend: friend),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withOpacity(0.2),
                    backgroundImage: friend.avatarUrl != null
                        ? NetworkImage(friend.avatarUrl!)
                        : null,
                    child: friend.avatarUrl == null
                        ? Text(
                            (friend.displayName ?? friend.email)
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text(friend.displayName ?? friend.email),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(friend.email),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _buildStatusText(friend),
                            style: TextStyle(
                              fontSize: 12,
                              color: friend.isOnline
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            friend.isOnline
                                ? Icons.circle
                                : Icons.schedule_rounded,
                            size: 12,
                            color: friend.isOnline
                                ? Colors.green.shade600
                                : Colors.grey.shade500,
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    tooltip: AppPreferences.tr('Chat', 'Chat'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(friend: friend),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
    );
  }

  String _buildStatusText(FriendUser friend) {
    if (friend.isOnline) return AppPreferences.tr('Đang trực tuyến', 'Online');
    final lastSeen = friend.lastSeenAt;
    if (lastSeen == null) return AppPreferences.tr('Ngoại tuyến', 'Offline');

    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1)
      return AppPreferences.tr('Vừa hoạt động', 'Just active');
    if (diff.inMinutes < 60)
      return AppPreferences.tr(
        'Hoạt động ${diff.inMinutes} phút trước',
        'Active ${diff.inMinutes} minutes ago',
      );
    if (diff.inHours < 24)
      return AppPreferences.tr(
        'Hoạt động ${diff.inHours} giờ trước',
        'Active ${diff.inHours} hours ago',
      );
    return AppPreferences.tr(
      'Hoạt động ${diff.inDays} ngày trước',
      'Active ${diff.inDays} days ago',
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
