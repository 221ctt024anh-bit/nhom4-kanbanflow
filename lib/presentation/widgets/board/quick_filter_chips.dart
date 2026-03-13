import 'package:flutter/material.dart';
import '../../../app_preferences.dart';

class QuickFilterChips extends StatelessWidget {
  final String currentFilter;
  final Function(String) onFilterChanged;

  const QuickFilterChips({
    super.key,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('all', AppPreferences.tr('Tất cả', 'All')),
          const SizedBox(width: 8),
          _filterChip('mine', AppPreferences.tr('Việc của tôi', 'My tasks')),
          const SizedBox(width: 8),
          _filterChip('overdue', AppPreferences.tr('Quá hạn', 'Overdue')),
          const SizedBox(width: 8),
          _filterChip('doing', AppPreferences.tr('Đang làm', 'Doing')),
          const SizedBox(width: 8),
          _filterChip('done', AppPreferences.tr('Hoàn thành', 'Completed')),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = currentFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onFilterChanged(value),
      selectedColor: Colors.blueAccent.withOpacity(0.16),
      labelStyle: TextStyle(
        color: selected ? Colors.blueAccent : Colors.black87,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}
