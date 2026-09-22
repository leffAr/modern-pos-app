import 'package:drift/drift.dart';
import 'lib/core/database/database.dart';

void main() {
  final db = AppDatabase();
  final query = db.select(db.inventory)..where((t) => t.stock.isSmallerOrEqual(t.minimumStock));
  print(query.constructQuery().sql);
}
