import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../domain/entities/task.dart';
import '../../../app_preferences.dart';
import 'task_details_utils.dart';

class TaskDescription extends StatelessWidget {
  final Task task;
  final String? role;
  final Color accentColor;
  final bool isEditing;
  final bool isSaving;
  final bool showSuccessHighlight;
  final bool showSavedIndicator;
  final TextEditingController descriptionController;
  final VoidCallback onToggleEdit;
  final VoidCallback onSave;
  final Function(String, {String? endTag}) onInsertMarkdownTag;
  final Function(String) onApplyTemplate;
  final VoidCallback onAIAssist;

  const TaskDescription({
    super.key,
    required this.task,
    required this.role,
    required this.accentColor,
    required this.isEditing,
    required this.isSaving,
    required this.showSuccessHighlight,
    required this.showSavedIndicator,
    required this.descriptionController,
    required this.onToggleEdit,
    required this.onSave,
    required this.onInsertMarkdownTag,
    required this.onApplyTemplate,
    required this.onAIAssist,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskDetailsUtils.buildSectionTitle(
          AppPreferences.tr('MÔ TẢ CHI TIẾT', 'DESCRIPTION'),
          isSaving: isSaving,
          trailing: InkWell(
            onTap: onToggleEdit,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isEditing
                    ? Colors.red.withOpacity(0.08)
                    : accentColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isEditing ? Icons.close_rounded : Icons.edit_note_rounded,
                    size: 16,
                    color: isEditing ? Colors.redAccent : accentColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isEditing
                        ? AppPreferences.tr('Hủy', 'Cancel')
                        : AppPreferences.tr('Sửa', 'Edit'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isEditing ? Colors.redAccent : accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isEditing ? _buildEditor() : _buildViewer(),
        ),
      ],
    );
  }

  Widget _buildViewer() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0, end: showSuccessHighlight ? 1 : 0),
      builder: (context, value, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Color.lerp(
              Colors.white,
              accentColor.withOpacity(0.05),
              value,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color.lerp(
                Colors.transparent,
                accentColor.withOpacity(0.2),
                value,
              )!,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        );
      },
      child: task.description.isEmpty
          ? Center(
              child: Column(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 48,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppPreferences.tr('Chưa có mô tả', 'No description yet'),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (role != 'viewer')
                    TextButton.icon(
                      onPressed: onToggleEdit,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        AppPreferences.tr(
                          'Thêm mô tả ngay',
                          'Add description now',
                        ),
                      ),
                    ),
                ],
              ),
            )
          : MarkdownBody(
              data: task.description,
              selectable: true,
              onTapLink: (text, href, title) {
                if (href != null) {
                  launchUrl(Uri.parse(href));
                }
              },
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Color(0xFF334155),
                ),
                a: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
                h3: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  height: 2,
                ),
                listBullet: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF334155),
                ),
              ),
            ),
    );
  }

  Widget _buildEditor() {
    return Column(
      children: [
        _buildToolbar(),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.05),
                blurRadius: 20,
              ),
            ],
          ),
          child: TextField(
            controller: descriptionController,
            maxLines: 12,
            minLines: 6,
            style: const TextStyle(fontSize: 15, height: 1.6),
            decoration: InputDecoration(
              hintText: AppPreferences.tr(
                'Bắt đầu viết mô tả...',
                'Start writing description...',
              ),
              contentPadding: const EdgeInsets.all(20),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (descriptionController.text.length > 500)
              Text(
                '${descriptionController.text.length}/2000',
                style: TextStyle(
                  fontSize: 12,
                  color: descriptionController.text.length > 1800
                      ? Colors.red
                      : Colors.grey,
                ),
              ),
            const Spacer(),
            if (showSavedIndicator)
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppPreferences.tr('Đã lưu', 'Saved'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: isSaving ? null : onSave,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text(AppPreferences.tr('Lưu thay đổi', 'Save changes')),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _toolbarButton(
            Icons.format_bold_rounded,
            () => onInsertMarkdownTag('**', endTag: '**'),
          ),
          _toolbarButton(
            Icons.format_italic_rounded,
            () => onInsertMarkdownTag('_', endTag: '_'),
          ),
          _toolbarButton(Icons.title_rounded, () => onInsertMarkdownTag('### ')),
          _toolbarButton(
            Icons.format_list_bulleted_rounded,
            () => onInsertMarkdownTag('- '),
          ),
          _toolbarButton(
            Icons.checklist_rounded,
            () => onInsertMarkdownTag('- [ ] '),
          ),
          _toolbarButton(
            Icons.code_rounded,
            () => onInsertMarkdownTag('`', endTag: '`'),
          ),
          _toolbarButton(
            Icons.link_rounded,
            () => onInsertMarkdownTag('[', endTag: '](url)'),
          ),
          _toolbarButton(Icons.alternate_email, () => onInsertMarkdownTag('@')),
          _toolbarButton(Icons.numbers, () => onInsertMarkdownTag('#TASK-')),
          const SizedBox(width: 8),
          _toolbarButton(
            Icons.auto_awesome,
            onAIAssist,
            color: Colors.purple,
          ),
          const VerticalDivider(width: 24),
          _toolbarButton(
            Icons.bug_report_outlined,
            () => onApplyTemplate('bug'),
            color: Colors.redAccent,
          ),
          _toolbarButton(
            Icons.rocket_launch_outlined,
            () => onApplyTemplate('feature'),
            color: Colors.purpleAccent,
          ),
          _toolbarButton(
            Icons.event_note_rounded,
            () => onApplyTemplate('meeting'),
            color: Colors.blueAccent,
          ),
          _toolbarButton(
            Icons.search_rounded,
            () => onApplyTemplate('research'),
            color: Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color ?? const Color(0xFF64748B)),
      onPressed: onTap,
      tooltip: 'Markdown Shortcut',
    );
  }
}
