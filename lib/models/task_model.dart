// models/task_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum TaskPriority { urgent, high, medium, low, none }

int getPriorityOrder(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.urgent: return 0;
    case TaskPriority.high: return 1;
    case TaskPriority.medium: return 2;
    case TaskPriority.low: return 3;
    case TaskPriority.none: return 4;
  }
}

Color getPriorityColor(TaskPriority? priority, BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  switch (priority) {
    case TaskPriority.urgent: return Colors.red.shade700;
    case TaskPriority.high: return Colors.orange.shade700;
    case TaskPriority.medium: return Colors.blue.shade600;
    case TaskPriority.low: return Colors.green.shade600;
    case TaskPriority.none:
    default: return colorScheme.onSurface.withOpacity(0.4);
  }
}

IconData getPriorityIcon(TaskPriority? priority) {
  switch (priority) {
    case TaskPriority.urgent: return Icons.priority_high_rounded;
    case TaskPriority.high: return Icons.keyboard_double_arrow_up_rounded;
    case TaskPriority.medium: return Icons.drag_handle_rounded;
    case TaskPriority.low: return Icons.keyboard_double_arrow_down_rounded;
    case TaskPriority.none:
    default: return Icons.flag_outlined;
  }
}

String priorityToStringRepresentation(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.urgent: return "Çok Acil";
    case TaskPriority.high: return "Yüksek";
    case TaskPriority.medium: return "Orta";
    case TaskPriority.low: return "Düşük";
    case TaskPriority.none: return "Belirsiz";
  }
}

String priorityToDatabaseString(TaskPriority priority) => priority.toString().split('.').last;

TaskPriority databaseStringToPriority(String? priorityString) {
  if (priorityString == null) return TaskPriority.none;
  try {
    return TaskPriority.values.firstWhere((e) => e.toString().split('.').last == priorityString);
  } catch (e) {
    debugPrint("databaseStringToPriority HATA: Bilinmeyen priority string '$priorityString'. Varsayılan 'none' kullanılıyor.");
    return TaskPriority.none;
  }
}

class Task {
  String id;
  String title;
  bool isDone;
  dynamic createdAt;
  TaskPriority priority;
  late int priorityOrder;
  Timestamp? startTime;
  int elapsedSeconds;
  bool isTimerRunning;
  Timestamp? dueDate; // YENİ ALAN: Görevin yapılacağı tarih

  Task({
    required this.id,
    required this.title,
    this.isDone = false,
    this.createdAt,
    this.priority = TaskPriority.low,
    this.startTime,
    this.elapsedSeconds = 0,
    this.isTimerRunning = false,
    this.dueDate, // Constructor'a eklendi
  }) {
    priorityOrder = getPriorityOrder(priority);
  }

  factory Task.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options,
      ) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception("Firestore'dan gelen task verisi null! ID: ${snapshot.id}");
    }
    TaskPriority currentPriority = databaseStringToPriority(data['priority'] as String?);

    return Task(
      id: snapshot.id,
      title: data['title'] as String? ?? 'Başlıksız Görev',
      isDone: data['isDone'] as bool? ?? false,
      createdAt: data['createdAt'],
      priority: currentPriority,
      startTime: data['startTime'] as Timestamp?,
      elapsedSeconds: data['elapsedSeconds'] as int? ?? 0,
      isTimerRunning: data['isTimerRunning'] as bool? ?? false,
      dueDate: data['dueDate'] as Timestamp?, // Firestore'dan oku
    );
  }

  Map<String, dynamic> toFirestore() {
    final Map<String, dynamic> map = {
      "title": title,
      "isDone": isDone,
      "priority": priorityToDatabaseString(priority),
      "priorityOrder": priorityOrder,
      "startTime": startTime,
      "elapsedSeconds": elapsedSeconds,
      "isTimerRunning": isTimerRunning,
      "dueDate": dueDate, // Firestore'a yaz
    };
    if (createdAt != null) {
      map['createdAt'] = createdAt;
    }
    return map;
  }
}