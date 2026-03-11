import 'package:flutter/material.dart';
import '../../../app_preferences.dart';

class TaskDetailsUtils {
  static String statusLabel(String status) {
    if (status == 'todo') return AppPreferences.tr('Cần làm', 'To Do');
    if (status == 'doing') return AppPreferences.tr('Đang làm', 'Doing');
    return AppPreferences.tr('Hoàn thành', 'Done');
  }

  static String formatDate(String value) {
    var date = DateTime.tryParse(value);
    if (date == null) return value;
    if (!date.isUtc && value.endsWith('Z')) {
      date = date.toLocal();
    } else {
      date = date.toLocal();
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static String formatDueAt(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String timeAgo(String value) {
    var date = DateTime.tryParse(value);
    if (date == null) return value;
    date = date.toLocal();

    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return AppPreferences.tr('Vừa xong', 'Just now');
    if (diff.inMinutes < 60) {
      return AppPreferences.tr(
        '${diff.inMinutes} phút trước',
        '${diff.inMinutes}m ago',
      );
    }
    if (diff.inHours < 24) {
      return AppPreferences.tr(
        '${diff.inHours} giờ trước',
        '${diff.inHours}h ago',
      );
    }
    if (diff.inDays < 7) {
      return AppPreferences.tr(
        '${diff.inDays} ngày trước',
        '${diff.inDays}d ago',
      );
    }

    return formatDate(value);
  }

  static Widget buildBadge(String text, Color bgColor, Color textColor) {
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

  static Widget buildSectionTitle(String title, {Widget? trailing, bool isSaving = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
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
            if (isSaving) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
