// lib/main.dart
import 'package:flutter/material.dart';
import 'services/contact_sync_service.dart'; // Import service yang baru dibuat

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kontak Chat App Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ContactSyncPage(), // Halaman utama kita
    );
  }
}

class ContactSyncPage extends StatefulWidget {
  @override
  _ContactSyncPageState createState() => _ContactSyncPageState();
}

class _ContactSyncPageState extends State<ContactSyncPage> {
  bool _isSyncing = false;
  String _status = 'Tekan tombol untuk sinkronisasi kontak';
  final ContactSyncService _syncService = ContactSyncService();
  int _processedCount = 0;
  int _errorCount = 0;

  Future<void> _syncContacts() async {
    setState(() {
      _isSyncing = true;
      _status = '1/3 Meminta izin kontak...';
      _processedCount = 0;
      _errorCount = 0;
    });

    bool permissionGranted = await _syncService.requestContactsPermission();

    if (!mounted) return; // Cek jika widget masih ada

    if (!permissionGranted) {
      setState(() {
        _isSyncing = false;
        _status = 'Izin kontak ditolak. Sinkronisasi dibatalkan.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Izin kontak diperlukan.')),
       );
      return;
    }

    setState(() { _status = '2/3 Mengambil kontak dari telepon...'; });
    List<Map<String, dynamic>> contactsToSync = await _syncService.fetchContactsFromPhone();

     if (!mounted) return;

    if (contactsToSync.isEmpty) {
       setState(() {
        _isSyncing = false;
        _status = 'Tidak ada kontak valid ditemukan atau izin error.';
      });
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Tidak ada kontak yang bisa disinkronkan.')),
       );
      return;
    }

    setState(() { _status = '3/3 Mengirim ${contactsToSync.length} kontak ke server...'; });
    Map<String, dynamic> result = await _syncService.sendContactsToBackend(contactsToSync);

     if (!mounted) return;

    setState(() {
      _isSyncing = false;
      if (result['success'] == true) {
           _processedCount = result['processed_count'] ?? 0;
           _errorCount = result['error_count'] ?? 0;
           _status = 'Sinkronisasi Selesai! (${_processedCount} diproses, ${_errorCount} error)';
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Sinkronisasi Selesai!'), backgroundColor: Colors.green),
           );
      } else {
          _status = 'Sinkronisasi Gagal: ${result['message'] ?? 'Error tidak diketahui'}';
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Sinkronisasi Gagal.'), backgroundColor: Colors.red),
           );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text('Flutter Kontak Sync Demo'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary, // Contoh styling appbar
       ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 30),
              _isSyncing
                  ? CircularProgressIndicator()
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          textStyle: TextStyle(fontSize: 16)
                      ),
                      icon: Icon(Icons.sync),
                      label: Text('Mulai Sinkronisasi Kontak'),
                      onPressed: _syncContacts, // Panggil fungsi sync
                    ),
            ],
          ),
        ),
      ),
    );
  }
}