import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

import 'task_details/task_header.dart';
import 'task_details/task_assignees.dart';
import 'task_details/task_description.dart';
import 'task_details/task_checklist.dart';
import 'task_details/task_attachments.dart';
import 'task_details/task_ratings.dart';
import 'task_details/task_comments.dart';
import '../../core/services/ai_service.dart';

class TaskDetailsScreen extends StatefulWidget {
  final Task task;
  final Color accentColor;
  final String? role;

  const TaskDetailsScreen({
    super.key,
    required this.task,
    required this.accentColor,
    this.role,
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

  bool _isEditingDescription = false;
  late TextEditingController _descriptionController;
  bool _isSavingDescription = false;
  Timer? _debounceTimer;
  bool _showSuccessHighlight = false;
  bool _showSavedIndicator = false;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    _descriptionController = TextEditingController(
      text: _currentTask.description,
    );
    _descriptionController.addListener(_onDescriptionChanged);
    _loadComments();
    _loadAttachments();
    _loadRatings();
    _loadBoardMembers();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _descriptionController.dispose();
    _debounceTimer?.cancel();
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

  void _toggleEditDescription() {
    if (widget.role == 'viewer') {
      _showSnack(
        AppPreferences.tr(
          "Bạn không có quyền chỉnh sửa",
          "You don't have permission to edit",
        ),
      );
      return;
    }
    setState(() {
      _isEditingDescription = !_isEditingDescription;
      if (!_isEditingDescription) {
        _descriptionController.text =
            _currentTask.description; // Reset if cancel
      }
    });
  }

  void _onDescriptionChanged() {
    if (!_isEditingDescription) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      if (_isEditingDescription) {
        _autoSaveDescription();
      }
    });
  }

  Future<void> _autoSaveDescription() async {
    final newDesc = _descriptionController.text.trim();
    if (newDesc == _currentTask.description) return;

    setState(() => _isSavingDescription = true);
    final updatedTask = _currentTask.copyWith(
      description: newDesc,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    try {
      context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
      setState(() {
        _currentTask = updatedTask;
        _showSavedIndicator = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showSavedIndicator = false);
      });
    } catch (_) {
      // Ignore auto-save error to avoid annoying user
    } finally {
      if (mounted) {
        setState(() => _isSavingDescription = false);
      }
    }
  }

  Future<void> _saveDescription() async {
    _debounceTimer?.cancel();
    final newDesc = _descriptionController.text.trim();
    setState(() => _isSavingDescription = true);

    final updatedTask = _currentTask.copyWith(
      description: newDesc,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    try {
      context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
      setState(() {
        _currentTask = updatedTask;
        _isEditingDescription = false;
        _showSuccessHighlight = true;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showSuccessHighlight = false);
      });

      _showSnack(AppPreferences.tr('Đã lưu mô tả', 'Description saved'));
    } catch (_) {
      _showSnack(AppPreferences.tr('Lưu thất bại', 'Save failed'));
    } finally {
      if (mounted) {
        setState(() => _isSavingDescription = false);
      }
    }
  }

  void _insertMarkdownTag(String tag, {String? endTag}) {
    final text = _descriptionController.text;
    final selection = _descriptionController.selection;
    final selectedText = selection.textInside(text);

    String newText;
    if (endTag != null) {
      newText = text.replaceRange(
        selection.start,
        selection.end,
        '$tag$selectedText$endTag',
      );
    } else {
      newText = text.replaceRange(
        selection.start,
        selection.end,
        '$tag$selectedText',
      );
    }

    _descriptionController.text = newText;
    _descriptionController.selection = TextSelection.collapsed(
      offset: selection.start + tag.length + selectedText.length,
    );
  }

  void _applyTemplate(String type) {
    String template = '';
    switch (type) {
      case 'bug':
        template = '''### 🐞 Bug Report
**Description:** 
**Steps to Reproduce:**
1. 
2. 
**Actual Result:**
**Expected Result:**
**Device/OS:**''';
        break;
      case 'feature':
        template = '''### 🚀 Feature Request
**Objective:** 
**Requirements:**
- [ ] 
- [ ] 
**User Story:**''';
        break;
      case 'meeting':
        template = '''### 📅 Meeting Notes
**Attendees:** 
**Agenda:**
- 
**Key Decisions:**
- 
**Action Items:**
- [ ] ''';
        break;
      case 'research':
        template = '''### 🔍 Research Study
**Topic:** 
**Goals:**
**Findings:**
**References:**''';
        break;
    }

    if (_descriptionController.text.isNotEmpty) {
      _descriptionController.text += '\\n\\n$template';
    } else {
      _descriptionController.text = template;
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
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: AppPreferences.tr('Mở trên Web', 'Open on Web'),
            onPressed: _showShareTaskDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            TaskHeader(
              task: _currentTask,
              accentColor: widget.accentColor,
            ),
            PriorityPreview(
              attachments: _attachments,
              loading: _loadingAttachments,
              onOpen: _openAttachment,
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TaskChecklist(
                    task: _currentTask,
                    role: widget.role,
                    accentColor: widget.accentColor,
                    onToggleItem: _toggleChecklistItem,
                    onEditItem: _editChecklistItem,
                    onDeleteItem: _deleteChecklistItem,
                  ),
                  const SizedBox(height: 24),
                  TaskAssignees(
                    task: _currentTask,
                    role: widget.role,
                    loadingMembers: _loadingMembers,
                    members: _members,
                    onEditAssignees: () async {
                      final selectedUserIds = await showDialog<List<String>>(
                        context: context,
                        builder: (context) => BoardMemberSelectDialog(
                          boardId: _currentTask.boardId,
                          currentAssigneeIds: _currentTask.assigneeIds,
                        ),
                      );
                      if (selectedUserIds == null) return;

                      final updatedTask = _currentTask.copyWith(
                        assigneeIds: selectedUserIds,
                      );

                      setState(() => _currentTask = updatedTask);
                      if (!mounted) return;
                      context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
                    },
                  ),
                  const SizedBox(height: 24),
                  TaskAttachments(
                    attachments: _attachments,
                    role: widget.role,
                    loading: _loadingAttachments,
                    uploading: _uploadingAttachment,
                    onPickAndUpload: _pickAndUploadAttachment,
                    onOpen: _openAttachment,
                    onDelete: _deleteAttachment,
                  ),
                  const SizedBox(height: 24),
                  TaskDescription(
                    task: _currentTask,
                    role: widget.role,
                    accentColor: widget.accentColor,
                    isEditing: _isEditingDescription,
                    isSaving: _isSavingDescription,
                    showSuccessHighlight: _showSuccessHighlight,
                    showSavedIndicator: _showSavedIndicator,
                    descriptionController: _descriptionController,
                    onToggleEdit: _toggleEditDescription,
                    onSave: _saveDescription,
                    onInsertMarkdownTag: _insertMarkdownTag,
                    onApplyTemplate: _applyTemplate,
                    onAIAssist: _showAIAssistSheet,
                  ),
                  const SizedBox(height: 24),
                  TaskRatings(
                    myRating: _myRating,
                    loading: _loadingRating,
                    saving: _savingRating,
                    avgRating: _avgRating,
                    ratingCount: _ratingCount,
                    onRate: _rateTask,
                  ),
                  const SizedBox(height: 24),
                  TaskComments(
                    comments: _comments,
                    loading: _loadingComments,
                    sending: _sendingComment,
                    role: widget.role,
                    commentController: _commentController,
                    onAdd: _addComment,
                    onDelete: _deleteComment,
                    accentColor: widget.accentColor,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleChecklistItem(ChecklistItem item) {
    if (widget.role == 'viewer') {
      _showSnack(
        AppPreferences.tr(
          'Bạn không có quyền chỉnh sửa',
          'You do not have permission to edit',
        ),
      );
      return;
    }
    final newList = _currentTask.checklist.map((e) {
      if (e.id == item.id) return e.copyWith(isDone: !e.isDone);
      return e;
    }).toList();

    final updatedTask = _currentTask.copyWith(checklist: newList);

    setState(() => _currentTask = updatedTask);
    context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
  }

  void _editChecklistItem(ChecklistItem item) async {
    if (widget.role == 'viewer') return;
    final controller = TextEditingController(text: item.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppPreferences.tr('Sửa công việc', 'Edit Task')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppPreferences.tr('Nhập tên công việc...', 'Enter task name...'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppPreferences.tr('Hủy', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(AppPreferences.tr('Lưu', 'Save')),
          ),
        ],
      ),
    );

    if (newTitle == null || newTitle.trim().isEmpty || newTitle == item.title) return;

    final newList = _currentTask.checklist.map((e) {
      if (e.id == item.id) return e.copyWith(title: newTitle.trim());
      return e;
    }).toList();

    final updatedTask = _currentTask.copyWith(checklist: newList);
    setState(() => _currentTask = updatedTask);
    context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
  }

  void _deleteChecklistItem(ChecklistItem item) {
    if (widget.role == 'viewer') return;
    final newList = _currentTask.checklist.where((e) => e.id != item.id).toList();
    final updatedTask = _currentTask.copyWith(checklist: newList);
    setState(() => _currentTask = updatedTask);
    context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
  }

  void _showAIAssistSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  AppPreferences.tr('Trợ lý AI', 'AI Assistant'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildAIAction(
              Icons.auto_fix_high,
              AppPreferences.tr('Viết lại rõ ràng hơn', 'Rephrase clearly'),
              () => _runAIAssist('polish'),
            ),
            _buildAIAction(
              Icons.checklist_rtl,
              AppPreferences.tr('Tạo checklist từ mô tả', 'Generate checklist'),
              () => _runAIAssist('checklist'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIAction(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: widget.accentColor),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _runAIAssist(String type) async {
    final aiService = sl<AiService>();
    final originalText = _descriptionController.text;
    
    if (originalText.trim().isEmpty) {
      _showSnack(AppPreferences.tr('Vui lòng nhập mô tả trước!', 'Please enter a description first!'));
      return;
    }

    setState(() => _isSavingDescription = true);

    try {
      if (type == 'polish') {
        final polished = await aiService.polishText(
          text: originalText,
          title: _currentTask.title,
          checklistItems: _currentTask.checklist.map((e) => e.title).toList(),
        );
        if (!mounted) return;
        _descriptionController.text = polished;
        _showSnack(AppPreferences.tr('AI đã tối ưu hóa mô tả!', 'AI polished the description!'));
      } else if (type == 'checklist') {
        final items = await aiService.generateChecklist(originalText);
        if (!mounted) return;
        
        if (items.isEmpty) {
          _showSnack(AppPreferences.tr('AI không tìm thấy đầu mục nào.', 'AI found no checklist items.'));
        } else {
          // Add generated items to current task checklist
          final currentItems = List<ChecklistItem>.from(_currentTask.checklist);
          final newItems = items.map((e) => ChecklistItem(
            id: DateTime.now().millisecondsSinceEpoch.toString() + e.hashCode.toString(),
            title: e,
            isDone: false,
          )).toList();
          
          final updatedTask = _currentTask.copyWith(
            checklist: [...currentItems, ...newItems],
          );
          
          setState(() => _currentTask = updatedTask);
          context.read<TaskBloc>().add(UpdateTaskEvent(updatedTask));
          _showSnack(AppPreferences.tr('AI đã tạo ${items.length} đầu mục!', 'AI generated ${items.length} items!'));
        }
      }
    } catch (e) {
      _showSnack(AppPreferences.tr('Lỗi AI: $e', 'AI Error: $e'));
    } finally {
      if (mounted) {
        setState(() => _isSavingDescription = false);
      }
    }
  }

  void _showShareTaskDialog() {
    // URL for the deployed web app on Netlify
    const baseUrl = "https://capable-gelato-8b83e8.netlify.app/task/";
    final taskUrl = "$baseUrl${_currentTask.id}";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(
          child: Text(
            AppPreferences.tr('Mở trên màn hình lớn', 'Open on Large Screen'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: QrImageView(
                data: taskUrl,
                version: QrVersions.auto,
                size: 200.0,
                gapless: false,
                embeddedImage: const AssetImage('assets/app_icon.png'),
                embeddedImageStyle: const QrEmbeddedImageStyle(
                  size: Size(40, 40),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppPreferences.tr(
                'Quét mã để xem chi tiết trên Web',
                'Scan to view details on Web',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Share.share(
                AppPreferences.tr(
                  'Xem task này trên Web: $taskUrl',
                  'View this task on Web: $taskUrl',
                ),
              ),
              icon: const Icon(Icons.share, size: 18),
              label: Text(AppPreferences.tr('Chia sẻ link', 'Share link')),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppPreferences.tr('Đóng', 'Close')),
          ),
        ],
      ),
    );
  }
}
