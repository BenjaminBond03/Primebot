import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:primebot_frontend/models/class_session.dart';
import 'package:primebot_frontend/models/study_task.dart';
import 'package:primebot_frontend/services/app_settings.dart';
import 'package:primebot_frontend/services/local_database.dart';
import 'package:primebot_frontend/services/notification_service.dart';
import 'package:primebot_frontend/widgets/custom_text_field.dart';

Map<String, Object?> _taskToRow(StudyTask t) => {
      'id': t.id,
      'title': t.title,
      'due_date': t.dueDate.toIso8601String(),
      'priority': t.priority.name,
      'category': t.category.name,
      'is_done': t.isDone ? 1 : 0,
      'reminder_enabled': t.reminderEnabled ? 1 : 0,
    };

StudyTask _taskFromRow(Map<String, Object?> row) => StudyTask(
      id: row['id'] as String,
      title: row['title'] as String,
      dueDate: DateTime.parse(row['due_date'] as String),
      priority: TaskPriority.values.byName(row['priority'] as String),
      category: TaskCategory.values.byName(row['category'] as String),
      isDone: (row['is_done'] as int) == 1,
      reminderEnabled: (row['reminder_enabled'] as int) == 1,
    );

Map<String, Object?> _classToRow(ClassSession c) => {
      'id': c.id,
      'course_name': c.courseName,
      'location': c.location,
      'weekday': c.weekday,
      'start_hour': c.startTime.hour,
      'start_minute': c.startTime.minute,
      'end_hour': c.endTime.hour,
      'end_minute': c.endTime.minute,
    };

ClassSession _classFromRow(Map<String, Object?> row) => ClassSession(
      id: row['id'] as String,
      courseName: row['course_name'] as String,
      location: row['location'] as String,
      weekday: row['weekday'] as int,
      startTime: TimeOfDay(hour: row['start_hour'] as int, minute: row['start_minute'] as int),
      endTime: TimeOfDay(hour: row['end_hour'] as int, minute: row['end_minute'] as int),
    );

const _primaryBlue = Color(0xFF1565C0);
const _darkText = Color(0xFF1A1A2E);
const _greyText = Color(0xFF757575);
const _background = Color(0xFFF5F7FA);

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<StudyTask> _tasks = [];
  List<ClassSession> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadData();
  }

  Future<void> _loadData() async {
    final tasks = (await LocalDatabase.instance.getTaskRows()).map(_taskFromRow).toList();
    final classes = (await LocalDatabase.instance.getClassRows()).map(_classFromRow).toList();

    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _classes = classes;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  StudyTask? get _nextDeadline {
    final upcoming = _tasks.where((t) => !t.isDone).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  Future<void> _addTask(StudyTask task) async {
    setState(() => _tasks.add(task));
    LocalDatabase.instance.upsertTaskRow(_taskToRow(task));
    if (task.reminderEnabled && await AppSettings.instance.notificationsEnabled) {
      NotificationService.instance.scheduleReminder(
        id: task.id,
        title: 'PrimeBot Reminder',
        body: task.title,
        scheduledDate: task.dueDate,
      );
    }
  }

  void _toggleTaskDone(StudyTask task) {
    setState(() => task.isDone = !task.isDone);
    LocalDatabase.instance.upsertTaskRow(_taskToRow(task));
  }

  void _deleteTask(StudyTask task) {
    setState(() => _tasks.remove(task));
    LocalDatabase.instance.deleteTaskRow(task.id);
    NotificationService.instance.cancelReminder(task.id);
  }

  void _addClass(ClassSession session) {
    setState(() => _classes.add(session));
    LocalDatabase.instance.insertClassRow(_classToRow(session));
  }

  void _deleteClass(ClassSession session) {
    setState(() => _classes.remove(session));
    LocalDatabase.instance.deleteClassRow(session.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Tasks & Schedule',
          style: TextStyle(
            color: _darkText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primaryBlue,
          unselectedLabelColor: _greyText,
          indicatorColor: _primaryBlue,
          tabs: const [
            Tab(text: 'Tasks'),
            Tab(text: 'Timetable'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryBlue))
          : TabBarView(
        controller: _tabController,
        children: [_buildTasksTab(), _buildTimetableTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'Add Task' : 'Add Class'),
        onPressed: () => _tabController.index == 0
            ? _showAddTaskSheet()
            : _showAddClassSheet(),
      ),
    );
  }

  Widget _buildTasksTab() {
    final sorted = [..._tasks]
      ..sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        return a.dueDate.compareTo(b.dueDate);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        _buildCountdownCard(),
        const SizedBox(height: 20),
        if (sorted.isEmpty)
          _buildEmptyState(
            icon: Icons.task_alt_outlined,
            message: 'No tasks yet.\nTap "Add Task" to create one.',
          )
        else
          ...sorted.map(_buildTaskTile),
      ],
    );
  }

  Widget _buildCountdownCard() {
    final task = _nextDeadline;
    if (task == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Row(
          children: [
            const Icon(Icons.celebration_outlined, color: _primaryBlue, size: 28),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                "You're all caught up! No upcoming deadlines.",
                style: TextStyle(color: _darkText, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    final daysLeft = task.dueDate.difference(DateTime.now()).inDays;
    final countdownLabel = daysLeft <= 0
        ? (task.dueDate.isBefore(DateTime.now()) ? 'Overdue' : 'Today')
        : daysLeft == 1
            ? 'Tomorrow'
            : '$daysLeft days left';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(task.category.icon, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                'NEXT DEADLINE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            task.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('EEE, MMM d • h:mm a').format(task.dueDate),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              countdownLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(StudyTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _toggleTaskDone(task),
            child: Icon(
              task.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: task.isDone ? _primaryBlue : const Color(0xFFBDBDBD),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Icon(task.category.icon, color: _greyText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: task.isDone ? _greyText : _darkText,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  DateFormat('MMM d, h:mm a').format(task.dueDate),
                  style: const TextStyle(fontSize: 12, color: _greyText),
                ),
              ],
            ),
          ),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: task.priority.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFBDBDBD)),
            onPressed: () => _deleteTask(task),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableTab() {
    if (_classes.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          _buildEmptyState(
            icon: Icons.calendar_month_outlined,
            message: 'No classes added yet.\nTap "Add Class" to build your timetable.',
          ),
        ],
      );
    }

    final byDay = <int, List<ClassSession>>{};
    for (final c in _classes) {
      byDay.putIfAbsent(c.weekday, () => []).add(c);
    }
    final days = byDay.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 6),
            child: Text(
              ClassSession.weekdayNames[day - 1],
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _primaryBlue,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...(byDay[day]!..sort((a, b) {
                final aMin = a.startTime.hour * 60 + a.startTime.minute;
                final bMin = b.startTime.hour * 60 + b.startTime.minute;
                return aMin.compareTo(bMin);
              }))
              .map(_buildClassTile),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildClassTile(ClassSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book_outlined, color: _primaryBlue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.courseName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _darkText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  session.location,
                  style: const TextStyle(fontSize: 12, color: _greyText),
                ),
                const SizedBox(height: 3),
                Text(
                  '${session.startTime.format(context)} - ${session.endTime.format(context)}',
                  style: const TextStyle(fontSize: 12, color: _primaryBlue, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFBDBDBD)),
            onPressed: () => _deleteClass(session),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(icon, size: 48, color: const Color(0xFFBDBDBD)),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _greyText, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  void _showAddTaskSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTaskSheet(onSubmit: _addTask),
    );
  }

  void _showAddClassSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddClassSheet(onSubmit: _addClass),
    );
  }
}

class _AddTaskSheet extends StatefulWidget {
  final void Function(StudyTask) onSubmit;

  const _AddTaskSheet({required this.onSubmit});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleController = TextEditingController();
  DateTime? _dueDate;
  TaskPriority _priority = TaskPriority.medium;
  TaskCategory _category = TaskCategory.assignment;
  bool _reminderEnabled = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;

    setState(() {
      _dueDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty || _dueDate == null) return;
    widget.onSubmit(
      StudyTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        dueDate: _dueDate!,
        priority: _priority,
        category: _category,
        reminderEnabled: _reminderEnabled,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Add Task',
      onSubmit: _submit,
      submitLabel: 'Add Task',
      children: [
        CustomTextField(
          controller: _titleController,
          labelText: 'Task title',
          hintText: 'e.g. Submit assignment 3',
          prefixIcon: Icons.edit_outlined,
        ),
        const SizedBox(height: 16),
        _DateTimePickerField(value: _dueDate, onTap: _pickDueDate),
        const SizedBox(height: 16),
        _LabeledChips<TaskCategory>(
          label: 'Category',
          values: TaskCategory.values,
          selected: _category,
          labelOf: (c) => c.label,
          onSelected: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 16),
        _LabeledChips<TaskPriority>(
          label: 'Priority',
          values: TaskPriority.values,
          selected: _priority,
          labelOf: (p) => p.label,
          onSelected: (p) => setState(() => _priority = p),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: _primaryBlue,
          title: const Text('Remind me', style: TextStyle(fontSize: 14, color: _darkText)),
          subtitle: const Text(
            'Send a notification at the due date & time',
            style: TextStyle(fontSize: 12, color: _greyText),
          ),
          value: _reminderEnabled,
          onChanged: (v) => setState(() => _reminderEnabled = v),
        ),
      ],
    );
  }
}

class _AddClassSheet extends StatefulWidget {
  final void Function(ClassSession) onSubmit;

  const _AddClassSheet({required this.onSubmit});

  @override
  State<_AddClassSheet> createState() => _AddClassSheetState();
}

class _AddClassSheetState extends State<_AddClassSheet> {
  final _courseController = TextEditingController();
  final _locationController = TextEditingController();
  int _weekday = 1;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void dispose() {
    _courseController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time != null) setState(() => _startTime = time);
  }

  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time != null) setState(() => _endTime = time);
  }

  void _submit() {
    if (_courseController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _startTime == null ||
        _endTime == null) {
      return;
    }
    widget.onSubmit(
      ClassSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        courseName: _courseController.text.trim(),
        location: _locationController.text.trim(),
        weekday: _weekday,
        startTime: _startTime!,
        endTime: _endTime!,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Add Class',
      onSubmit: _submit,
      submitLabel: 'Add Class',
      children: [
        CustomTextField(
          controller: _courseController,
          labelText: 'Course name',
          hintText: 'e.g. Database Systems',
          prefixIcon: Icons.menu_book_outlined,
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _locationController,
          labelText: 'Location',
          hintText: 'e.g. Science Block, Room 204',
          prefixIcon: Icons.place_outlined,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Day', style: TextStyle(fontSize: 13, color: _greyText, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(ClassSession.weekdayNames.length, (i) {
            final day = i + 1;
            final selected = _weekday == day;
            return ChoiceChip(
              label: Text(ClassSession.weekdayNames[i].substring(0, 3)),
              selected: selected,
              selectedColor: _primaryBlue,
              labelStyle: TextStyle(color: selected ? Colors.white : _darkText, fontSize: 12),
              onSelected: (_) => setState(() => _weekday = day),
            );
          }),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _DateTimePickerField(
                label: 'Start time',
                timeValue: _startTime,
                onTap: _pickStartTime,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateTimePickerField(
                label: 'End time',
                timeValue: _endTime,
                onTap: _pickEndTime,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback onSubmit;
  final String submitLabel;

  const _SheetScaffold({
    required this.title,
    required this.children,
    required this.onSubmit,
    required this.submitLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _darkText),
              ),
              const SizedBox(height: 18),
              ...children,
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(submitLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTimePickerField extends StatelessWidget {
  final DateTime? value;
  final TimeOfDay? timeValue;
  final String label;
  final VoidCallback onTap;

  const _DateTimePickerField({
    this.value,
    this.timeValue,
    this.label = 'Due date & time',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String displayText = 'Select';
    if (value != null) {
      displayText = DateFormat('MMM d, yyyy • h:mm a').format(value!);
    } else if (timeValue != null) {
      displayText = timeValue!.format(context);
    }
    final hasValue = value != null || timeValue != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 17, color: _greyText),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: _greyText)),
                  Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 14,
                      color: hasValue ? _darkText : const Color(0xFFBDBDBD),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledChips<T> extends StatelessWidget {
  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final void Function(T) onSelected;

  const _LabeledChips({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _greyText, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((v) {
            final isSelected = v == selected;
            return ChoiceChip(
              label: Text(labelOf(v)),
              selected: isSelected,
              selectedColor: _primaryBlue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : _darkText,
                fontSize: 12,
              ),
              onSelected: (_) => onSelected(v),
            );
          }).toList(),
        ),
      ],
    );
  }
}
