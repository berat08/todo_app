//models//task_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  String id;
  String title;
  bool isDone;
  Timestamp createdAt; // Artık null olamaz, Firestore'dan her zaman gelecek veya oluşturulurken atanacak

  Task({
    required this.id,
    required this.title,
    this.isDone = false,
    required this.createdAt,
  });

  // Firestore'dan gelen Map'i Task nesnesine dönüştürmek için factory constructor
  factory Task.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options,
      ) {
    final data = snapshot.data();
    return Task(
      id: snapshot.id,
      title: data?['title'] ?? 'Başlıksız Görev', // Varsayılan değer
      isDone: data?['isDone'] ?? false,
      createdAt: data?['createdAt'] ?? Timestamp.now(), // Varsayılan değer (normalde olmamalı)
    );
  }

  // Task nesnesini Firestore'a yazılacak Map'e dönüştürmek için
  Map<String, dynamic> toFirestore() {
    return {
      "title": title,
      "isDone": isDone,
      // createdAt alanı Firestore'a yazılırken FieldValue.serverTimestamp()
      // ile yönetilecekse burada null bırakılabilir veya sadece okunurken kullanılır.
      // Yeni görev eklerken createdAt'i FieldValue.serverTimestamp() olarak ayarlayacağız.
      // Güncelleme yaparken bu alanı genellikle değiştirmeyiz.
      // Eğer ilk oluşturmada client tarafında bir zaman damgası atamak isterseniz:
      // "createdAt": createdAt,
      // Ama genellikle sunucu zamanı tercih edilir.
      // Bu yüzden toFirestore'da createdAt'i şimdilik dışarıda bırakıyorum,
      // ekleme sırasında özel olarak eklenecek.
      // Ya da her zaman güncellenmesini istiyorsak:
      // if (createdAt != null) "createdAt": createdAt,
    };
  }
}