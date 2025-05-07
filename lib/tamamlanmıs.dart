// tamamlanmis.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'models/task_model.dart';
import 'services/firestore_service.dart';

class CompletedTasksScreen extends StatelessWidget {
  const CompletedTasksScreen({super.key});

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) return "$hours:$minutes:$seconds";
    return "$minutes:$seconds";
  }

  String _formatTimestamp(dynamic timestamp, BuildContext context) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(date.toLocal());
    }
    return "Bilinmiyor";
  }

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tamamlananlar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Task>>(
        stream: firestoreService.getCompletedTasksStream(),
        builder: (context, AsyncSnapshot<QuerySnapshot<Task>> snapshot) {
          if (snapshot.hasError) {
            if (snapshot.error.toString().contains('firestore/failed-precondition') &&
                snapshot.error.toString().contains('index')) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Veritabanı yapılandırma hatası.\nLütfen Firebase Console\'da "tasks" koleksiyonu için şu dizini oluşturun:\nAlanlar: isDone (Artan), createdAt (Azalan)\n\nDetay: ${snapshot.error}',
                    textAlign: TextAlign.center, style: TextStyle(color: colorScheme.error)),
              ),
              );
            }
            return Center(child: Text('Bir hata oluştu: ${snapshot.error}', style: TextStyle(color: colorScheme.error)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.playlist_add_check_circle_outlined, size: 70, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('Henüz tamamlanmış göreviniz yok.', style: textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Text('Görevleri tamamladıkça burada listelenecekler.', style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500), textAlign: TextAlign.center),
                ],
              ),
            );
          }

          final completedTasks = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: completedTasks.length,
            itemBuilder: (context, index) {
              final task = completedTasks[index].data();
              final priorityColor = getPriorityColor(task.priority, context);

              return Card(
                elevation: 1.5,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  leading: Tooltip(
                    message: "Tekrar yapılacaklara ekle",
                    child: Checkbox(
                      value: task.isDone,
                      onChanged: (bool? value) async {
                        try {
                          await firestoreService.toggleTaskStatus(task.id, task.isDone);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('"${task.title}" yapılacaklara taşındı.'), backgroundColor: colorScheme.secondary),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Durum güncellenirken hata: $e'), backgroundColor: colorScheme.error));
                          }
                        }
                      },
                    ),
                  ),
                  title: Text(
                    task.title,
                    style: textTheme.bodyLarge?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (task.priority != TaskPriority.none) ...[
                            Icon(getPriorityIcon(task.priority), size: 15, color: priorityColor.withOpacity(0.8)),
                            const SizedBox(width: 4),
                            Text(priorityToStringRepresentation(task.priority), style: TextStyle(fontSize: 11, color: priorityColor.withOpacity(0.9), fontWeight: FontWeight.w500)),
                            Text("  •  ", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                          Icon(Icons.event_available_rounded, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(task.createdAt, context), // Tamamlanma tarihi idealde 'completedAt' olurdu
                            style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600, fontSize: 11),
                          ),
                        ],
                      ),

                      if (task.elapsedSeconds > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_off_outlined, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text("Süre: ${_formatDuration(task.elapsedSeconds)}", style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600, fontSize: 11)),
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_forever_outlined, color: colorScheme.error.withOpacity(0.7)),
                    tooltip: 'Kalıcı Olarak Sil',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          title: const Text('Görevi Kalıcı Sil?'),
                          content: Text('"${task.title}" görevini kalıcı olarak silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
                          actions: [
                            TextButton(child: const Text('İptal'), onPressed: () => Navigator.of(context).pop(false)),
                            TextButton(style: TextButton.styleFrom(foregroundColor: colorScheme.error), child: const Text('Sil'), onPressed: () => Navigator.of(context).pop(true)),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        try {
                          await firestoreService.deleteTask(task.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('"${task.title}" kalıcı olarak silindi.'), backgroundColor: colorScheme.primary),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Görev silinirken hata: $e'), backgroundColor: colorScheme.error));
                          }
                        }
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}