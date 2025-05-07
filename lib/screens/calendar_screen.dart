// lib/screens/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Timestamp için

import '../models/task_model.dart';
import '../services/firestore_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Görevleri ve o günkü görevleri tutmak için
  Map<DateTime, List<Task>> _events = {};
  List<Task> _selectedDayTasks = [];

  // Görev ekleme için controller
  final TextEditingController _newEventController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadFirestoreEvents();
  }

  @override
  void dispose() {
    _newEventController.dispose();
    super.dispose();
  }

  void _loadFirestoreEvents() async {
    // Tüm görevleri çek (dueDate olanları)
    // Bu stream'i dinleyerek _events map'ini güncelleyeceğiz.
    // Şimdilik basit bir .get() ile alalım, sonra stream'e çevrilebilir.
    _firestoreService.getAllTasksWithDueDateStream().listen((snapshot) {
      if (!mounted) return;
      final Map<DateTime, List<Task>> newEvents = {};
      for (var doc in snapshot.docs) {
        final task = doc.data();
        if (task.dueDate != null) {
          // Timestamp'ı DateTime'a çevir ve saat, dakika, saniye bilgilerini sıfırla
          // Böylece sadece gün bazında karşılaştırma yapılır.
          final date = task.dueDate!.toDate();
          final dayOnly = DateTime(date.year, date.month, date.day);

          if (newEvents[dayOnly] == null) {
            newEvents[dayOnly] = [];
          }
          newEvents[dayOnly]!.add(task);
        }
      }
      setState(() {
        _events = newEvents;
        _onDaySelected(_selectedDay!, _focusedDay); // Seçili günün görevlerini güncelle
      });
    });
  }

  List<Task> _getEventsForDay(DateTime day) {
    // Saat, dakika, saniye bilgilerini sıfırlayarak karşılaştır
    final dayOnly = DateTime(day.year, day.month, day.day);
    return _events[dayOnly] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay; // Takvimin odaklandığı günü de güncelle
        _selectedDayTasks = _getEventsForDay(selectedDay);
      });
    }
  }

  void _showAddTaskDialog(DateTime date) {
    _newEventController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${DateFormat.yMMMMd('tr_TR').format(date)} için Yeni Görev"),
        content: TextField(
          controller: _newEventController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Görev başlığı"),
        ),
        actions: [
          TextButton(
            child: const Text("İptal"),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Ekle"),
            onPressed: () async {
              if (_newEventController.text.isEmpty) return;
              try {
                // Firestore'a dueDate'i Timestamp olarak kaydet
                await _firestoreService.addTask(
                  _newEventController.text,
                  dueDate: Timestamp.fromDate(date),
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Görev eklendi: ${_newEventController.text}")),
                  );
                  // _loadFirestoreEvents(); // Stream dinlediğimiz için otomatik güncellenecek
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Görev eklenirken hata: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Görev Takvimim"),
        leading: IconButton( // Geri butonu
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          TableCalendar<Task>(
            locale: 'tr_TR', // Türkçe lokasyon
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            eventLoader: _getEventsForDay, // Her gün için olayları yükler
            startingDayOfWeek: StartingDayOfWeek.monday, // Haftanın başlangıç günü
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false, // Geçmiş/gelecek ayların günlerini gizle
              todayDecoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration( // Görev olan gün için işaretleyici
                color: Colors.red.withOpacity(0.7), // Saydam kırmızı
                shape: BoxShape.circle,
              ),
              markerSize: 6.0,
              markersAlignment: Alignment.bottomCenter,
              markersMaxCount: 1, // Her gün için max 1 marker göster
              weekendTextStyle: TextStyle(color: colorScheme.secondary.withOpacity(0.8)),
              holidayTextStyle: TextStyle(color: Colors.red.shade700), // Resmi tatiller için (eğer tanımlanırsa)
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true, // Ay/Hafta/2 Hafta format butonu
              titleCentered: true,
              titleTextStyle: textTheme.titleLarge!.copyWith(color: colorScheme.primary, fontSize: 18),
              formatButtonTextStyle: TextStyle(color: colorScheme.onPrimary),
              formatButtonDecoration: BoxDecoration(
                color: colorScheme.secondary,
                borderRadius: BorderRadius.circular(16.0),
              ),
              leftChevronIcon: Icon(Icons.chevron_left, color: colorScheme.primary),
              rightChevronIcon: Icon(Icons.chevron_right, color: colorScheme.primary),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontWeight: FontWeight.w500, color: colorScheme.onSurface.withOpacity(0.7)),
              weekendStyle: TextStyle(fontWeight: FontWeight.w500, color: colorScheme.secondary.withOpacity(0.9)),
            ),
            onDaySelected: _onDaySelected,
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay; // Sayfa değiştiğinde odaklanan günü güncelle
            },
            // Görev olan günlerin arka planını değiştirmek için calendarBuilders
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  // Saat, dakika, saniye bilgilerini sıfırla
                  final dayOnly = DateTime(date.year, date.month, date.day);
                  final hasEvent = _events.containsKey(dayOnly) && _events[dayOnly]!.isNotEmpty;

                  if (hasEvent) {
                    return Positioned(
                      bottom: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(0.7), // Saydam kırmızı nokta
                        ),
                        width: 7.0,
                        height: 7.0,
                      ),
                    );
                  }
                }
                return null;
              },
              // Seçili günün arka planını değiştirmek için (isteğe bağlı)
              // selectedBuilder: (context, date, focusedDate) {
              //   final dayOnly = DateTime(date.year, date.month, date.day);
              //   final hasEvent = _events.containsKey(dayOnly) && _events[dayOnly]!.isNotEmpty;
              //   return Container(
              //     margin: const EdgeInsets.all(4.0),
              //     alignment: Alignment.center,
              //     decoration: BoxDecoration(
              //       color: hasEvent ? Colors.red.withOpacity(0.2) : Theme.of(context).primaryColor, // Görev varsa kırmızımsı
              //       shape: BoxShape.circle,
              //     ),
              //     child: Text(
              //       '${date.day}',
              //       style: TextStyle().copyWith(color: Colors.white),
              //     ),
              //   );
              // },
            ),
          ),
          const SizedBox(height: 12.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDay != null ? "${DateFormat.yMMMMd('tr_TR').format(_selectedDay!)} Görevleri" : "Bir gün seçin",
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (_selectedDay != null)
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: colorScheme.primary, size: 28),
                    tooltip: "Bu güne görev ekle",
                    onPressed: () => _showAddTaskDialog(_selectedDay!),
                  )
              ],
            ),
          ),
          Expanded(
            child: _selectedDayTasks.isEmpty
                ? Center(child: Text("Bu gün için planlanmış görev yok.", style: textTheme.bodyMedium?.copyWith(color: Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              itemCount: _selectedDayTasks.length,
              itemBuilder: (context, index) {
                final task = _selectedDayTasks[index];
                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    leading: Checkbox( // Basit bir checkbox, ana ekrandaki gibi detaylı değil
                      value: task.isDone,
                      onChanged: (bool? value) async {
                        await _firestoreService.toggleTaskStatus(task.id, task.isDone);
                        // _loadFirestoreEvents(); // Stream dinlediğimiz için otomatik güncellenecek
                      },
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration: task.isDone ? TextDecoration.lineThrough : null,
                        color: task.isDone ? Colors.grey : null,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red.withOpacity(0.7)),
                      onPressed: () async {
                        await _firestoreService.deleteTask(task.id);
                        // _loadFirestoreEvents(); // Stream dinlediğimiz için otomatik güncellenecek
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}