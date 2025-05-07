// ekran.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'models/task_model.dart';
import 'services/firestore_service.dart';
import 'tamamlanmıs.dart';
import 'screens/calendar_screen.dart';
import 'screens/focus_stats_screen.dart'; // Odaklanma Süresi ekranı için import

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> with WidgetsBindingObserver {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _taskController = TextEditingController();
  final FocusNode _taskFocusNode = FocusNode();
  late ConfettiController _confettiController;

  TaskPriority _selectedPriorityFilter = TaskPriority.none;
  SortOption _currentSortOption = SortOption.createdAtDesc;

  final Map<String, bool> _localTimerRunningState = {};

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr_TR', null);
    WidgetsBinding.instance.addObserver(this);
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 400));
    _loadInitialLocalTimerStates();
    debugPrint("_TodoListScreenState: initState tamamlandı.");
  }

  void _loadInitialLocalTimerStates() async {
    debugPrint("_loadInitialLocalTimerStates çağrıldı.");
    try {
      final snapshot = await _firestoreService.getPendingTasksStream(
        priorityFilter: _selectedPriorityFilter == TaskPriority.none ? null : _selectedPriorityFilter,
        sortOption: _currentSortOption,
      ).first;

      if (!mounted) return;

      final newStates = <String, bool>{};
      for (var doc in snapshot.docs) {
        Task task = doc.data();
        newStates[task.id] = task.isTimerRunning;
      }
      if (mounted) {
        setState(() {
          _localTimerRunningState.clear();
          _localTimerRunningState.addAll(newStates);
          debugPrint("_localTimerRunningState güncellendi: $_localTimerRunningState");
        });
      }
    } catch (e, s) {
      debugPrint("_loadInitialLocalTimerStates HATA: $e \nSTACKTRACE: $s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Timer durumları yüklenirken hata: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint("_TodoListScreenState: didChangeAppLifecycleState. State: $state");
    if (!mounted) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      debugPrint("Uygulama duraklatıldı/sonlandırılıyor. Çalışan timer'lar Firestore'a kaydedilecek.");
      _localTimerRunningState.forEach((taskId, wasRunningLocally) async {
        if (wasRunningLocally) {
          try {
            final docSnap = await _firestoreService.getTaskDocument(taskId);
            if (docSnap.exists) {
              final taskData = docSnap.data();
              if (taskData != null && taskData.isTimerRunning && taskData.startTime != null) {
                final now = Timestamp.now();
                final runningMillis = now.millisecondsSinceEpoch - taskData.startTime!.millisecondsSinceEpoch;
                final totalElapsed = taskData.elapsedSeconds + (runningMillis > 0 ? (runningMillis / 1000).floor() : 0);
                await _firestoreService.stopTimer(taskId, totalElapsed, true);
                debugPrint("Arka plana geçiş: Task ID $taskId için timer durduruldu. Elapsed: $totalElapsed");
              }
            }
          } catch (e) {
            debugPrint("Arka planda timer durdurma hatası (Task ID: $taskId): $e");
          }
        }
      });
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("Uygulama devam ettirildi. Timer durumları Firestore'dan yeniden yüklenecek.");
      _loadInitialLocalTimerStates();
    }
  }

  @override
  void dispose() {
    debugPrint("_TodoListScreenState: dispose çağrıldı.");
    WidgetsBinding.instance.removeObserver(this);
    _taskController.dispose();
    _taskFocusNode.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _addTask() async {
    final String text = _taskController.text.trim();
    if (text.isNotEmpty) {
      debugPrint("_addTask: Görev metni: '$text'");
      try {
        await _firestoreService.addTask(text);
        _taskController.clear();
        _taskFocusNode.unfocus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"$text" görevi eklendi!'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          );
        }
      } catch (e,s) {
        debugPrint("_addTask HATA: $e \nSTACKTRACE: $s");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Görev eklenirken hata: $e'), backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Lütfen bir görev metni girin.'), backgroundColor: Theme.of(context).colorScheme.error.withOpacity(0.9)),
      );
    }
  }

  void _toggleTaskStatus(Task task) async {
    debugPrint("_toggleTaskStatus. Task ID: ${task.id}, Mevcut Durum: ${task.isDone}");
    try {
      bool willBeDone = !task.isDone;

      if (willBeDone && (_localTimerRunningState[task.id] ?? task.isTimerRunning)) {
        debugPrint("Görev tamamlanıyor ve timer çalışıyordu. Önce timer durdurulacak.");
        await _handleStopTimer(task, taskCompleted: true);
      }

      await _firestoreService.toggleTaskStatus(task.id, task.isDone);

      if (mounted) {
        if (willBeDone) {
          _confettiController.play();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${task.title}" tamamlandı! 🎉'), backgroundColor: Colors.green.shade600),
          );
          if (mounted) { setState(() { _localTimerRunningState.remove(task.id); }); }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${task.title}" tekrar yapılacaklara taşındı.'), backgroundColor: Theme.of(context).colorScheme.secondaryContainer),
          );
          _loadInitialLocalTimerStates();
        }
      }
    } catch (e,s) {
      debugPrint("_toggleTaskStatus HATA: $e \nSTACKTRACE: $s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Durum güncellenirken hata: $e'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  void _deleteTask(Task task, {bool fromSlidable = false}) async {
    debugPrint("_deleteTask. Task ID: ${task.id}, fromSlidable: $fromSlidable");
    bool confirmDelete = fromSlidable;
    if (!fromSlidable) {
      confirmDelete = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Görevi Sil'),
          content: Text('"${task.title}" görevini silmek istediğinizden emin misiniz?'),
          actions: <Widget>[
            TextButton(child: const Text('İptal'), onPressed: () => Navigator.of(context).pop(false)),
            TextButton(style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), child: const Text('Sil'), onPressed: () => Navigator.of(context).pop(true)),
          ],
        ),
      ) ?? false;
    }

    if (confirmDelete) {
      try {
        if (_localTimerRunningState[task.id] ?? task.isTimerRunning) {
          debugPrint("Görev siliniyor ve timer çalışıyordu. Yerel timer state temizlenecek.");
          if (mounted) { setState(() { _localTimerRunningState.remove(task.id); }); }
        }
        await _firestoreService.deleteTask(task.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${task.title}" görevi silindi.'), backgroundColor: Theme.of(context).colorScheme.primary),
          );
        }
      } catch (e,s) {
        debugPrint("_deleteTask HATA: $e \nSTACKTRACE: $s");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silinirken hata: $e'), backgroundColor: Theme.of(context).colorScheme.error));
        }
      }
    }
  }

  void _handleStartTimer(Task task) async {
    debugPrint("_handleStartTimer. Task ID: ${task.id}");
    if (task.isDone || (_localTimerRunningState[task.id] ?? task.isTimerRunning)) {
      debugPrint("Timer başlatılamadı: Görev tamamlanmış veya timer zaten çalışıyor.");
      return;
    }

    final Timestamp newStartTime = Timestamp.now();
    try {
      await _firestoreService.startOrUpdateTimer(task.id, newStartTime, task.elapsedSeconds);
      if (mounted) {
        setState(() { _localTimerRunningState[task.id] = true; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${task.title}" için zamanlayıcı başlatıldı.'), backgroundColor: Colors.lightGreen.shade700),
        );
      }
    } catch (e,s) {
      debugPrint("_handleStartTimer HATA: $e \nSTACKTRACE: $s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Timer başlatılırken hata: $e'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  Future<void> _handleStopTimer(Task task, {bool taskCompleted = false}) async {
    debugPrint("_handleStopTimer. Task ID: ${task.id}, taskCompleted: $taskCompleted");

    if (!(_localTimerRunningState[task.id] ?? task.isTimerRunning)) {
      debugPrint("Timer zaten durmuş veya hiç başlamamış (yerel state'e göre). İşlem yapılmayacak.");
      return;
    }

    DocumentSnapshot<Task> docSnap;
    try {
      docSnap = await _firestoreService.getTaskDocument(task.id);
    } catch (e) {
      debugPrint("_handleStopTimer: Görev dokümanı alınırken hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Timer durdurulurken görev verisi alınamadı.'), backgroundColor: Theme.of(context).colorScheme.error));
      }
      return;
    }

    if (!docSnap.exists) {
      debugPrint("Timer durdurulacak görev Firestore'da bulunamadı. Task ID: ${task.id}");
      if (mounted) { setState(() { _localTimerRunningState[task.id] = false; }); }
      return;
    }

    final currentTaskData = docSnap.data();
    if (currentTaskData == null) {
      debugPrint("Timer durdurulacak görev verisi (data) null. Task ID: ${task.id}");
      if (mounted) { setState(() { _localTimerRunningState[task.id] = false; });}
      return;
    }

    int finalElapsedSeconds = currentTaskData.elapsedSeconds;
    if (currentTaskData.isTimerRunning && currentTaskData.startTime != null) {
      final now = Timestamp.now();
      final runningMillis = now.millisecondsSinceEpoch - currentTaskData.startTime!.millisecondsSinceEpoch;
      finalElapsedSeconds = currentTaskData.elapsedSeconds + (runningMillis > 0 ? (runningMillis / 1000).floor() : 0);
      debugPrint("Timer durduruluyor. Hesaplanan ek süre: ${(runningMillis / 1000).floor()}s. Toplam: ${finalElapsedSeconds}s");
    } else {
      debugPrint("Timer durduruluyor. Firestore'a göre timer zaten durmuş veya startTime null. Mevcut elapsedSeconds kullanılacak: ${finalElapsedSeconds}s");
    }

    try {
      await _firestoreService.stopTimer(task.id, finalElapsedSeconds, taskCompleted);
      if (mounted) {
        setState(() { _localTimerRunningState[task.id] = false; });
        if (!taskCompleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${task.title}" için zamanlayıcı durduruldu.'), backgroundColor: Colors.orangeAccent.shade700),
          );
        }
      }
    } catch (e,s) {
      debugPrint("_handleStopTimer HATA: $e \nSTACKTRACE: $s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Timer durdurulurken hata: $e'), backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  void _handleResetTimer(Task task) async {
    debugPrint("_handleResetTimer. Task ID: ${task.id}");
    bool confirmReset = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Zamanlayıcıyı Sıfırla'),
        content: Text('"${task.title}" görevinin zamanlayıcısını sıfırlamak istediğinizden emin misiniz?'),
        actions: <Widget>[
          TextButton(child: const Text('İptal'), onPressed: () => Navigator.of(context).pop(false)),
          TextButton(style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), child: const Text('Sıfırla'), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    ) ?? false;

    if (confirmReset) {
      try {
        await _firestoreService.resetTimer(task.id);
        if (mounted) {
          setState(() { _localTimerRunningState[task.id] = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${task.title}" için zamanlayıcı sıfırlandı.'), backgroundColor: Colors.blueGrey.shade700),
          );
        }
      } catch (e,s) {
        debugPrint("_handleResetTimer HATA: $e \nSTACKTRACE: $s");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Timer sıfırlanırken hata: $e'), backgroundColor: Theme.of(context).colorScheme.error));
        }
      }
    }
  }

  void _showPriorityPicker(Task task) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left:8.0),
                child: Text('Öncelik Seçin', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
              ),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: TaskPriority.values.map((priority) {
                  return ChoiceChip(
                    label: Text(priorityToStringRepresentation(priority)),
                    avatar: Icon(getPriorityIcon(priority), size: 18, color: task.priority == priority ? Colors.white : getPriorityColor(priority, context)),
                    selected: task.priority == priority,
                    selectedColor: getPriorityColor(priority, context),
                    backgroundColor: getPriorityColor(priority, context).withOpacity(0.1),
                    labelStyle: TextStyle(
                        color: task.priority == priority ? Colors.white : getPriorityColor(priority, context).withOpacity(0.9),
                        fontWeight: FontWeight.w500
                    ),
                    onSelected: (bool selected) async {
                      if (selected) {
                        Navigator.of(context).pop();
                        try {
                          await _firestoreService.updateTaskPriority(task.id, priority);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('"${task.title}" önceliği "${priorityToStringRepresentation(priority)}" olarak ayarlandı.'),
                                backgroundColor: getPriorityColor(priority, context),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Öncelik güncellenirken hata: $e'),
                                  backgroundColor: Theme.of(context).colorScheme.error),
                            );
                          }
                        }
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _navigateToCompletedTasks() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const CompletedTasksScreen()));
  }

  void _navigateToCalendarScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CalendarScreen()),
    );
  }

  // YENİ METOD - Odaklanma Süresi ekranına gitmek için
  void _navigateToFocusStatsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FocusStatsScreen()),
    );
  }

  Widget _buildFilterAndSortControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PopupMenuButton<TaskPriority>(
            initialValue: _selectedPriorityFilter,
            onSelected: (TaskPriority result) {
              if (_selectedPriorityFilter != result) {
                setState(() { _selectedPriorityFilter = result; });
                _loadInitialLocalTimerStates();
              }
            },
            itemBuilder: (BuildContext context) => TaskPriority.values.map((priority) {
              return PopupMenuItem<TaskPriority>(
                value: priority,
                child: Row(children: [
                  Icon(getPriorityIcon(priority), color: getPriorityColor(priority, context), size: 20),
                  const SizedBox(width: 8),
                  Text(priority == TaskPriority.none ? "Tümü" : priorityToStringRepresentation(priority)),
                  if (_selectedPriorityFilter == priority) ...[const SizedBox(width: 8), const Icon(Icons.check, size: 18)]
                ]),
              );
            }).toList(),
            child: Row(
              children: [
                Icon(Icons.filter_list_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  _selectedPriorityFilter == TaskPriority.none ? "Filtrele" : priorityToStringRepresentation(_selectedPriorityFilter),
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          PopupMenuButton<SortOption>(
            initialValue: _currentSortOption,
            onSelected: (SortOption result) {
              if (_currentSortOption != result) {
                setState(() { _currentSortOption = result; });
                _loadInitialLocalTimerStates();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
              const PopupMenuItem<SortOption>(value: SortOption.createdAtDesc, child: Text('Tarih (Yeni)')),
              const PopupMenuItem<SortOption>(value: SortOption.createdAtAsc, child: Text('Tarih (Eski)')),
              const PopupMenuItem<SortOption>(value: SortOption.priorityDesc, child: Text('Öncelik (Acil Üstte)')),
              const PopupMenuItem<SortOption>(value: SortOption.priorityAsc, child: Text('Öncelik (Düşük Üstte)')),
              const PopupMenuItem<SortOption>(value: SortOption.titleAsc, child: Text('Başlık (A-Z)')),
              const PopupMenuItem<SortOption>(value: SortOption.titleDesc, child: Text('Başlık (Z-A)')),
            ],
            child: Row(
              children: [
                Icon(Icons.sort_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 4),
                Text('Sırala', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Görevlerim'),
        actions: [
          IconButton( // YENİ: Odaklanma Süresi butonu
            icon: const Icon(Icons.bar_chart_rounded), // İkonu değiştirebilirsiniz
            tooltip: 'Odak Süreleri',
            onPressed: _navigateToFocusStatsScreen,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Takvim',
            onPressed: _navigateToCalendarScreen,
          ),
          IconButton(
            icon: const Icon(Icons.checklist_rtl_rounded),
            tooltip: 'Tamamlananlar',
            onPressed: _navigateToCompletedTasks,
          ),
        ],
        flexibleSpace: Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: [Colors.green.shade300, colorScheme.primary, colorScheme.secondary, Colors.pink.shade200, Colors.orange.shade300],
            gravity: 0.05, emissionFrequency: 0.03, numberOfParticles: 15, maxBlastForce: 20, minBlastForce: 8,
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Row(children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _taskController,
                  focusNode: _taskFocusNode,
                  decoration: const InputDecoration(hintText: 'Yeni bir görev yazın...'),
                  onSubmitted: (_) => _addTask(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(icon: const Icon(Icons.add_task_rounded), label: const Text('Ekle'), onPressed: _addTask),
            ]),
          ),
          _buildFilterAndSortControls(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Task>>(
              stream: _firestoreService.getPendingTasksStream(
                priorityFilter: _selectedPriorityFilter == TaskPriority.none ? null : _selectedPriorityFilter,
                sortOption: _currentSortOption,
              ),
              builder: (context, AsyncSnapshot<QuerySnapshot<Task>> snapshot) {
                if (snapshot.hasError) {
                  debugPrint("StreamBuilder HATA: ${snapshot.error} \nSTACKTRACE: ${snapshot.stackTrace}");
                  return Center(child: Text('Veri alınırken hata: ${snapshot.error}', textAlign: TextAlign.center, style: TextStyle(color: colorScheme.error)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 70, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              _selectedPriorityFilter == TaskPriority.none ? 'Henüz yapılacak görev yok.' : 'Bu filtreye uygun görev bulunamadı.',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600), textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text('Yeni bir görev ekleyerek başlayabilirsiniz!', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500), textAlign: TextAlign.center),
                          ],
                        ),
                      )
                  );
                }

                final taskDocs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 0, bottom: 80),
                  itemCount: taskDocs.length,
                  itemBuilder: (context, index) {
                    final task = taskDocs[index].data();
                    final bool isTimerEffectivelyRunning = _localTimerRunningState[task.id] ?? task.isTimerRunning;

                    return _TaskItemCard(
                      task: task,
                      isTimerEffectivelyRunning: isTimerEffectivelyRunning,
                      onToggleStatus: () => _toggleTaskStatus(task),
                      onStartTimer: () => _handleStartTimer(task),
                      onStopTimer: () => _handleStopTimer(task),
                      onResetTimer: () => _handleResetTimer(task),
                      onSetPriority: () => _showPriorityPicker(task),
                      onDelete: ({bool fromSlidable = false}) => _deleteTask(task, fromSlidable: fromSlidable),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskItemCard extends StatelessWidget {
  final Task task;
  final bool isTimerEffectivelyRunning;
  final VoidCallback onToggleStatus;
  final VoidCallback onStartTimer;
  final VoidCallback onStopTimer;
  final VoidCallback onResetTimer;
  final VoidCallback onSetPriority;
  final Function({bool fromSlidable}) onDelete;

  const _TaskItemCard({
    super.key,
    required this.task,
    required this.isTimerEffectivelyRunning,
    required this.onToggleStatus,
    required this.onStartTimer,
    required this.onStopTimer,
    required this.onResetTimer,
    required this.onSetPriority,
    required this.onDelete,
  });

  String _formatCreatedAt(dynamic createdAt, BuildContext context) {
    if (createdAt is Timestamp) {
      final date = createdAt.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final taskDate = DateTime(date.year, date.month, date.day);

      if (taskDate == today) {
        return "Bugün, ${DateFormat.Hm('tr_TR').format(date)}";
      } else if (taskDate == yesterday) {
        return "Dün, ${DateFormat.Hm('tr_TR').format(date)}";
      } else {
        return DateFormat('dd MMM, HH:mm', 'tr_TR').format(date);
      }
    }
    return "";
  }

  String _formatDueDate(Timestamp? dueDateTimestamp, BuildContext context) {
    if (dueDateTimestamp == null) return "";
    final date = dueDateTimestamp.toDate();
    return DateFormat.MMMMd('tr_TR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final priorityColor = getPriorityColor(task.priority, context);

    return Slidable(
      key: ValueKey(task.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) => onDelete(fromSlidable: true),
            backgroundColor: Colors.redAccent.shade200,
            foregroundColor: Colors.white,
            icon: Icons.delete_sweep_rounded,
            label: 'Sil',
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (context) => onSetPriority(),
            backgroundColor: colorScheme.secondary.withOpacity(0.8),
            foregroundColor: Colors.white,
            icon: Icons.flag_rounded,
            label: 'Öncelik',
          ),
          SlidableAction(
            onPressed: (context) => isTimerEffectivelyRunning ? onStopTimer() : onStartTimer(),
            backgroundColor: isTimerEffectivelyRunning ? Colors.orangeAccent.shade400 : Colors.green.shade400,
            foregroundColor: Colors.white,
            icon: isTimerEffectivelyRunning ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
            label: isTimerEffectivelyRunning ? 'Durdur' : 'Başlat',
            borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
          ),
        ],
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 50,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: 1.1,
                      child: Checkbox(value: task.isDone, onChanged: (bool? value) => onToggleStatus()),
                    ),
                    const SizedBox(height: 4),
                    if(task.priority != TaskPriority.none)
                      Tooltip(message: priorityToStringRepresentation(task.priority), child: Icon(getPriorityIcon(task.priority), color: priorityColor, size: 20))
                    else const SizedBox(height:20),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4.0, right: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: task.isDone ? TextDecoration.lineThrough : TextDecoration.none,
                                color: task.isDone ? Colors.grey.shade600 : colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (task.dueDate != null && !task.isDone)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 12, color: colorScheme.primary.withOpacity(0.8)),
                                  const SizedBox(width: 3),
                                  Text(
                                    _formatDueDate(task.dueDate, context),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isTimerEffectivelyRunning ? Icons.pause_circle_outline_rounded : (task.elapsedSeconds > 0 ? Icons.play_circle_outline_rounded : Icons.timer_outlined),
                                size: 18, color: isTimerEffectivelyRunning ? colorScheme.primary : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 5),
                              TaskTimerDisplay(
                                initialStartTime: task.startTime,
                                initialElapsedSeconds: task.elapsedSeconds,
                                isInitiallyRunning: isTimerEffectivelyRunning,
                              ),
                            ],
                          ),
                          if (task.createdAt != null)
                            Text(_formatCreatedAt(task.createdAt, context), style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade500, fontSize: 11)),
                        ],
                      ),
                      if (!isTimerEffectivelyRunning && task.elapsedSeconds > 0 && !task.isDone)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            icon: Icon(Icons.replay_rounded, size: 14, color: colorScheme.secondary),
                            label: Text("Sıfırla", style: TextStyle(fontSize: 11, color: colorScheme.secondary, fontWeight: FontWeight.w500)),
                            onPressed: onResetTimer,
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), minimumSize: const Size(40, 20), tapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!task.isDone)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600),
                  tooltip: "Seçenekler",
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    if (!isTimerEffectivelyRunning)
                      PopupMenuItem<String>(value: 'start_timer', child: ListTile(leading: Icon(Icons.play_arrow_rounded, color: Colors.green.shade600), title: const Text('Başlat'))),
                    if (isTimerEffectivelyRunning)
                      PopupMenuItem<String>(value: 'stop_timer', child: ListTile(leading: Icon(Icons.pause_rounded, color: Colors.orange.shade600), title: const Text('Durdur'))),
                    if (task.elapsedSeconds > 0 && !isTimerEffectivelyRunning)
                      PopupMenuItem<String>(value: 'reset_timer', child: ListTile(leading: Icon(Icons.replay_rounded, color: Colors.blueGrey.shade600), title: const Text('Sıfırla'))),
                    if (task.elapsedSeconds > 0) const PopupMenuDivider(),
                    PopupMenuItem<String>(value: 'set_priority', child: ListTile(leading: Icon(Icons.flag_outlined, color: colorScheme.primary), title: const Text('Öncelik Ata'))),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline_rounded, color: colorScheme.error), title: const Text('Sil'))),
                  ],
                  onSelected: (String value) {
                    if (value == 'delete') onDelete(fromSlidable: false);
                    else if (value == 'start_timer') onStartTimer();
                    else if (value == 'stop_timer') onStopTimer();
                    else if (value == 'reset_timer') onResetTimer();
                    else if (value == 'set_priority') onSetPriority();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TaskTimerDisplay extends StatefulWidget {
  final Timestamp? initialStartTime;
  final int initialElapsedSeconds;
  final bool isInitiallyRunning;

  const TaskTimerDisplay({
    super.key,
    this.initialStartTime,
    required this.initialElapsedSeconds,
    required this.isInitiallyRunning,
  });

  @override
  State<TaskTimerDisplay> createState() => _TaskTimerDisplayState();
}

class _TaskTimerDisplayState extends State<TaskTimerDisplay> {
  Timer? _timer;
  late int _currentElapsedSeconds;
  late bool _isRunning;

  @override
  void initState() {
    super.initState();
    _isRunning = widget.isInitiallyRunning;
    _currentElapsedSeconds = widget.initialElapsedSeconds;

    if (_isRunning && widget.initialStartTime != null) {
      final now = Timestamp.now();
      final diffMillis = now.millisecondsSinceEpoch - widget.initialStartTime!.millisecondsSinceEpoch;
      _currentElapsedSeconds = widget.initialElapsedSeconds + (diffMillis > 0 ? (diffMillis / 1000).floor() : 0);
    }

    if (_isRunning) {
      _startLocalTimer();
    }
  }

  @override
  void didUpdateWidget(covariant TaskTimerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    _isRunning = widget.isInitiallyRunning;
    _currentElapsedSeconds = widget.initialElapsedSeconds;

    if (_isRunning && widget.initialStartTime != null) {
      final now = Timestamp.now();
      final diffMillis = now.millisecondsSinceEpoch - widget.initialStartTime!.millisecondsSinceEpoch;
      _currentElapsedSeconds = widget.initialElapsedSeconds + (diffMillis > 0 ? (diffMillis / 1000).floor() : 0);
    }

    if (_isRunning) {
      _startLocalTimer();
    } else {
      _stopLocalTimer();
    }
  }

  void _startLocalTimer() {
    _timer?.cancel();
    if (!_isRunning || !mounted) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isRunning) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          _currentElapsedSeconds++;
        });
      }
    });
  }

  void _stopLocalTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "$hours:$minutes:$seconds";
    }
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatDuration(_currentElapsedSeconds),
      style: TextStyle(
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(_isRunning ? 0.9 : 0.7),
        fontWeight: _isRunning ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}