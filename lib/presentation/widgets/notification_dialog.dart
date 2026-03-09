import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_preferences.dart';
import '../../domain/entities/app_notification.dart';
import '../../data/repositories/notification_repository.dart';
import 'user_avatar.dart';

class NotificationDialog extends StatefulWidget {
  final List<AppNotification> notifications;
  final VoidCallback onRefresh;
  final NotificationRepository repository;

  const NotificationDialog({
    super.key,
    required this.notifications,
    required this.onRefresh,
    required this.repository,
  });

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  String _timeAgo(String value) {
    try {
      final dt = DateTime.parse(value).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return AppPreferences.tr('Vừa xong', 'Just now');
      if (diff.inMinutes < 60) {
        return AppPreferences.tr(
          '${diff.inMinutes} phút trước',
          '${diff.inMinutes}m ago',
        );
      }
      if (diff.inHours < 24) {
        return AppPreferences.tr(
          '${diff.inHours} giờ trước',
          '${diff.inHours}h ago',
        );
      }
      if (diff.inDays < 7) {
        return AppPreferences.tr(
          '${diff.inDays} ngày trước',
          '${diff.inDays}d ago',
        );
      }
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }

  Future<void> _markRead(String id) async {
    await widget.repository.markAsRead(id);
    widget.onRefresh();
  }

  Future<void> _markAllRead() async {
    setState(() => _markingAll = true);
    await widget.repository.markAllAsRead();
    widget.onRefresh();
    if (mounted) setState(() => _markingAll = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Colors.blueAccent;
    final hasUnread = widget.notifications.any((n) => !n.isRead);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeController,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        color: themeColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        AppPreferences.tr('Thông báo', 'Notifications'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    if (hasUnread)
                      TextButton(
                        onPressed: _markingAll ? null : _markAllRead,
                        style: TextButton.styleFrom(
                          foregroundColor: themeColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _markingAll
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                AppPreferences.tr('Đọc tất cả', 'Read all'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content
              Flexible(
                child: widget.notifications.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shrinkWrap: true,
                        itemCount: widget.notifications.length,
                        itemBuilder: (context, index) {
                          final item = widget.notifications[index];
                          return _NotificationItem(
                            notification: item,
                            timeAgo: _timeAgo(item.createdAt),
                            onTap: () => _markRead(item.id),
                          );
                        },
                      ),
              ),

              const Divider(height: 1),
              // Footer
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF475569),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      AppPreferences.tr('Đóng', 'Close'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppPreferences.tr('Chưa có thông báo nào', 'No notifications yet'),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppPreferences.tr(
              'Chúng tôi sẽ thông báo cho bạn khi có cập nhật mới.',
              'We will notify you when there are new updates.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final AppNotification notification;
  final String timeAgo;
  final VoidCallback onTap;

  const _NotificationItem({
    required this.notification,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final themeColor = Colors.blueAccent;

    return InkWell(
      onTap: isUnread ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isUnread ? themeColor.withOpacity(0.03) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon or Avatar
            _buildLeading(themeColor),
            const SizedBox(width: 16),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isUnread
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isUnread
                                ? const Color(0xFF1E293B)
                                : const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: isUnread ? themeColor : Colors.grey[400],
                          fontWeight: isUnread
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: isUnread
                          ? const Color(0xFF334155)
                          : const Color(0xFF94A3B8),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 12),
              Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: themeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withOpacity(0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeading(Color themeColor) {
    if (notification.senderId != null) {
      return UserAvatar(userId: notification.senderId!, radius: 20);
    }

    IconData iconData = Icons.info_outline_rounded;
    Color iconColor = themeColor;

    if (notification.title.contains('Nhiệm vụ') ||
        notification.title.toLowerCase().contains('task')) {
      iconData = Icons.assignment_turned_in_rounded;
      iconColor = Colors.orange;
    } else if (notification.title.contains('Tin nhắn') ||
        notification.title.toLowerCase().contains('message')) {
      iconData = Icons.chat_bubble_rounded;
      iconColor = Colors.green;
    } else if (notification.title.contains('bình luận') ||
        notification.title.toLowerCase().contains('comment')) {
      iconData = Icons.insert_comment_rounded;
      iconColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }
}
