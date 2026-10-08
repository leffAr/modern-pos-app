import 'dart:io';

void main() {
  final tablesFile = File('lib/core/database/tables.dart');
  String tContent = tablesFile.readAsStringSync();
  tContent = tContent.replaceFirst(
    '  TextColumn get pin => text().nullable()(); // hashed PIN for quick login',
    '  TextColumn get pin => text().nullable()(); // hashed PIN for quick login\n  BoolColumn get allowBiometric => boolean().withDefault(const Constant(false))();'
  );
  tablesFile.writeAsStringSync(tContent);

  final dbFile = File('lib/core/database/database.dart');
  String dbContent = dbFile.readAsStringSync();
  dbContent = dbContent.replaceFirst(
    'int get schemaVersion => 14;',
    'int get schemaVersion => 15;'
  );
  dbContent = dbContent.replaceFirst(
    'if (from < 14) {',
    'if (from < 14) {\n          await m.addColumn(businesses, businesses.qrisBase64);\n        }\n        if (from < 15) {\n          await m.addColumn(users, users.allowBiometric);\n        }\n        if (from == 999) {' // hacky string match to replace right block if we need to
  );
  
  // Wait, let's properly append the migration rule.
  final regex = RegExp(r'if \(from < 14\) \{[\s\S]*?\}');
  final match = regex.firstMatch(dbContent);
  if (match != null) {
    dbContent = dbContent.replaceFirst(
      match.group(0)!,
      match.group(0)! + '\n        if (from < 15) {\n          await m.addColumn(users, users.allowBiometric);\n        }'
    );
  }
  
  // Actually wait, I need to clean up my hack above
  dbContent = dbFile.readAsStringSync(); // read again
  dbContent = dbContent.replaceFirst('int get schemaVersion => 14;', 'int get schemaVersion => 15;');
  final cleanRegex = RegExp(r'if \(from < 14\) \{[\s\S]*?\}');
  final cleanMatch = cleanRegex.firstMatch(dbContent);
  if (cleanMatch != null) {
    dbContent = dbContent.replaceFirst(
      cleanMatch.group(0)!,
      cleanMatch.group(0)! + '\n        if (from < 15) {\n          await m.addColumn(users, users.allowBiometric);\n        }'
    );
  }
  
  dbFile.writeAsStringSync(dbContent);
  print("SUCCESS");
}
