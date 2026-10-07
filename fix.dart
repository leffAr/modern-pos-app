import 'package:pos_mobile/features/pos/presentation/pos_screen.dart' as p;
import 'dart:io';

void main() {
  final file = File('lib/features/pos/presentation/pos_screen.dart');
  String content = file.readAsStringSync();
  content = content.replaceAll(r"'final stock $unit'", r"'\ \'");
  file.writeAsStringSync(content);
}
