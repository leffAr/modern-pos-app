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

      backupData['businesses'] = (await db.select(db.businesses).get()).map((e) => e.toJson()).toList();
      backupData['branches'] = (await db.select(db.branches).get()).map((e) => e.toJson()).toList();
      backupData['users'] = (await db.select(db.users).get()).map((e) => e.toJson()).toList();
      backupData['categories'] = (await db.select(db.categories).get()).map((e) => e.toJson()).toList();
      backupData['products'] = (await db.select(db.products).get()).map((e) => e.toJson()).toList();
      backupData['productVariants'] = (await db.select(db.productVariants).get()).map((e) => e.toJson()).toList();
      backupData['inventory'] = (await db.select(db.inventory).get()).map((e) => e.toJson()).toList();
      backupData['customers'] = (await db.select(db.customers).get()).map((e) => e.toJson()).toList();
      backupData['debtPayments'] = (await db.select(db.debtPayments).get()).map((e) => e.toJson()).toList();
      backupData['suppliers'] = (await db.select(db.suppliers).get()).map((e) => e.toJson()).toList();
      backupData['promos'] = (await db.select(db.promos).get()).map((e) => e.toJson()).toList();
      
      backupData['transactions'] = (await db.select(db.transactions).get()).map((e) => e.toJson()).toList();
      backupData['transactionItems'] = (await db.select(db.transactionItems).get()).map((e) => e.toJson()).toList();
      backupData['payments'] = (await db.select(db.payments).get()).map((e) => e.toJson()).toList();
      
      backupData['shifts'] = (await db.select(db.shifts).get()).map((e) => e.toJson()).toList();
      backupData['expenses'] = (await db.select(db.expenses).get()).map((e) => e.toJson()).toList();
      
      backupData['purchases'] = (await db.select(db.purchases).get()).map((e) => e.toJson()).toList();
      backupData['purchaseItems'] = (await db.select(db.purchaseItems).get()).map((e) => e.toJson()).toList();

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
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final jsonString = utf8.decode(bytes);
        final Map<String, dynamic> backupData = jsonDecode(jsonString);
        final db = appDb;

        await db.transaction(() async {
          await db.batch((batch) {
            // Restore Master Data
            if (backupData.containsKey('businesses')) {
              for (var item in backupData['businesses']) batch.insert(db.businesses, Business.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
            if (backupData.containsKey('branches')) {
              for (var item in backupData['branches']) batch.insert(db.branches, Branch.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
            if (backupData.containsKey('users')) {
              for (var item in backupData['users']) batch.insert(db.users, User.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
            if (backupData.containsKey('categories')) {
              for (var item in backupData['categories']) batch.insert(db.categories, Category.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
            if (backupData.containsKey('products')) {
              for (var item in backupData['products']) batch.insert(db.products, Product.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
            if (backupData.containsKey('productVariants')) {
              for (var item in backupData['productVariants']) batch.insert(db.productVariants, ProductVariant.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
            if (backupData.containsKey('inventory')) {
              for (var item in backupData['inventory']) batch.insert(db.inventory, InventoryItem.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
            if (backupData.containsKey('customers')) {
              for (var item in backupData['customers']) batch.insert(db.customers, Customer.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
            if (backupData.containsKey('debtPayments')) {
              for (var item in backupData['debtPayments']) batch.insert(db.debtPayments, DebtPayment.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
            if (backupData.containsKey('suppliers')) {
              for (var item in backupData['suppliers']) batch.insert(db.suppliers, Supplier.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
            if (backupData.containsKey('promos')) {
              for (var item in backupData['promos']) batch.insert(db.promos, Promo.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }

            // Restore Transactions
            if (backupData.containsKey('transactions')) {
              for (var item in backupData['transactions']) batch.insert(db.transactions, Transaction.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
            if (backupData.containsKey('transactionItems')) {
              for (var item in backupData['transactionItems']) batch.insert(db.transactionItems, TransactionItem.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
            if (backupData.containsKey('payments')) {
              for (var item in backupData['payments']) batch.insert(db.payments, Payment.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }

            // Restore Shifts & Operational
            if (backupData.containsKey('shifts')) {
              for (var item in backupData['shifts']) batch.insert(db.shifts, Shift.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
            if (backupData.containsKey('expenses')) {
              for (var item in backupData['expenses']) batch.insert(db.expenses, Expense.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
            if (backupData.containsKey('purchases')) {
              for (var item in backupData['purchases']) batch.insert(db.purchases, Purchase.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
            if (backupData.containsKey('purchaseItems')) {
              for (var item in backupData['purchaseItems']) batch.insert(db.purchaseItems, PurchaseItem.fromJson(item), mode: drift.InsertMode.insertOrReplace);
            }
          });
        });
      }
    } catch (e) {
      debugPrint('Restore error: $e');
      rethrow;
    }
  }
}
