//services//firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart'; // Task modelini import et

class FirestoreService {
  // Firestore instance'ı
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 'tasks' koleksiyonuna referans (withConverter ile)
  late final CollectionReference<Task> _tasksCollection;

  FirestoreService() {
    _tasksCollection = _firestore.collection('tasks').withConverter<Task>(
      fromFirestore: Task.fromFirestore,
      toFirestore: (Task task, _) => task.toFirestore(),
    );
  }

  // Yapılacak görevler için stream
  Stream<QuerySnapshot<Task>> getPendingTasksStream() {
    return _tasksCollection
        .where('isDone', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Tamamlanmış görevler için stream
  Stream<QuerySnapshot<Task>> getCompletedTasksStream() {
    return _tasksCollection
        .where('isDone', isEqualTo: true)
        .orderBy('createdAt', descending: true) // Veya tamamlanma zamanına göre sırala
        .snapshots();
  }

  // Yeni görev ekleme
  Future<void> addTask(String title) async {
    // toFirestore'da createdAt olmadığı için burada manuel ekliyoruz
    // veya Task constructor'ında FieldValue.serverTimestamp() desteklenmeli
    // ya da Task.toFirestore() FieldValue.serverTimestamp() içermeli.
    // Şimdilik doğrudan Map ile ekleyelim ve createdAt'i FieldValue ile verelim.
    await _firestore.collection('tasks').add({ // _tasksCollection.add() yerine doğrudan Map
      'title': title,
      'isDone': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // VEYA Task modelini güncelleyerek:
    // Task newTask = Task(id: '', title: title, createdAt: Timestamp.now()); // id Firestore'dan gelecek
    // await _tasksCollection.add(newTask); // Bu durumda toFirestore'un createdAt'i doğru yönetmesi gerekir.
  }

  // Görev durumunu güncelleme
  Future<void> toggleTaskStatus(String taskId, bool currentStatus) async {
    await _tasksCollection.doc(taskId).update({'isDone': !currentStatus});
  }

  // Görevi silme
  Future<void> deleteTask(String taskId) async {
    await _tasksCollection.doc(taskId).delete();
  }
}