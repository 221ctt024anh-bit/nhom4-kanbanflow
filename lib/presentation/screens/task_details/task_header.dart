import 'package:flutter/material.dart';
import '../../../domain/entities/task.dart';
import '../../../app_preferences.dart';
import 'task_details_utils.dart';

class TaskHeader extends StatelessWidget {
  final Task task;
  final Color accentColor;

  const TaskHeader({
    super.key,
    required this.task,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
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
              TaskDetailsUtils.buildBadge(
                TaskDetailsUtils.statusLabel(task.status),
                accentColor.withOpacity(0.12),
                accentColor,
              ),
              TaskDetailsUtils.buildBadge(
                TaskDetailsUtils.formatDate(task.createdAt),
                Colors.grey.withOpacity(0.08),
                const Color(0xFF64748B),
              ),
              if (task.dueAt != null)
                TaskDetailsUtils.buildBadge(
                  AppPreferences.tr(
                    'Hạn: ${TaskDetailsUtils.formatDueAt(task.dueAt!.toLocal())}',
                    'Due: ${TaskDetailsUtils.formatDueAt(task.dueAt!.toLocal())}',
                  ),
                  Colors.orange.withOpacity(0.12),
                  Colors.orange[800]!,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Text(
                AppPreferences.tr(
                  'Cập nhật: ${TaskDetailsUtils.timeAgo(task.updatedAt)}',
                  'Updated: ${TaskDetailsUtils.timeAgo(task.updatedAt)}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
