//ekran.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/task_model.dart'; // Model importu
import 'services/firestore_service.dart';
import 'tamamlanmıs.dart'; // Servis importu

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _taskController = TextEditingController();
  final FocusNode _taskFocusNode = FocusNode();

  @override
  void dispose() {
    _taskController.dispose();
    _taskFocusNode.dispose();
    super.dispose();
  }

  void _addTask() async {
    final String text = _taskController.text.trim();
    if (text.isNotEmpty) {
      try {
        await _firestoreService.addTask(text);
        _taskController.clear();
        _taskFocusNode.unfocus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Görev eklendi!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Görev eklenirken hata: $e')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir görev girin!'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(10),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _toggleTaskStatus(Task task) async {
    try {
      await _firestoreService.toggleTaskStatus(task.id, task.isDone);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Görev durumu güncellenirken hata: $e')),
        );
      }
    }
  }

  void _deleteTask(Task task) async {
    try {
      await _firestoreService.deleteTask(task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${task.title}" görevi silindi.'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(10),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Görev silinirken hata: $e')),
        );
      }
    }
  }

  void _navigateToCompletedTasks() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CompletedTasksScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yapılacaklar (Firestore)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Yapılanları Göster',
            onPressed: _navigateToCompletedTasks,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    focusNode: _taskFocusNode,
                    decoration: const InputDecoration(hintText: 'Yeni görev ekle...'),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Ekle'),
                  onPressed: _addTask,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Task>>(
              stream: _firestoreService.getPendingTasksStream(),
              builder: (context, AsyncSnapshot<QuerySnapshot<Task>> snapshot) { // AsyncSnapshot tipini belirtmek iyi olur
                // --- DEBUG PRINTLERİ BAŞLANGIÇ ---
                print("--- StreamBuilder Güncellemesi (TodoListScreen) ---");
                print("Bağlantı Durumu: ${snapshot.connectionState}");

                if (snapshot.hasError) {
                  print("HATA OLUŞTU: ${snapshot.error}");
                  // Hatanın stack trace'ini de görmek için:
                  // print("Hata StackTrace: ${snapshot.stackTrace}");
                }

                print("Veri Var mı (hasData): ${snapshot.hasData}");

                if (snapshot.hasData) {
                  print("Gelen Doküman Sayısı: ${snapshot.data!.docs.length}");
                  if (snapshot.data!.docs.isNotEmpty) {
                    // İlk dokümanın verisini (Task nesnesi) ve bazı alanlarını yazdıralım
                    Task firstTask = snapshot.data!.docs.first.data(); // withConverter sayesinde bu Task olmalı
                    print("İlk Görevin ID'si: ${firstTask.id}");
                    print("İlk Görevin Başlığı: ${firstTask.title}");
                    print("İlk Görevin Durumu (isDone): ${firstTask.isDone}");
                    print("İlk Görevin Oluşturulma Zamanı (createdAt): ${firstTask.createdAt.toDate()}"); // .toDate() ile daha okunabilir
                  } else {
                    print("Doküman listesi boş.");
                  }
                } else {
                  print("Snapshot'ta veri yok (snapshot.hasData false).");
                }
                print("--- StreamBuilder Güncellemesi BİTTİ (TodoListScreen) ---");
                // --- DEBUG PRINTLERİ SON ---

                if (snapshot.hasError) {
                  return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Bu koşulu biraz daha detaylı loglayalım
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  print(">>> 'Yapılacak görev yok' mesajı gösteriliyor. HasData: ${snapshot.hasData}, Docs Empty: ${snapshot.data?.docs.isEmpty}");
                  return const Center(
                      child: Text('Yapılacak görev yok.\nHarika!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey)));
                }

                final pendingTasks = snapshot.data!.docs.map((doc) => doc.data()).toList();

                return ListView.builder(
                  itemCount: pendingTasks.length,
                  itemBuilder: (context, index) {
                    final task = pendingTasks[index];
                    return _buildTaskItem(task);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: task.isDone,
          onChanged: (bool? value) {
            _toggleTaskStatus(task);
          },
          activeColor: Colors.indigo,
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isDone ? TextDecoration.lineThrough : TextDecoration.none,
            color: task.isDone ? Colors.grey : null,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _deleteTask(task),
          tooltip: 'Görevi Sil',
        ),
        onTap: () => _toggleTaskStatus(task),
      ),
    );
  }
}