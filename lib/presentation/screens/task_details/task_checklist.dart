import 'package:flutter/material.dart';
import '../../../domain/entities/task.dart';
import '../../../app_preferences.dart';
import 'task_details_utils.dart';

class TaskChecklist extends StatelessWidget {
  final Task task;
  final String? role;
  final Color accentColor;
  final Function(ChecklistItem) onToggleItem;
  final Function(ChecklistItem)? onEditItem;
  final Function(ChecklistItem)? onDeleteItem;

  const TaskChecklist({
    super.key,
    required this.task,
    required this.role,
    required this.accentColor,
    required this.onToggleItem,
    this.onEditItem,
    this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context) {
    if (task.checklist.isEmpty) return const SizedBox.shrink();

    final doneCount = task.checklist.where((e) => e.isDone).length;
    final totalCount = task.checklist.length;
    final progress = totalCount == 0 ? 0.0 : doneCount / totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TaskDetailsUtils.buildSectionTitle(
              AppPreferences.tr('DANH SÁCH CÔNG VIỆC', 'CHECKLIST'),
            ),
            Text(
              '$doneCount/$totalCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: accentColor.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
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
            children: task.checklist.map((item) {
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
                  onChanged: (val) => onToggleItem(item),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: accentColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  secondary: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEditItem != null)
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade600),
                          onPressed: () => onEditItem!(item),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (onDeleteItem != null)
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.withOpacity(0.7)),
                          onPressed: () => onDeleteItem!(item),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  dense: true,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
