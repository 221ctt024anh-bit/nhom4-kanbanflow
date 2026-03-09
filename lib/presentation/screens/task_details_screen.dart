import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../app_preferences.dart';
import '../../injection_container.dart';
import '../../data/repositories/task_interaction_repository.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_attachment.dart';
import '../../domain/entities/task_comment.dart';
import '../../domain/entities/task_rating.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/board_repository.dart';
import '../blocs/task_bloc.dart';
import '../blocs/task_event.dart';
import '../widgets/board_member_select_dialog.dart';
import '../widgets/user_avatar.dart';

class TaskDetailsScreen extends StatefulWidget {
  final Task task;
  final Color accentColor;

  const TaskDetailsScreen({
    super.key,
    required this.task,
    required this.accentColor,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final _repo = sl<TaskInteractionRepository>();
  final _commentController = TextEditingController();

  late Task _currentTask;
  List<TaskComment> _comments = [];
  List<TaskAttachment> _attachments = [];
  bool _loadingComments = true;
  bool _loadingAttachments = true;
  bool _sendingComment = false;
  bool _uploadingAttachment = false;
  bool _loadingRating = true;
  bool _savingRating = false;
  TaskRating? _myRating;
  double _avgRating = 0;
  int _ratingCount = 0;
  List<UserModel> _members = [];
  bool _loadingMembers = true;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    _loadComments();
    _loadAttachments();
    _loadRatings();
    _loadBoardMembers();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final comments = await _repo.getComments(_currentTask.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
      });
    } catch (_) {
      _showSnack(
        AppPreferences.tr(
          'Không tải được bình luận',
          'Failed to load comments',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingComments = false);
      }
    }
  }

  Future<void> _loadAttachments() async {
    setState(() => _loadingAttachments = true);
    try {
      final attachments = await _repo.getAttachments(_currentTask.id);
      if (!mounted) return;
      setState(() {
        _attachments = attachments;
      });
    } catch (_) {
      _showSnack(
        AppPreferences.tr(
          'Không tải được tệp đính kèm',
          'Failed to load attachments',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingAttachments = false);
      }
    }
  }

  Future<void> _loadRatings() async {
    setState(() => _loadingRating = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final stats = await _repo.getRatingStats(_currentTask.id);
      TaskRating? myRating;
      if (userId != null) {
        myRating = await _repo.getMyRating(
          taskId: _currentTask.id,
          userId: userId,
        );
      }
      if (!mounted) return;
      setState(() {
        _avgRating = stats.$1;
        _ratingCount = stats.$2;
        _myRating = myRating;
      });
    } catch (_) {
      _showSnack(
        AppPreferences.tr('Không tải được đánh giá', 'Failed to load ratings'),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingRating = false);
      }
    }
  }

  Future<void> _loadBoardMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final boardRepo = sl<BoardRepository>();
      final members = await boardRepo.getBoardMembers(_currentTask.boardId);
      if (!mounted) return;
      setState(() {
        _members = members;
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) {
        setState(() => _loadingMembers = false);
      }
    }
  }

  Future<void> _addComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnack(
        AppPreferences.tr('Cần đăng nhập để bình luận', 'Login to comment'),
      );
      return;
    }

    setState(() => _sendingComment = true);
    try {
      final comment = await _repo.addComment(
        taskId: _currentTask.id,
        userId: userId,
        content: content,
      );
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, comment];
        _commentController.clear();
      });
    } catch (_) {
      _showSnack(AppPreferences.tr('Gửi bình luận thất bại', 'Comment failed'));
    } finally {
      if (mounted) {
        setState(() => _sendingComment = false);
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppPreferences.tr('Xóa bình luận', 'Delete comment')),
        content: Text(
          AppPreferences.tr(
            'Bạn có chắc chắn muốn xóa bình luận này?',
            'Are you sure you want to delete this comment?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppPreferences.tr('Hủy', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppPreferences.tr('Xóa', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repo.deleteComment(commentId);
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == commentId);
      });
      _showSnack(AppPreferences.tr('Đã xóa bình luận', 'Comment deleted'));
    } catch (_) {
      _showSnack(AppPreferences.tr('Xóa thất bại', 'Delete failed'));
    }
  }

  Future<void> _pickAndUploadAttachment() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnack(
        AppPreferences.tr('Cần đăng nhập để tải tệp', 'Login to upload'),
      );
      return;
    }

    final file = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
    );
    if (file == null || file.files.isEmpty) return;

    final picked = file.files.single;
    final bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showSnack(
        AppPreferences.tr('Không đọc được dữ liệu tệp', 'Invalid file data'),
      );
      return;
    }

    setState(() => _uploadingAttachment = true);
    try {
      final uploaded = await _repo.uploadAttachment(
        boardId: _currentTask.boardId,
        taskId: _currentTask.id,
        fileName: picked.name,
        bytes: bytes,
        uploaderId: userId,
        contentType: lookupMimeType(picked.name),
      );
      if (!mounted) return;
      setState(() {
        _attachments = [uploaded, ..._attachments];
      });
      _showSnack(AppPreferences.tr('Tải tệp thành công', 'File uploaded'));
    } catch (_) {
      _showSnack(AppPreferences.tr('Tải tệp thất bại', 'Upload failed'));
    } finally {
      if (mounted) {
        setState(() => _uploadingAttachment = false);
      }
    }
  }

  Future<void> _openAttachment(TaskAttachment attachment) async {
    final url = Uri.tryParse(attachment.publicUrl);
    if (url == null) {
      _showSnack(
        AppPreferences.tr('Liên kết tệp không hợp lệ', 'Invalid file link'),
      );
      return;
    }
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) {
      _showSnack(AppPreferences.tr('Không mở được tệp', 'Cannot open file'));
    }
  }

  Future<void> _deleteAttachment(TaskAttachment attachment) async {
    try {
      await _repo.deleteAttachment(attachment);
      if (!mounted) return;
      setState(() {
        _attachments = _attachments
            .where((item) => item.id != attachment.id)
            .toList();
      });
      _showSnack(AppPreferences.tr('Đã xóa tệp', 'File deleted'));
    } catch (_) {
      _showSnack(AppPreferences.tr('Xóa tệp thất bại', 'Delete failed'));
    }
  }

  Future<void> _rateTask(int score) async {
    if (score < 1 || score > 5) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _showSnack(
        AppPreferences.tr('Cần đăng nhập để đánh giá', 'Login to rate'),
      );
      return;
    }
    setState(() => _savingRating = true);
    try {
      await _repo.upsertRating(
        taskId: _currentTask.id,
        userId: userId,
        rating: score,
      );
      await _loadRatings();
      _showSnack(AppPreferences.tr('Đã cập nhật đánh giá', 'Rating updated'));
    } catch (_) {
      _showSnack(
        AppPreferences.tr('Cập nhật đánh giá thất bại', 'Rating failed'),
      );
    } finally {
      if (mounted) {
        setState(() => _savingRating = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusLabel(String status) {
    if (status == 'todo') return AppPreferences.tr('Cần làm', 'To Do');
    if (status == 'doing') return AppPreferences.tr('Đang làm', 'Doing');
    return AppPreferences.tr('Hoàn thành', 'Done');
  }

  String _formatDate(String value) {
    var date = DateTime.tryParse(value);
    if (date == null) return value;
    // Đảm bảo chuyển về giờ địa phương nếu chuỗi ISO là UTC
    if (!date.isUtc && value.endsWith('Z')) {
      date = date.toLocal();
    } else if (value.contains('+') || (value.length > 19 && value[19] == '+')) {
      // Offset đã được parse tự động bởi tryParse, nhưng ta vẫn gọi toLocal cho chắc chắn
      date = date.toLocal();
    } else {
      date = date.toLocal();
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _timeAgo(String value) {
    var date = DateTime.tryParse(value);
    if (date == null) return value;
    date = date.toLocal();

    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return AppPreferences.tr('Vừa xong', 'Just now');
    if (diff.inMinutes < 60)
      return AppPreferences.tr(
        '${diff.inMinutes} phút trước',
        '${diff.inMinutes}m ago',
      );
    if (diff.inHours < 24)
      return AppPreferences.tr(
        '${diff.inHours} giờ trước',
        '${diff.inHours}h ago',
      );
    if (diff.inDays < 7)
      return AppPreferences.tr(
        '${diff.inDays} ngày trước',
        '${diff.inDays}d ago',
      );

    return _formatDate(value);
  }

  Widget _buildPriorityPreview() {
    if (_loadingAttachments) return const SizedBox.shrink();
    if (_attachments.isEmpty) return const SizedBox.shrink();

    final imageIndex = _attachments.indexWhere(
      (e) => lookupMimeType(e.fileName)?.startsWith('image/') == true,
    );

    if (imageIndex != -1) {
      final image = _attachments[imageIndex];
      return Container(
        width: double.infinity,
        height: 280,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _openAttachment(image),
                child: Image.network(
                  image.publicUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: () => _openAttachment(image),
                backgroundColor: Colors.white,
                child: const Icon(
                  Icons.fullscreen_rounded,
                  color: Colors.blueAccent,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          AppPreferences.tr('Chi tiết thẻ', 'Task Details'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildPriorityPreview(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentTask.checklist.isNotEmpty) ...[
                    _buildChecklistSection(),
                    const SizedBox(height: 24),
                  ],
                  _buildAssigneeSection(),
                  const SizedBox(height: 24),
                  if (_attachments.isNotEmpty &&
                      !_attachments.any(
                        (e) =>
                            lookupMimeType(e.fileName)?.startsWith('image/') ==
                            true,
                      )) ...[
                    _buildAttachmentsSection(),
                    const SizedBox(height: 24),
                  ],
                  _buildDescriptionSection(),
                  const SizedBox(height: 24),
                  _buildRatingSection(),
                  const SizedBox(height: 24),
                  if (_currentTask.checklist.isEmpty) ...[
                    // Only show if it was hidden above
                  ],
                  if (_attachments.any(
                    (e) =>
                        lookupMimeType(e.fileName)?.startsWith('image/') ==
                        true,
                  )) ...[
                    _buildAttachmentsSection(),
                    const SizedBox(height: 24),
                  ],
                  _buildCommentsSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentTask.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildBadge(
                _statusLabel(_currentTask.status),
                widget.accentColor.withOpacity(0.12),
                widget.accentColor,
              ),
              _buildBadge(
                _formatDate(_currentTask.createdAt),
                Colors.grey.withOpacity(0.08),
                const Color(0xFF64748B),
              ),
              if (_currentTask.dueAt != null)
                _buildBadge(
                  AppPreferences.tr(
                    'Hạn: ${_formatDueAt(_currentTask.dueAt!.toLocal())}',
                    'Due: ${_formatDueAt(_currentTask.dueAt!.toLocal())}',
                  ),
                  Colors.orange.withOpacity(0.12),
                  Colors.orange[800]!,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Widget? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildAssigneeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          AppPreferences.tr('NGƯỜI THỰC HIỆN', 'ASSIGNEES'),
          trailing: TextButton.icon(
            onPressed: () async {
              final selectedUserIds = await showDialog<List<String>>(
                context: context,
                builder: (context) => BoardMemberSelectDialog(
                  boardId: _currentTask.boardId,
                  currentAssigneeIds: _currentTask.assigneeIds,
                ),
              );
              if (selectedUserIds == null) return;

              final updatedTask = Task(
                id: _currentTask.id,
                boardId: _currentTask.boardId,
                title: _currentTask.title,
                description: _currentTask.description,
                status: _currentTask.status,
                creatorId: _currentTask.creatorId,
                createdAt: _currentTask.createdAt,
                assigneeIds: selectedUserIds,
                dueAt: _currentTask.dueAt,
                checklist: _currentTask.checklist,
                hasAttachments: _currentTask.hasAttachments,
                taskType: _currentTask.taskType,
              );

              setState(() => _currentTask = updatedTask);
              if (!mounted) return;
              context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
            },
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text(AppPreferences.tr('Thay đổi', 'Change')),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
          child: _currentTask.assigneeIds.isNotEmpty
              ? Column(
                  children: _currentTask.assigneeIds.map((uid) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          UserAvatar(userId: uid, radius: 20, showName: true),
                          const SizedBox(width: 12),
                          const Spacer(),
                          if (!_loadingMembers) _buildAssigneeRoleChip(uid),
                        ],
                      ),
                    );
                  }).toList(),
                )
              : Text(
                  AppPreferences.tr('Chưa giao cho ai', 'Unassigned'),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAssigneeRoleChip(String userId) {
    if (_members.isEmpty) return const SizedBox.shrink();
    final member = _members.cast<UserModel?>().firstWhere(
      (m) => m?.id == userId,
      orElse: () => null,
    );
    if (member == null || member.role == null) return const SizedBox.shrink();

    final isAdmin = member.role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin
            ? Colors.orange.withOpacity(0.1)
            : Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAdmin
              ? Colors.orange.withOpacity(0.5)
              : Colors.blueAccent.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Text(
        isAdmin
            ? AppPreferences.tr('Quản trị viên', 'Admin')
            : AppPreferences.tr('Thành viên', 'Member'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isAdmin ? Colors.orange[800] : Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(AppPreferences.tr('MÔ TẢ CHI TIẾT', 'DESCRIPTION')),
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
          child: Text(
            _currentTask.description.isEmpty
                ? AppPreferences.tr(
                    'Chưa có mô tả cho task này.',
                    'No description for this task.',
                  )
                : _currentTask.description,
            style: TextStyle(
              fontSize: 15,
              color: _currentTask.description.isEmpty
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF334155),
              fontStyle: _currentTask.description.isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    final myScore = _myRating?.rating ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(AppPreferences.tr('ĐÁNH GIÁ TASK', 'TASK RATING')),
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
          child: _loadingRating
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        final active = star <= myScore;
                        return IconButton(
                          onPressed: _savingRating
                              ? null
                              : () => _rateTask(star),
                          iconSize: 32,
                          icon: Icon(
                            active
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: active
                                ? Colors.amber[600]
                                : const Color(0xFFCBD5E1),
                          ),
                          tooltip: '$star ${AppPreferences.tr('sao', 'stars')}',
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _ratingCount == 0
                          ? AppPreferences.tr(
                              'Chưa có đánh giá',
                              'No ratings yet',
                            )
                          : '${AppPreferences.tr('Trung bình', 'Average')}: ${_avgRating.toStringAsFixed(1)}/5 ($_ratingCount ${AppPreferences.tr('đánh giá', 'ratings')})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildChecklistSection() {
    if (_currentTask.checklist.isEmpty) return const SizedBox.shrink();

    final doneCount = _currentTask.checklist.where((e) => e.isDone).length;
    final totalCount = _currentTask.checklist.length;
    final progress = totalCount == 0 ? 0.0 : doneCount / totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(
              AppPreferences.tr('DANH SÁCH CÔNG VIỆC', 'CHECKLIST'),
            ),
            Text(
              '$doneCount/$totalCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: widget.accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: widget.accentColor.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
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
            children: _currentTask.checklist.map((item) {
              return Theme(
                data: ThemeData(
                  checkboxTheme: CheckboxThemeData(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                child: CheckboxListTile(
                  title: Text(
                    item.title,
                    style: TextStyle(
                      decoration: item.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.isDone
                          ? Colors.grey
                          : const Color(0xFF334155),
                      fontSize: 14,
                      fontWeight: item.isDone
                          ? FontWeight.normal
                          : FontWeight.w500,
                    ),
                  ),
                  value: item.isDone,
                  onChanged: (val) => _toggleChecklistItem(item),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: widget.accentColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  dense: true,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _toggleChecklistItem(ChecklistItem item) {
    final newList = _currentTask.checklist.map((e) {
      if (e.id == item.id) return e.copyWith(isDone: !e.isDone);
      return e;
    }).toList();

    final updatedTask = Task(
      id: _currentTask.id,
      boardId: _currentTask.boardId,
      title: _currentTask.title,
      description: _currentTask.description,
      status: _currentTask.status,
      creatorId: _currentTask.creatorId,
      createdAt: _currentTask.createdAt,
      assigneeIds: _currentTask.assigneeIds,
      dueAt: _currentTask.dueAt,
      checklist: newList,
    );

    setState(() => _currentTask = updatedTask);
    context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          AppPreferences.tr('TỆP ĐÍNH KÈM', 'ATTACHMENTS'),
          trailing: TextButton.icon(
            onPressed: _uploadingAttachment ? null : _pickAndUploadAttachment,
            icon: _uploadingAttachment
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline, size: 16),
            label: Text(AppPreferences.tr('Thêm tệp', 'Add file')),
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingAttachments)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_attachments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
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
            child: Center(
              child: Text(
                AppPreferences.tr('Chưa có tệp đính kèm', 'No attachments yet'),
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: _attachments.length,
            itemBuilder: (context, index) {
              final item = _attachments[index];
              final isImage =
                  lookupMimeType(item.fileName)?.startsWith('image/') == true;
              final isAudio =
                  lookupMimeType(item.fileName)?.startsWith('audio/') == true;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openAttachment(item),
                  child: Stack(
                    children: [
                      if (isImage)
                        Positioned.fill(
                          child: Image.network(
                            item.publicUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF1F5F9),
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned.fill(
                          child: Container(
                            color: const Color(0xFFF1F5F9),
                            child: Icon(
                              isAudio
                                  ? Icons.mic_rounded
                                  : Icons.insert_drive_file_outlined,
                              size: 32,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.fileName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                onPressed: () => _deleteAttachment(item),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(AppPreferences.tr('BÌNH LUẬN', 'COMMENTS')),
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
              if (_loadingComments)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_comments.isEmpty)
                Padding(
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
                )
              else
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final item = _comments[index];
                    return _buildGitHubCommentItem(item);
                  },
                ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Row(
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
                        controller: _commentController,
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
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendingComment ? null : _addComment,
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.accentColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _sendingComment
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGitHubCommentItem(TaskComment item) {
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
                                    'đã bình luận ${_timeAgo(item.createdAt)}',
                                    'commented ${_timeAgo(item.createdAt)}',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF636C76),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (item.userId ==
                              Supabase.instance.client.auth.currentUser?.id)
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.more_horiz,
                                size: 18,
                                color: Color(0xFF636C76),
                              ),
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _deleteComment(item.id);
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

  String _formatDueAt(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
