// lib/firestore_test_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreTestPage extends StatefulWidget {
  const FirestoreTestPage({super.key});

  @override
  State<FirestoreTestPage> createState() => _FirestoreTestPageState();
}

class _FirestoreTestPageState extends State<FirestoreTestPage> {
  // Firestore instance'ını alıyoruz
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Test verisi eklemek için fonksiyon
  Future<void> _addTestData() async {
    try {
      // 'test_items' adında bir koleksiyona basit bir belge ekleyelim
      // Eğer 'test_items' koleksiyonu yoksa, Firestore otomatik oluşturur.
      await _firestore.collection('test_items').add({
        'name': 'Test Öğesi',
        'timestamp': Timestamp.now(), // Ne zaman eklendiğini görelim
        'value': DateTime.now().millisecondsSinceEpoch, // Benzersiz bir değer
      });
      print('Basariyla test derisive eklendi!');
      // Kullanıcıya geri bildirim vermek için ScaffoldMessenger kullanabiliriz
      if (mounted) { // Widget hala ağaçtaysa işlem yap
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test verisi Firestore\'a eklendi!')),
        );
      }
    } catch (e) {
      print('Hata oluştu (Veri Ekleme): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Test Sayfası'),
      ),
      body: Column(
        children: [
          // Veri Ekleme Butonu
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _addTestData, // Butona basıldığında fonksiyonu çağır
              child: const Text('Firestore\'a Test Verisi Ekle'),
            ),
          ),

          const Divider(), // Ayırıcı çizgi

          // Firestore'dan Veri Okuma Alanı (StreamBuilder ile)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "'test_items' Koleksiyonundaki Veriler:",
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // 'test_items' koleksiyonundaki değişiklikleri dinle
              stream: _firestore.collection('test_items').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                // Bağlantı bekleniyorsa
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Hata varsa
                if (snapshot.hasError) {
                  return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
                }
                // Veri yoksa veya boşsa
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Firestore\'da \'test_items\' koleksiyonunda veri yok.'));
                }

                // Veri varsa listele
                final items = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final data = item.data() as Map<String, dynamic>;
                    final name = data['name'] as String? ?? 'İsimsiz';
                    // Timestamp'ı daha okunabilir bir formata çevirelim (opsiyonel)
                    final timestamp = data['timestamp'] as Timestamp?;
                    final timeString = timestamp != null
                        ? timestamp.toDate().toLocal().toString()
                        : 'Zaman yok';

                    return ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(name),
                      subtitle: Text('Eklendi: $timeString\nID: ${item.id}'), // Belge ID'sini de gösterelim
                      isThreeLine: true,
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