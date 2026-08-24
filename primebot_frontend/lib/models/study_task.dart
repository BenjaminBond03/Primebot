import 'package:flutter/material.dart';

enum TaskPriority { low, medium, high }

extension TaskPriorityX on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.low:
        return const Color(0xFF43A047);
      case TaskPriority.medium:
        return const Color(0xFFF9A825);
      case TaskPriority.high:
        return const Color(0xFFE53935);
    }
  }
}

enum TaskCategory { assignment, exam, other }

extension TaskCategoryX on TaskCategory {
  String get label {
    switch (this) {
      case TaskCategory.assignment:
        return 'Assignment';
      case TaskCategory.exam:
        return 'Exam';
      case TaskCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case TaskCategory.assignment:
        return Icons.assignment_outlined;
      case TaskCategory.exam:
        return Icons.school_outlined;
      case TaskCategory.other:
        return Icons.task_alt_outlined;
    }
  }
}

class StudyTask {
  final String id;
  String title;
  DateTime dueDate;
  TaskPriority priority;
  TaskCategory category;
  bool isDone;
  bool reminderEnabled;

  StudyTask({
    required this.id,
    required this.title,
    required this.dueDate,
    this.priority = TaskPriority.medium,
    this.category = TaskCategory.assignment,
    this.isDone = false,
    this.reminderEnabled = false,
  });
}
