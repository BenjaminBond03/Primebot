import 'package:flutter/material.dart';

class ClassSession {
  final String id;
  String courseName;
  String location;
  int weekday;
  TimeOfDay startTime;
  TimeOfDay endTime;

  ClassSession({
    required this.id,
    required this.courseName,
    required this.location,
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });

  static const List<String> weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String get weekdayLabel => weekdayNames[weekday - 1];
}
