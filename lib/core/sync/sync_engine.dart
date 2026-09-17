import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../network/api_client.dart';

class SyncEngine {
  final AppDatabase db;
  final ApiClient api;
  final Connectivity connectivity;
  bool _isSyncing = false;

  SyncEngine({
    required this.db,
    required this.api,
    required this.connectivity,
  });

  /// Digunakan oleh fitur/modul ketika ada data baru yang disimpan offline (Contoh: Transaksi Baru)
  Future<void> enqueue({
    required String entity,
    required String action, // CREATE, UPDATE, DELETE
    required Map<String, dynamic> payload,
  }) async {
    await db.into(db.syncQueue).insert(
      SyncQueueCompanion.insert(
        id: 'SQ-${DateTime.now().millisecondsSinceEpoch}', // Harusnya UUID
        entity: entity,
        action: action,
        payload: jsonEncode(payload),
      ),
    );

    // Otomatis mencoba sync jika online
    _triggerSyncIfOnline();
  }

  Future<void> _triggerSyncIfOnline() async {
    final status = await connectivity.checkConnectivity();
    if (status != ConnectivityResult.none && !_isSyncing) {
      await performSync();
    }
  }

  /// Mengeksekusi siklus Sinkronisasi Penuh (Push lalu Pull)
  Future<void> performSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      await _pushDataToServer();
      await _pullDataFromServer();
    } catch (e) {
      print('Sync Error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// PUSH: Mengirim data antrean lokal ke Server
  Future<void> _pushDataToServer() async {
    // Ambil antrean yang PENDING atau FAILED dengan retry_count < 3
    final pendingItems = await (db.select(db.syncQueue)
          ..where((t) => t.status.isIn(['PENDING', 'FAILED']) & t.retryCount.isSmallerThanValue(3))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .get();

    if (pendingItems.isEmpty) return;

    final batchPayload = pendingItems.map((e) => {
      'sync_id': e.id,
      'entity': e.entity,
      'action': e.action,
      'payload': jsonDecode(e.payload),
    }).toList();

    try {
      final response = await api.client.post('/sync/push', data: {'data': batchPayload});
      if (response.statusCode == 200) {
        // Hapus item yang sukses atau tandai SYNCED
        final successIds = List<String>.from(response.data['success_ids'] ?? []);
        if (successIds.isNotEmpty) {
          await (db.delete(db.syncQueue)..where((t) => t.id.isIn(successIds))).go();
        }
      }
    } on DioException catch (e) {
      // Increment retry count jika gagal
      for (var item in pendingItems) {
        await (db.update(db.syncQueue)..where((t) => t.id.equals(item.id))).write(
          SyncQueueCompanion(
            status: const Value('FAILED'),
            retryCount: Value(item.retryCount + 1),
          ),
        );
      }
    }
  }

  /// PULL: Mengambil pembaruan dari server sejak sync terakhir
  Future<void> _pullDataFromServer() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_sync') ?? '1970-01-01 00:00:00';

    try {
      final response = await api.client.get('/sync/pull', queryParameters: {'last_sync': lastSync});
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        await db.transaction(() async {
          // TODO: Parse dan UPSERT (Update/Insert) data Products, Categories, dll
          // Contoh:
          // final products = data['products'] as List;
          // for(var p in products) {
          //   await db.into(db.products).insertOnConflictUpdate(ProductsCompanion.insert(...));
          // }
        });

        // Simpan waktu sync baru
        await prefs.setString('last_sync', DateTime.now().toUtc().toIso8601String());
      }
    } catch (e) {
      print('Pull Sync Failed: $e');
    }
  }
}
