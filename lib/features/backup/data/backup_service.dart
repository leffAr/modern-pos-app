import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupService {
  /// Menggandakan file SQLite utama (pos_offline.sqlite) ke folder Download / Documents pengguna
  static Future<bool> exportLocalDatabase() async {
    try {
      // 1. Dapatkan lokasi file DB asli
      final appDocsDir = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(appDocsDir.path, 'pos_offline.sqlite'));

      if (!await dbFile.exists()) {
        print('Database file does not exist!');
        return false;
      }

      // 2. Tentukan lokasi tujuan (Folder Download atau Documents)
      Directory? externalDir;
      if (Platform.isAndroid) {
        // Fallback to external storage download directory
        externalDir = Directory('/storage/emulated/0/Download');
      } else {
        externalDir = await getApplicationDocumentsDirectory(); // iOS / Windows fallback
      }

      if (!await externalDir.exists()) {
        await externalDir.create(recursive: true);
      }

      // 3. Nama file backup dengan timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFileName = 'modernpos_backup_$timestamp.sqlite';
      final destinationPath = p.join(externalDir.path, backupFileName);

      // 4. Copy file
      await dbFile.copy(destinationPath);
      print('Database backup successfully exported to: $destinationPath');
      
      return true;
    } catch (e) {
      print('Failed to backup database: $e');
      return false;
    }
  }

  /// TODO: Implementasikan mekanisme upload file SQLite ke Cloud Storage (Firebase/AWS)
  static Future<void> backupToCloud() async {
    // 1. Export local
    // 2. Ambil token
    // 3. Upload file via API/SDK
  }
}
