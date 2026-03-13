import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../app_preferences.dart';
import '../../domain/entities/assigned_task_view.dart';
import '../../domain/repositories/task_aggregator_repository.dart';
import '../../injection_container.dart';
import 'task_details_screen.dart';

class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TaskAggregatorRepository _repository = sl<TaskAggregatorRepository>();
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Trạng thái cho Calendar view
  final Map<DateTime, List<AssignedTaskView>> _events = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDay = _focusedDay;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<AssignedTaskView> _getEventsForDay(DateTime day) {
    // Chỉ lấy phần ngày để so sánh
    final date = DateTime(day.year, day.month, day.day);
    return _events[date] ?? [];
  }

  void _updateEvents(List<AssignedTaskView> tasks) {
    _events.clear();
    for (final taskView in tasks) {
      if (taskView.task.dueAt != null) {
        final date = DateTime(
          taskView.task.dueAt!.year,
          taskView.task.dueAt!.month,
          taskView.task.dueAt!.day,
        );
        if (_events[date] == null) _events[date] = [];
        _events[date]!.add(taskView);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppPreferences.tr('Công việc của tôi', 'My Tasks')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: AppPreferences.tr('Danh sách', 'List')),
            Tab(text: AppPreferences.tr('Lịch', 'Calendar')),
          ],
        ),
      ),
      body: StreamBuilder<List<AssignedTaskView>>(
        stream: _repository.getAssignedTasksStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final tasks = snapshot.data ?? [];
          _updateEvents(tasks);

          return TabBarView(
            controller: _tabController,
            children: [
              _buildListView(tasks),
              _buildCalendarView(tasks),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListView(List<AssignedTaskView> tasks) {
    if (tasks.isEmpty) {
      return _buildEmptyState();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextWeek = today.add(const Duration(days: 7));

    final overdue = tasks.where((t) => t.task.dueAt != null && t.task.dueAt!.isBefore(today) && t.task.status != 'done').toList();
    final dueToday = tasks.where((t) => t.task.dueAt != null && _isSameDay(t.task.dueAt!, today)).toList();
    final upcoming = tasks.where((t) => t.task.dueAt != null && t.task.dueAt!.isAfter(today) && t.task.dueAt!.isBefore(nextWeek)).toList();
    final later = tasks.where((t) => t.task.dueAt != null && t.task.dueAt!.isAfter(nextWeek)).toList();
    final noDueDate = tasks.where((t) => t.task.dueAt == null).toList();

    return RefreshIndicator(
      onRefresh: () => _repository.fetchAssignedTasks(Supabase.instance.client.auth.currentUser!.id),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (overdue.isNotEmpty) _buildSection(AppPreferences.tr('Quá hạn', 'Overdue'), overdue, Colors.redAccent),
          if (dueToday.isNotEmpty) _buildSection(AppPreferences.tr('Hôm nay', 'Today'), dueToday, Colors.blueAccent),
          if (upcoming.isNotEmpty) _buildSection(AppPreferences.tr('Tuần này', 'This Week'), upcoming, Colors.green),
          if (later.isNotEmpty) _buildSection(AppPreferences.tr('Sắp tới', 'Upcoming'), later, Colors.grey),
          if (noDueDate.isNotEmpty) _buildSection(AppPreferences.tr('Chưa có hạn', 'No Due Date'), noDueDate, Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<AssignedTaskView> tasks, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 8),
              Text(
                '(${tasks.length})',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
        ...tasks.map((t) => _buildTaskCard(t)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTaskCard(AssignedTaskView taskView) {
    final task = taskView.task;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskDetailsScreen(
              task: task,
              accentColor: Colors.blueAccent,
            ),
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.status == 'done' ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                taskView.boardTitle,
                style: const TextStyle(color: Colors.blueAccent, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (task.dueAt != null) ...[
              const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                DateFormat('dd/MM').format(task.dueAt!),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        trailing: _buildStatusChip(task.status),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'todo':
        color = Colors.grey;
        label = AppPreferences.tr('Cần làm', 'To Do');
        break;
      case 'doing':
        color = Colors.blue;
        label = AppPreferences.tr('Đang làm', 'Doing');
        break;
      case 'done':
        color = Colors.green;
        label = AppPreferences.tr('Xong', 'Done');
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            AppPreferences.tr('Bạn chưa có công việc nào được giao', 'No tasks assigned yet'),
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(List<AssignedTaskView> tasks) {
    return Column(
      children: [
        TableCalendar<AssignedTaskView>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          eventLoader: _getEventsForDay,
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            if (_calendarFormat != format) {
              setState(() {
                _calendarFormat = format;
              });
            }
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          calendarStyle: const CalendarStyle(
            todayDecoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _getEventsForDay(_selectedDay!).map((t) => _buildTaskCard(t)).toList(),
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
}
