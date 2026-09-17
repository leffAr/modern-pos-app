import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final path = [Platform.environment['USERPROFILE'], 'Documents', 'pos_offline.sqlite'].join('\\');
  if (File(path).existsSync()) {
     final db = sqlite3.open(path);
     final txs = db.select('SELECT * FROM transactions ORDER BY created_at DESC LIMIT 5');
     for (var row in txs) {
       print(row);
     }
  } else {
     print('Not found at $path');
  }
}
