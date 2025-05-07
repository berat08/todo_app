// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// import 'package:cloud_firestore/cloud_firestore.dart'; // MyApp içinde doğrudan kullanılmıyorsa kaldırılabilir
// import 'firestore_test_page.dart'; // Artık ana sayfa bu olmayacak

import 'ekran.dart'; // TodoListScreen sınıfının bu dosyada olduğunu varsayıyoruz

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter To-Do Listesi (Firestore)', // Başlığı güncelleyebilirsin
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 2,
          centerTitle: true,
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.indigoAccent,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardTheme(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        ),
        listTileTheme: const ListTileThemeData(
          dense: true,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.indigoAccent, width: 2.0),
          ),
          hintStyle: TextStyle(color: Colors.grey),
        ),
      ),
      // home: const FirestoreTestPage(), // ESKİ SATIR - YORUM SATIRI YAPILDI VEYA SİLİNDİ
      home: const TodoListScreen(),   // YENİ SATIR - Uygulamanın ana ekranı olarak TodoListScreen ayarlandı
      debugShowCheckedModeBanner: false,
    );
  }
}