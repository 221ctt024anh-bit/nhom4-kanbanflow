import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/entities/task_comment.dart';
import '../../../app_preferences.dart';
import '../../widgets/user_avatar.dart';
import 'task_details_utils.dart';

class TaskComments extends StatelessWidget {
  final List<TaskComment> comments;
  final bool loading;
  final bool sending;
  final String? role;
  final TextEditingController commentController;
  final VoidCallback onAdd;
  final Function(String) onDelete;
  final Color accentColor;

  const TaskComments({
    super.key,
    required this.comments,
    required this.loading,
    required this.sending,
    required this.role,
    required this.commentController,
    required this.onAdd,
    required this.onDelete,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskDetailsUtils.buildSectionTitle(AppPreferences.tr('BÌNH LUẬN', 'COMMENTS')),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (comments.isEmpty)
                _buildEmptyState()
              else
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final item = comments[index];
                    return _buildCommentItem(item, context);
                  },
                ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              _buildInputArea(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FA),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD0D7DE)),
            ),
            child: const Icon(
              Icons.mode_comment_outlined,
              size: 32,
              color: Color(0xFF636C76),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppPreferences.tr(
              'Chưa có thảo luận nào.',
              'No discussions yet.',
            ),
            style: const TextStyle(
              color: Color(0xFF1F2328),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppPreferences.tr(
              'Hãy bắt đầu cuộc hội thoại ngay bây giờ!',
              'Start the conversation now!',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF636C76),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: commentController,
              minLines: 2,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: AppPreferences.tr(
                  'Viết bình luận (Hỗ trợ Markdown)...',
                  'Write a comment (Markdown supported)...',
                ),
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              style: const TextStyle(fontSize: 14, height: 1.5),
              enabled: role != 'viewer',
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: (role == 'viewer' || sending) ? null : onAdd,
          child: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: sending
                ? const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentItem(TaskComment item, BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isMyComment = item.userId == currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UserAvatar(userId: item.userId, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFD0D7DE)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF6F8FA),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(7),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFD0D7DE)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                UserAvatar(
                                  userId: item.userId,
                                  radius: 10,
                                  showName: true,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  AppPreferences.tr(
                                    'đã bình luận ${TaskDetailsUtils.timeAgo(item.createdAt)}',
                                    'commented ${TaskDetailsUtils.timeAgo(item.createdAt)}',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF636C76),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isMyComment)
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.more_horiz,
                                size: 18,
                                color: Color(0xFF636C76),
                              ),
                              onSelected: (value) {
                                if (value == 'delete') {
                                  onDelete(item.id);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        AppPreferences.tr('Xóa', 'Delete'),
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: MarkdownBody(
                        data: item.content,
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1F2328),
                            height: 1.5,
                          ),
                          code: TextStyle(
                            backgroundColor: Colors.grey[100],
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: const Color(0xFFF6F8FA),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFD0D7DE)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
