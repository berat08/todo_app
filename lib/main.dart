// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'ekran.dart'; // TodoListScreen

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase.initializeApp HATA: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF5E35B1); // Koyu Mor
    const secondaryColor = Color(0xFF7E57C2); // Açık Mor
    const backgroundColor = Color(0xFFF3E5F5); // Çok Açık Leylak/Mor
    const surfaceColor = Colors.white;
    const onSurfaceColor = Colors.black87; // Yüzey üzerindeki metinler için ana renk
    const onBackgroundColor = Colors.black87; // Arka plan üzerindeki metinler için ana renk

    final baseTheme = ThemeData.light(useMaterial3: true);

    return MaterialApp(
      title: 'Görev Yöneticim',
      theme: baseTheme.copyWith(
          primaryColor: primaryColor,
          scaffoldBackgroundColor: backgroundColor,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryColor,
            primary: primaryColor,
            secondary: secondaryColor,
            surface: surfaceColor,
            background: backgroundColor,
            error: Colors.redAccent.shade200,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: onSurfaceColor, // Tanımlandı
            onBackground: onBackgroundColor, // Tanımlandı
            onError: Colors.white,
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.poppinsTextTheme(baseTheme.textTheme).copyWith(
            // Genel metin stillerinde renkleri colorScheme'den almak daha esnek olabilir
            titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 22, color: primaryColor),
            titleMedium: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 18, color: onSurfaceColor.withOpacity(0.85)), // Biraz daha belirgin
            bodyLarge: GoogleFonts.poppins(fontSize: 16, color: onSurfaceColor.withOpacity(0.8)),
            bodyMedium: GoogleFonts.poppins(fontSize: 14, color: onSurfaceColor.withOpacity(0.75)),
            labelLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white), // ElevatedButton içindeki label için
          ),
          appBarTheme: AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            titleTextStyle: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: secondaryColor,
              foregroundColor: Colors.white, // labelLarge'daki renk bunu ezecek
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600), // labelLarge'daki font bunu ezecek
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          cardTheme: CardTheme(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            color: surfaceColor,
          ),
          // InputDecorationTheme GÜNCELLENDİ
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: surfaceColor.withOpacity(0.9), // Biraz daha opak olabilir
            hintStyle: TextStyle(color: onSurfaceColor.withOpacity(0.5), fontWeight: FontWeight.normal), // Hint text rengi daha belirgin
            // Girilen metnin stili için (eğer TextField'da ayrıca style verilmemişse)
            labelStyle: TextStyle(color: onSurfaceColor.withOpacity(0.7)), // Label için (kullanılıyorsa)
            // Eğer TextField'a girilen metnin rengini de buradan kontrol etmek isterseniz,
            // bir `style` parametresi ekleyemezsiniz ama `ekran.dart` içindeki
            // TextField'a doğrudan `style: TextStyle(color: onSurfaceColor)` ekleyebilirsiniz.
            // Ya da textTheme.bodyLarge/bodyMedium renklerini daha koyu yapabilirsiniz.
            // Şimdilik hintStyle'a odaklandık.
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none, // Kenarlık yok
            ),
            enabledBorder: OutlineInputBorder( // Normal durumdaki kenarlık (isteğe bağlı, hafif bir çizgi eklenebilir)
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: primaryColor, width: 2.0),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          ),
          checkboxTheme: CheckboxThemeData(
            // ... (checkboxTheme aynı kalabilir) ...
          ),
          listTileTheme: ListTileThemeData(
            // ... (listTileTheme aynı kalabilir) ...
          ),
          dialogTheme: DialogTheme(
            // ... (dialogTheme aynı kalabilir) ...
          ),
          snackBarTheme: SnackBarThemeData(
            // ... (snackBarTheme aynı kalabilir) ...
          ),
          popupMenuTheme: PopupMenuThemeData(
            // ... (popupMenuTheme aynı kalabilir) ...
          ),
          bottomSheetTheme: BottomSheetThemeData(
            // ... (bottomSheetTheme aynı kalabilir) ...
          )
      ),
      home: const TodoListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}