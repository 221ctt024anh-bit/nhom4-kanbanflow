import 'dart:async';
import 'package:flutter/material.dart';
import '../../app_preferences.dart';
import '../../injection_container.dart';
import '../../data/repositories/friend_repository.dart';
import '../../domain/entities/friend_request.dart';
import '../../domain/entities/friend_user.dart';
import '../widgets/user_avatar.dart';
import 'friend_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _repo = sl<FriendRepository>();
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
    if (_friends.isEmpty && _incomingRequests.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final results = await Future.wait([
        _repo.getFriends(),
        _repo.getIncomingRequests(),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0] as List<FriendUser>;
        _incomingRequests = results[1] as List<FriendRequest>;
        _loading = false;
      });
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('SocketException') ||
          errorMessage.contains('ClientException') ||
          errorMessage.contains('Connection reset by peer')) {
        errorMessage = AppPreferences.tr(
          'Lỗi kết nối mạng. Vui lòng kiểm tra lại internet.',
          'Network connection error. Please check your internet.',
        );
      } else {
        errorMessage =
            '${AppPreferences.tr('Không tải được dữ liệu bạn bè', 'Failed to load friends')}: $e';
      }

      _showSnack(errorMessage);
      if (mounted) setState(() => _loading = false);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.blueAccent;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          AppPreferences.tr('Bạn bè', 'Friends'),
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1E293B),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: Icon(Icons.refresh_rounded, color: themeColor),
            tooltip: AppPreferences.tr('Làm mới', 'Refresh'),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(themeColor),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              color: themeColor,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSendRequestCard(themeColor),
                  const SizedBox(height: 24),
                  if (_incomingRequests.isNotEmpty) ...[
                    _buildIncomingRequestsSection(themeColor),
                    const SizedBox(height: 24),
                  ],
                  _buildFriendsSection(themeColor),
                ],
              ),
            ),
    );
  }

  Widget _buildSendRequestCard(Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: themeColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: themeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                AppPreferences.tr('Thêm bạn mới', 'Add New Friend'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: AppPreferences.tr('Nhập email', 'Enter email'),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _sending ? null : _sendRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        AppPreferences.tr('Gửi', 'Send'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestsSection(Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Text(
                AppPreferences.tr('Lời mời đang chờ', 'Pending requests'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_incomingRequests.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _incomingRequests.length,
          itemBuilder: (context, index) {
            final request = _incomingRequests[index];
            final displayName =
                request.senderDisplayName ?? request.senderEmail;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  UserAvatar(userId: request.senderId, radius: 24),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          request.senderEmail,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRequestActionButton(
                        icon: Icons.close_rounded,
                        color: Colors.redAccent,
                        onPressed: () => _respond(request, false),
                      ),
                      const SizedBox(width: 10),
                      _buildRequestActionButton(
                        icon: Icons.check_rounded,
                        color: Colors.green,
                        onPressed: () => _respond(request, true),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRequestActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildFriendsSection(Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            AppPreferences.tr('Danh sách bạn bè', 'Friends List'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        if (_friends.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(Icons.group_outlined, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  AppPreferences.tr(
                    'Bạn chưa có bạn bè nào.',
                    'You have no friends yet.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _friends.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                indent: 80,
                endIndent: 20,
                color: Colors.grey.withOpacity(0.1),
              ),
              itemBuilder: (context, index) {
                final friend = _friends[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FriendProfileScreen(friend: friend),
                      ),
                    );
                    if (result == true) {
                      _refresh();
                    }
                  },
                  leading: Stack(
                    children: [
                      UserAvatar(userId: friend.id, radius: 26),
                      if (friend.isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    friend.displayName ?? friend.email,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: Text(
                    _buildStatusText(friend),
                    style: TextStyle(
                      fontSize: 12,
                      color: friend.isOnline ? Colors.green : Colors.grey[500],
                      fontWeight: friend.isOnline ? FontWeight.w600 : null,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
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
}
