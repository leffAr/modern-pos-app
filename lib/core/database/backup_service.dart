import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:drift/drift.dart' as drift;
import 'database.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_picker/file_picker.dart';

class BackupService {
  static Future<void> exportBackup() async {
    try {
      final db = appDb;
      Map<String, List<Map<String, dynamic>>> backupData = {};

      backupData['users'] = (await db.select(db.users).get()).map((e) => e.toJson()).toList();
      backupData['categories'] = (await db.select(db.categories).get()).map((e) => e.toJson()).toList();
      backupData['products'] = (await db.select(db.products).get()).map((e) => e.toJson()).toList();
      backupData['inventory'] = (await db.select(db.inventory).get()).map((e) => e.toJson()).toList();
      backupData['transactions'] = (await db.select(db.transactions).get()).map((e) => e.toJson()).toList();
      backupData['transactionItems'] = (await db.select(db.transactionItems).get()).map((e) => e.toJson()).toList();
      backupData['shifts'] = (await db.select(db.shifts).get()).map((e) => e.toJson()).toList();
      backupData['promos'] = (await db.select(db.promos).get()).map((e) => e.toJson()).toList();

      final jsonString = jsonEncode(backupData);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      final fileName = 'ModernPOS_Backup_${DateTime.now().millisecondsSinceEpoch}';
      
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'json',
        mimeType: MimeType.json,
      );
    } catch (e) {
      debugPrint('Backup error: $e');
      rethrow;
    }
  }

  static Future<void> importBackup() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final jsonString = utf8.decode(bytes);
        final Map<String, dynamic> backupData = jsonDecode(jsonString);
        final db = appDb;

        await db.batch((batch) {
          if (backupData.containsKey('users')) {
            for (var item in backupData['users']) {
              batch.insert(db.users, User.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
          }
          if (backupData.containsKey('categories')) {
            for (var item in backupData['categories']) {
              batch.insert(db.categories, Category.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
          }
          if (backupData.containsKey('products')) {
            for (var item in backupData['products']) {
              batch.insert(db.products, Product.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
          }
          if (backupData.containsKey('inventory')) {
            for (var item in backupData['inventory']) {
              batch.insert(db.inventory, InventoryItem.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
          }
          if (backupData.containsKey('transactions')) {
            for (var item in backupData['transactions']) {
              batch.insert(db.transactions, Transaction.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
          }
          if (backupData.containsKey('transactionItems')) {
            for (var item in backupData['transactionItems']) {
              batch.insert(db.transactionItems, TransactionItem.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
          }
          if (backupData.containsKey('shifts')) {
            for (var item in backupData['shifts']) {
              batch.insert(db.shifts, Shift.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
          }
          if (backupData.containsKey('promos')) {
            for (var item in backupData['promos']) {
              batch.insert(db.promos, Promo.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Restore error: $e');
      rethrow;
    }
  }
}
