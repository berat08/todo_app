// services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // debugPrint için
import '../models/task_model.dart';

enum SortOption {
  createdAtDesc,
  createdAtAsc,
  priorityDesc,
  priorityAsc,
  titleAsc,
  titleDesc,
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late final CollectionReference<Task> _tasksCollection;

  FirestoreService() {
    _tasksCollection = _db.collection('tasks').withConverter<Task>(
      fromFirestore: Task.fromFirestore,
      toFirestore: (Task task, _) => task.toFirestore(),
    );
  }

  Future<DocumentSnapshot<Task>> getTaskDocument(String taskId) async {
    return _tasksCollection.doc(taskId).get();
  }

  Future<void> addTask(String title, {TaskPriority priority = TaskPriority.low, Timestamp? dueDate}) async {
    debugPrint("FirestoreService: addTask çağrıldı. Başlık: '$title', Öncelik: $priority, DueDate: $dueDate");
    try {
      final newTask = Task(
        id: '',
        title: title,
        priority: priority,
        createdAt: FieldValue.serverTimestamp(),
        dueDate: dueDate,
      );
      DocumentReference docRef = await _tasksCollection.add(newTask);
      debugPrint("FirestoreService: Görev başarıyla eklendi. Doküman ID: ${docRef.id}");
    } catch (e, s) {
      debugPrint("FirestoreService: addTask sırasında HATA OLUŞTU!");
      debugPrint("HATA: $e");
      debugPrint("STACKTRACE: $s");
      rethrow;
    }
  }

  Future<void> toggleTaskStatus(String taskId, bool currentStatus) async {
    await _tasksCollection.doc(taskId).update({'isDone': !currentStatus});
  }

  Future<void> deleteTask(String taskId) async {
    await _tasksCollection.doc(taskId).delete();
  }

  Stream<QuerySnapshot<Task>> getPendingTasksStream({
    TaskPriority? priorityFilter,
    SortOption sortOption = SortOption.createdAtDesc,
  }) {
    Query<Task> query = _tasksCollection.where('isDone', isEqualTo: false);

    if (priorityFilter != null && priorityFilter != TaskPriority.none) {
      query = query.where('priority', isEqualTo: priorityToDatabaseString(priorityFilter));
    }

    switch (sortOption) {
      case SortOption.priorityDesc:
        query = query.orderBy('priorityOrder', descending: false).orderBy('createdAt', descending: true);
        break;
      case SortOption.priorityAsc:
        query = query.orderBy('priorityOrder', descending: true).orderBy('createdAt', descending: true);
        break;
      case SortOption.titleAsc:
        query = query.orderBy('title', descending: false).orderBy('priorityOrder', descending: false).orderBy('createdAt', descending: true);
        break;
      case SortOption.titleDesc:
        query = query.orderBy('title', descending: true).orderBy('priorityOrder', descending: false).orderBy('createdAt', descending: true);
        break;
      case SortOption.createdAtAsc:
        query = query.orderBy('createdAt', descending: false).orderBy('priorityOrder', descending: false);
        break;
      case SortOption.createdAtDesc:
      default:
        query = query.orderBy('createdAt', descending: true).orderBy('priorityOrder', descending: false);
    }
    debugPrint("FirestoreService: getPendingTasksStream sorgusu. Sort: $sortOption, Filter: $priorityFilter");
    return query.snapshots();
  }

  Stream<QuerySnapshot<Task>> getCompletedTasksStream() {
    return _tasksCollection
        .where('isDone', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateTaskPriority(String taskId, TaskPriority newPriority) async {
    await _tasksCollection.doc(taskId).update({
      'priority': priorityToDatabaseString(newPriority),
      'priorityOrder': getPriorityOrder(newPriority),
    });
  }

  Future<void> startOrUpdateTimer(String taskId, Timestamp startTime, int currentElapsedSeconds) async {
    await _tasksCollection.doc(taskId).update({
      'startTime': startTime,
      'isTimerRunning': true,
    });
    debugPrint("FirestoreService: Timer başlatıldı/güncellendi. Task ID: $taskId, StartTime: $startTime");
  }

  Future<void> stopTimer(String taskId, int elapsedSeconds, [bool appPausedOrTaskCompleted = false]) async {
    await _tasksCollection.doc(taskId).update({
      'elapsedSeconds': elapsedSeconds,
      'isTimerRunning': false,
      'startTime': null,
    });
    debugPrint("FirestoreService: Timer durduruldu. Task ID: $taskId, Elapsed: $elapsedSeconds");
  }

  Future<void> resetTimer(String taskId) async {
    await _tasksCollection.doc(taskId).update({
      'elapsedSeconds': 0,
      'isTimerRunning': false,
      'startTime': null,
    });
    debugPrint("FirestoreService: Timer sıfırlandı. Task ID: $taskId");
  }

  Stream<QuerySnapshot<Task>> getAllTasksWithDueDateStream() {
    return _tasksCollection
        .orderBy('dueDate', descending: false)
        .snapshots();
  }

  // YENİ METOD - Belirli bir tarih aralığında tamamlanmış görevleri getirmek için
  Stream<QuerySnapshot<Task>> getCompletedTasksByDateRangeStream(
      Timestamp startDate, Timestamp endDate) {
    return _tasksCollection
        .where('isDone', isEqualTo: true)
        .where('createdAt', isGreaterThanOrEqualTo: startDate)
        .where('createdAt', isLessThanOrEqualTo: endDate)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}