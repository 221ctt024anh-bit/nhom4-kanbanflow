import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../domain/entities/task.dart';
import '../../../app_preferences.dart';

class BoardUtils {
  static Color getStatusColor(String status) {
    if (status == 'todo') return Colors.blueAccent;
    if (status == 'doing') return Colors.orangeAccent;
    if (status == 'done') return Colors.teal;
    if (status == 'overdue') return Colors.redAccent;
    return Colors.blueGrey;
  }

  static String getStatusTitle(String status) {
    if (status == 'todo') return AppPreferences.tr('Cần làm', 'To Do');
    if (status == 'doing') return AppPreferences.tr('Đang làm', 'Doing');
    if (status == 'done') return AppPreferences.tr('Hoàn thành', 'Completed');
    if (status == 'overdue') return AppPreferences.tr('Quá hạn', 'Overdue');
    return status;
  }

  static bool isOverdueTask(Task task) {
    return task.dueAt != null &&
        task.status != 'done' &&
        task.dueAt!.isBefore(DateTime.now());
  }

  static List<String> defaultStatuses() => <String>[
        'todo',
        'doing',
        'done',
        'overdue',
      ];

  static bool isSingleStatusFilter(String value) {
    return value == 'todo' ||
        value == 'doing' ||
        value == 'done' ||
        value == 'overdue';
  }

  static List<Task> applyQuickFilter(List<Task> tasks, String quickFilter) {
    if (quickFilter == 'all') return tasks;
    if (quickFilter == 'mine') {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return [];
      return tasks
          .where((t) => t.assigneeIds.contains(userId) || t.creatorId == userId)
          .toList();
    }
    if (quickFilter == 'overdue') {
      return tasks.where(isOverdueTask).toList();
    }
    return tasks.where((t) => t.status == quickFilter).toList();
  }

  static List<Task> getTasksByStatus(List<Task> allTasks, String status) {
    if (status == 'overdue') {
      return allTasks.where(isOverdueTask).toList();
    }
    return allTasks
        .where((t) => t.status == status && !isOverdueTask(t))
        .toList();
  }
}
