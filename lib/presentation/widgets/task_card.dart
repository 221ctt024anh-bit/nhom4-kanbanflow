import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/task.dart';
import '../blocs/task_bloc.dart';
import '../blocs/task_event.dart';
import '../screens/task_details_screen.dart';
import 'user_avatar.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final Color accentColor;

  const TaskCard({super.key, required this.task, required this.accentColor});

  String _formatDueAt(DateTime dueAt) {
    return '${dueAt.day.toString().padLeft(2, '0')}/'
        '${dueAt.month.toString().padLeft(2, '0')} '
        '${dueAt.hour.toString().padLeft(2, '0')}:'
        '${dueAt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTypeBadge() {
    String label;
    IconData icon;
    Color color;

    if (task.taskType == 'checklist' || task.checklist.isNotEmpty) {
      label = 'Danh sách';
      icon = Icons.checklist_rtl_rounded;
      color = Colors.greenAccent;
    } else if (task.taskType == 'image') {
      label = 'Ảnh & Video';
      icon = Icons.image_rounded;
      color = Colors.purpleAccent;
    } else if (task.taskType == 'audio') {
      label = 'Âm thanh';
      icon = Icons.keyboard_voice_rounded;
      color = Colors.redAccent;
    } else {
      label = 'Văn bản';
      icon = Icons.text_snippet_rounded;
      color = Colors.blueAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color.withOpacity(0.8)),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: color.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOverdue =
        task.dueAt != null &&
        task.status != 'done' &&
        task.dueAt!.isBefore(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TaskDetailsScreen(task: task, accentColor: accentColor),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: accentColor, width: 3)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTypeBadge(),
                            const SizedBox(height: 6),
                            Text(
                              task.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF1E293B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => context.read<TaskBloc>().add(
                          DeleteTaskEvent(task.id),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.black26,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (task.checklist.isNotEmpty || task.hasAttachments)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          if (task.checklist.isNotEmpty) ...[
                            Icon(
                              Icons.check_box_outlined,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${task.checklist.where((e) => e.isDone).length}/${task.checklist.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (task.hasAttachments) const SizedBox(width: 12),
                          ],
                          if (task.hasAttachments)
                            Icon(
                              Icons.attach_file_rounded,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                        ],
                      ),
                    ),
                  if (task.assigneeIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          if (task.dueAt != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isOverdue
                                    ? Colors.red.withOpacity(0.12)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isOverdue
                                      ? Colors.red.withOpacity(0.4)
                                      : Colors.grey.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                _formatDueAt(task.dueAt!),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isOverdue
                                      ? const Color(0xFFB91C1C)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          const Spacer(),
                          SizedBox(
                            height: 24,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (
                                  int i = 0;
                                  i < task.assigneeIds.length;
                                  i++
                                )
                                  Align(
                                    widthFactor: 0.6,
                                    child: UserAvatar(
                                      userId: task.assigneeIds[i],
                                      radius: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (task.assigneeIds.isEmpty && task.dueAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? Colors.red.withOpacity(0.12)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isOverdue
                                ? Colors.red.withOpacity(0.4)
                                : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          _formatDueAt(task.dueAt!),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOverdue
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
