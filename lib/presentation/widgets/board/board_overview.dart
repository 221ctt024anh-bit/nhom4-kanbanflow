import 'package:flutter/material.dart';
import '../../../domain/entities/task.dart';
import '../../../app_preferences.dart';
import 'board_utils.dart';

class BoardOverview extends StatelessWidget {
  final List<Task> tasks;
  final List<Task> allTasks;
  final List<String> visibleStatuses;

  const BoardOverview({
    super.key,
    required this.tasks,
    required this.allTasks,
    required this.visibleStatuses,
  });

  @override
  Widget build(BuildContext context) {
    final showDone = visibleStatuses.contains('done');
    final showDoing = visibleStatuses.contains('doing');
    final showTodo = visibleStatuses.contains('todo');
    final showOverdue = visibleStatuses.contains('overdue');

    final overdue = showOverdue ? tasks.where(BoardUtils.isOverdueTask).length : 0;
    final done = showDone ? tasks.where((t) => t.status == 'done').length : 0;
    final doing = showDoing
        ? tasks
            .where((t) => t.status == 'doing' && !BoardUtils.isOverdueTask(t))
            .length
        : 0;
    final todo = showTodo
        ? tasks
            .where((t) => t.status == 'todo' && !BoardUtils.isOverdueTask(t))
            .length
        : 0;

    final boardTotal = allTasks.length;
    final activeTotal = done + doing + todo + overdue;
    final progress = activeTotal == 0 ? 0.0 : done / activeTotal;
    final percentText = '${(progress * 100).round()}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 9,
                  strokeCap: StrokeCap.round,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF2563EB),
                  ),
                ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      percentText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      AppPreferences.tr('Tiến độ', 'Progress'),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _miniStat(
                  AppPreferences.tr('Toán dự án', 'Project'),
                  boardTotal,
                  const Color(0xFF334155),
                ),
                _miniStat(
                  AppPreferences.tr('Cần làm', 'To Do'),
                  todo,
                  Colors.blueAccent,
                ),
                _miniStat(
                  AppPreferences.tr('Đang làm', 'Doing'),
                  doing,
                  Colors.orangeAccent,
                ),
                _miniStat(
                  AppPreferences.tr('Hoàn thành', 'Done'),
                  done,
                  Colors.teal,
                ),
                _miniStat(
                  AppPreferences.tr('Quá hạn', 'Overdue'),
                  overdue,
                  Colors.redAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
