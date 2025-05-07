// lib/screens/focus_stats_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/task_model.dart';
import '../services/firestore_service.dart';

class FocusStatsScreen extends StatefulWidget {
  const FocusStatsScreen({super.key});

  @override
  State<FocusStatsScreen> createState() => _FocusStatsScreenState();
}

class _FocusStatsScreenState extends State<FocusStatsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  DateTime _selectedDate = DateTime.now(); // Başlangıçta bugünü göster
  List<Task> _tasksForSelectedDay = [];
  int _totalFocusMinutesToday = 0;

  @override
  void initState() {
    super.initState();
    _loadTasksForDate(_selectedDate);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)), // Gelecek bir yıla kadar seçilebilir
      locale: const Locale('tr', 'TR'), // Türkçe takvim
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadTasksForDate(picked);
    }
  }

  void _loadTasksForDate(DateTime date) async {
    // Tarihin başlangıcını ve sonunu al (00:00:00 - 23:59:59)
    DateTime startDate = DateTime(date.year, date.month, date.day);
    DateTime endDate = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    // Firestore Timestamp'e çevir
    Timestamp startTimestamp = Timestamp.fromDate(startDate);
    Timestamp endTimestamp = Timestamp.fromDate(endDate);

    // Belirtilen tarihte tamamlanmış ve süresi olan görevleri çek
    // Bu stream'i dinleyerek anlık güncellemeler alabiliriz.
    _firestoreService
        .getCompletedTasksByDateRangeStream(startTimestamp, endTimestamp)
        .listen((snapshot) {
      if (!mounted) return;

      int totalMinutes = 0;
      List<Task> tasks = [];

      for (var doc in snapshot.docs) {
        final task = doc.data();
        // Sadece elapsedSeconds > 0 olanları dikkate al
        if (task.isDone && task.elapsedSeconds > 0) {
          tasks.add(task);
          totalMinutes += (task.elapsedSeconds / 60).round(); // Saniyeyi dakikaya çevir ve yuvarla
        }
      }

      setState(() {
        _tasksForSelectedDay = tasks;
        // Eğer seçili tarih bugünse, bugünün toplam odaklanma süresini güncelle
        if (DateUtils.isSameDay(_selectedDate, DateTime.now())) {
          _totalFocusMinutesToday = totalMinutes;
        } else if (tasks.isNotEmpty) { // Başka bir gün seçildiyse ve görev varsa, o günün toplamını göster
          _totalFocusMinutesToday = totalMinutes; // Bu değişkeni o günün toplamı için kullanalım
        } else {
          _totalFocusMinutesToday = 0;
        }
      });
    });
  }

  String _formatDurationFromSeconds(int totalSeconds) {
    if (totalSeconds <= 0) return "0 dk";
    final duration = Duration(seconds: totalSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    String result = "";
    if (hours > 0) {
      result += "${hours} sa ";
    }
    if (minutes > 0 || hours == 0) { // Eğer saat 0 ise dakikayı göster
      result += "${minutes} dk";
    }
    return result.trim().isEmpty ? "0 dk" : result.trim();
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    bool isTodaySelected = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text(isTodaySelected ? "Bugünün Odaklanma Süresi" : "${DateFormat.yMMMMd('tr_TR').format(_selectedDate)} Odak Süresi"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: "Tarih Seç",
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              color: colorScheme.primaryContainer.withOpacity(0.8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isTodaySelected ? "Bugünkü Toplam Odak:" : "Seçili Gün Toplam:",
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      _formatDurationFromSeconds(_totalFocusMinutesToday * 60), // Dakikayı saniyeye çevirerek formatla
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Tamamlanan Görevler (${DateFormat.yMMMMd('tr_TR').format(_selectedDate)})",
              style: textTheme.titleLarge?.copyWith(color: colorScheme.primary, fontSize: 20),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _tasksForSelectedDay.isEmpty
                  ? Center(
                  child: Text(
                    "Bu tarih için süresi kaydedilmiş tamamlanmış görev bulunamadı.",
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                  ))
                  : ListView.builder(
                itemCount: _tasksForSelectedDay.length,
                itemBuilder: (context, index) {
                  final task = _tasksForSelectedDay[index];
                  return Card(
                    elevation: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: getPriorityColor(task.priority, context).withOpacity(0.5), width: 1)
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${(task.elapsedSeconds / 60).round()} dakika", // Süreyi dakika cinsinden göster
                            style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.85)
                            ),
                          ),
                          if (task.priority != TaskPriority.none) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(getPriorityIcon(task.priority), size: 16, color: getPriorityColor(task.priority, context)),
                                const SizedBox(width: 4),
                                Text(
                                  priorityToStringRepresentation(task.priority),
                                  style: textTheme.bodySmall?.copyWith(color: getPriorityColor(task.priority, context), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ]
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}