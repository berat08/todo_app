// tamamlanmis.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/task_model.dart'; // Model importu
import 'services/firestore_service.dart'; // Servis importu

class CompletedTasksScreen extends StatelessWidget {
  const CompletedTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yapılan Görevler (Firestore)'),
      ),
      body: StreamBuilder<QuerySnapshot<Task>>(
        stream: firestoreService.getCompletedTasksStream(),
        builder: (context, AsyncSnapshot<QuerySnapshot<Task>> snapshot) { // AsyncSnapshot tipini belirtmek iyi olur
          // --- DEBUG PRINTLERİ BAŞLANGIÇ ---
          print("--- StreamBuilder Güncellemesi (CompletedTasksScreen) ---");
          print("Bağlantı Durumu: ${snapshot.connectionState}");

          if (snapshot.hasError) {
            print("HATA OLUŞTU (Completed): ${snapshot.error}");
            // print("Hata StackTrace (Completed): ${snapshot.stackTrace}");
          }

          print("Veri Var mı (Completed - hasData): ${snapshot.hasData}");

          if (snapshot.hasData) {
            print("Gelen Doküman Sayısı (Completed): ${snapshot.data!.docs.length}");
            if (snapshot.data!.docs.isNotEmpty) {
              Task firstTask = snapshot.data!.docs.first.data();
              print("İlk Tamamlanmış Görevin Başlığı: ${firstTask.title}");
            } else {
              print("Tamamlanmış doküman listesi boş.");
            }
          } else {
            print("Snapshot'ta veri yok (Completed - snapshot.hasData false).");
          }
          print("--- StreamBuilder Güncellemesi BİTTİ (CompletedTasksScreen) ---");
          // --- DEBUG PRINTLERİ SON ---

          if (snapshot.hasError) {
            // Kullanıcıya daha anlaşılır bir hata mesajı göstermek için
            // ve dizin oluşturma linkini tekrar sağlamak için:
            if (snapshot.error.toString().contains('firestore/failed-precondition') &&
                snapshot.error.toString().contains('index')) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Bir hata oluştu: Firestore sorgusu için bir dizin gerekiyor.\n\nLütfen Firebase Console\'da şu dizini oluşturun:\nKoleksiyon: tasks\nAlanlar: isDone (Artan), createdAt (Azalan)\n\nHata Detayı: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print(">>> 'Henüz tamamlanmış görev yok' mesajı gösteriliyor. HasData: ${snapshot.hasData}, Docs Empty: ${snapshot.data?.docs.isEmpty}");
            return const Center(
                child: Text('Henüz tamamlanmış görev yok.',
                    style: TextStyle(fontSize: 16, color: Colors.grey)));
          }

          final completedTasks = snapshot.data!.docs.map((doc) => doc.data()).toList();

          return ListView.builder(
            itemCount: completedTasks.length,
            itemBuilder: (context, index) {
              final task = completedTasks[index];
              return Card(
                child: ListTile(
                  leading: Checkbox(
                    value: task.isDone,
                    onChanged: (bool? value) async {
                      try {
                        await firestoreService.toggleTaskStatus(task.id, task.isDone);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Görev durumu güncellenirken hata: $e')),
                          );
                        }
                      }
                    },
                    activeColor: Colors.indigo,
                  ),
                  title: Text(
                    task.title,
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () async {
                      try {
                        await firestoreService.deleteTask(task.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('"${task.title}" görevi kalıcı olarak silindi.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Görev silinirken hata: $e')),
                          );
                        }
                      }
                    },
                    tooltip: 'Görevi Kalıcı Olarak Sil',
                  ),
                  onTap: () async {
                    try {
                      await firestoreService.toggleTaskStatus(task.id, task.isDone);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Görev durumu güncellenirken hata: $e')),
                        );
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}