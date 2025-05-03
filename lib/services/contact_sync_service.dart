// lib/services/contact_sync_service.dart
import 'dart:convert';
import 'package:flutter/material.dart'; // Dibutuhkan untuk BuildContext jika ada interaksi UI
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class ContactSyncService {
  // Ganti dengan URL Backend API Anda yang SEBENARNYA
  // Jika testing di emulator Android, pakai 10.0.2.2 untuk akses localhost PC
  // Jika testing di device fisik, pakai IP Address lokal PC Anda (pastikan satu jaringan)
  // atau URL publik jika backend di-deploy online.
  final String _apiUrl = 'https://mitrautamateknologi.co-id.id/api/kontak.php'; // CONTOH! Ganti ini

  // --- 1. Request Permission ---
  Future<bool> requestContactsPermission() async {
    var status = await Permission.contacts.status;
    if (status.isGranted) return true;

    var requestedStatus = await Permission.contacts.request();
    if (requestedStatus.isGranted) return true;

    if (await Permission.contacts.isPermanentlyDenied) {
      print("Izin kontak ditolak permanen.");
      // Pertimbangkan openAppSettings();
    } else {
      print("Izin kontak ditolak.");
    }
    return false;
  }

  // --- 2. Fetch Contacts ---
  Future<List<Map<String, dynamic>>> fetchContactsFromPhone() async {
    List<Map<String, dynamic>> contactListForServer = [];
    Set<String> uniqueHashedNumbers = {}; // Untuk menghindari duplikat hash

    try {
      if (!await Permission.contacts.isGranted) {
        print("Izin kontak belum ada saat fetch.");
        return [];
      }

      // Ambil kontak tanpa thumbnail untuk efisiensi awal
      List<Contact> contacts = await ContactsService.getContacts(
        withThumbnails: false,
      );

      for (var contact in contacts) {
        if (contact.phones != null && contact.phones!.isNotEmpty) {
          for (var phone in contact.phones!) {
            String? phoneNumber = phone.value;
            if (phoneNumber != null) {
              String normalizedNumber = _normalizePhoneNumber(phoneNumber);
              if (normalizedNumber.isNotEmpty) {
                String hashedNumber = _hashPhoneNumber(normalizedNumber);
                // Hanya tambahkan jika hash unik
                if (uniqueHashedNumbers.add(hashedNumber)) {
                    contactListForServer.add({
                        'displayName': contact.displayName ?? '',
                        'hashedNumber': hashedNumber,
                    });
                }
                // Jika ingin ambil SEMUA nomor valid per kontak (bukan hanya yg unik pertama):
                // Hapus break di bawah dan modifikasi logika uniqueHashedNumbers jika perlu
                // atau biarkan backend menangani duplikat hash per user.
                 break; // Ambil nomor valid pertama per kontak saja (lebih simpel)
              }
            }
          }
        }
      }
       print("Ditemukan ${contactListForServer.length} nomor kontak unik (hashed) untuk dikirim.");
    } catch (e) {
      print("Error fetch contacts: $e");
    }
    return contactListForServer;
  }

  // --- 3. Send Contacts to Backend ---
  Future<Map<String, dynamic>> sendContactsToBackend(List<Map<String, dynamic>> contacts) async {
    // --- PENTING: Autentikasi ---
    // Anda HARUS menyertakan cara backend mengenali user.
    // Contoh paling sederhana (TIDAK AMAN untuk produksi): kirim user_id
    // int userId = 1; // Ganti dengan user ID yang login sebenarnya
    // String requestBody = jsonEncode({'userId': userId, 'contacts': contacts});
    // Atau (Lebih Baik): Gunakan token di header
    // String? token = await SecureStorageService.getToken(); // Contoh
    // if (token == null) return {'success': false, 'message': 'User not authenticated'};
    Map<String, String> headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      // 'Authorization': 'Bearer $token', // Sertakan token jika pakai
    };
    // --- Akhir Autentikasi ---

     // Tambahkan parameter action=save_contacts ke URL
     var url = Uri.parse("$_apiUrl?action=save_contacts");


    try {
      // Kirim data kontak sebagai JSON di body POST request
      var response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(contacts), // Kirim HANYA list kontak di body
      );

      print('Send Contacts - Status Code: ${response.statusCode}');
      print('Send Contacts - Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
             return jsonDecode(response.body); // Kembalikan respon JSON dari PHP
        } catch (e) {
             return {'success': false, 'message': 'Format respon backend tidak valid (bukan JSON).', 'body': response.body};
        }
      } else {
        // Tangani error HTTP lainnya
         return {'success': false, 'message': 'Error HTTP ${response.statusCode} dari server.', 'body': response.body};
      }
    } catch (e) {
      print('Error sending contacts: $e');
      return {'success': false, 'message': 'Koneksi ke server gagal: $e'};
    }
  }

  // --- Helper Functions ---
  String _normalizePhoneNumber(String phone) {
    // Implementasi normalisasi (sama seperti di PHP)
    String normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (normalized.startsWith('+62')) {
      normalized = '0' + normalized.substring(3);
    } else if (normalized.startsWith('62')) {
       normalized = '0' + normalized.substring(2);
    }
    normalized = normalized.replaceAll(RegExp(r'[^\d]'), '');
    if (normalized.length < 8) return ''; // Anggap nomor pendek tidak valid
    return normalized;
  }

  String _hashPhoneNumber(String phone) {
    // Implementasi hashing SHA-256 (sama seperti di PHP jika perlu dicocokkan)
    var bytes = utf8.encode(phone);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
}