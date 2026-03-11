import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_preferences.dart';
import '../../injection_container.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/task_attachment.dart';
import '../../domain/entities/task_comment.dart';
import '../../domain/repositories/task_repository.dart';
import '../../data/repositories/task_interaction_repository.dart';

import 'task_details/task_header.dart';
import 'task_details/task_description.dart';
import 'task_details/task_checklist.dart';
import 'task_details/task_attachments.dart';
import 'task_details/task_comments.dart';

class WebTaskViewScreen extends StatefulWidget {
  final String taskId;

  const WebTaskViewScreen({super.key, required this.taskId});

  @override
  State<WebTaskViewScreen> createState() => _WebTaskViewScreenState();
}

class _WebTaskViewScreenState extends State<WebTaskViewScreen> {
  Task? _task;
  bool _loading = true;
  String? _error;
  
  List<TaskAttachment> _attachments = [];
  bool _loadingAttachments = false;
  
  List<TaskComment> _comments = [];
  bool _loadingComments = false;

  final _repo = sl<TaskInteractionRepository>();
  final _taskRepo = sl<TaskRepository>();

  @override
  void initState() {
    super.initState();
    _loadTaskData();
  }

  Future<void> _loadTaskData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final task = await _taskRepo.getTaskById(widget.taskId);
      if (task == null) {
        setState(() {
          _loading = false;
          _error = AppPreferences.tr('Không tìm thấy công việc', 'Task not found');
        });
        return;
      }

      setState(() {
        _task = task;
        _loading = false;
      });

      // Load additional data
      _loadAttachments();
      _loadComments();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadAttachments() async {
    setState(() => _loadingAttachments = true);
    try {
      final attachments = await _repo.getAttachments(widget.taskId);
      setState(() => _attachments = attachments);
    } catch (_) {}
    setState(() => _loadingAttachments = false);
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final comments = await _repo.getComments(widget.taskId);
      setState(() => _comments = comments);
    } catch (_) {}
    setState(() => _loadingComments = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadTaskData,
                child: Text(AppPreferences.tr('Thử lại', 'Retry')),
              ),
            ],
          ),
        ),
      );
    }

    final task = _task!;
    const accentColor = Colors.blueAccent;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(task.title),
        actions: [
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse('https://kanbanflow-nhom4.web.app')),
            icon: const Icon(Icons.launch, size: 18),
            label: Text(AppPreferences.tr('Mở App', 'Open App')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Main Info
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TaskHeader(task: task, accentColor: accentColor),
                      const SizedBox(height: 24),
                      PriorityPreview(
                        attachments: _attachments,
                        loading: _loadingAttachments,
                        onOpen: (a) => launchUrl(Uri.parse(a.publicUrl)),
                      ),
                      const SizedBox(height: 24),
                      TaskDescription(
                        task: task,
                        role: 'viewer', // Read-only
                        accentColor: accentColor,
                        isEditing: false,
                        isSaving: false,
                        showSuccessHighlight: false,
                        showSavedIndicator: false,
                        descriptionController: TextEditingController(text: task.description),
                        onToggleEdit: () {},
                        onSave: () {},
                        onInsertMarkdownTag: (_, {String? endTag}) {},
                        onApplyTemplate: (template) {},
                        onAIAssist: () {},
                      ),
                      const SizedBox(height: 24),
                      TaskChecklist(
                        task: task,
                        role: 'viewer', // Read-only
                        accentColor: accentColor,
                        onToggleItem: (item) {},
                      ),
                    ],
                  ),
                ),
              ),
              // Right Column: Side Info (Attachments & Comments)
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(left: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        TaskAttachments(
                          attachments: _attachments,
                          role: 'viewer',
                          loading: _loadingAttachments,
                          uploading: false,
                          onPickAndUpload: () {},
                          onOpen: (a) => launchUrl(Uri.parse(a.publicUrl)),
                          onDelete: (a) {},
                        ),
                        const SizedBox(height: 32),
                        TaskComments(
                          comments: _comments,
                          loading: _loadingComments,
                          sending: false,
                          role: 'viewer',
                          commentController: TextEditingController(),
                          onAdd: () {},
                          onDelete: (c) {},
                          accentColor: accentColor,
                        ),
                      ],
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
}
