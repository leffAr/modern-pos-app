import 'dart:io';

void main() {
  final file = File('android/app/src/main/kotlin/com/example/pos_mobile/MainActivity.kt');
  String content = file.readAsStringSync();
  
  content = content.replaceAll(
    'import io.flutter.embedding.android.FlutterActivity',
    'import io.flutter.embedding.android.FlutterFragmentActivity'
  );
  content = content.replaceAll(
    'class MainActivity: FlutterActivity()',
    'class MainActivity: FlutterFragmentActivity()'
  );
  
  file.writeAsStringSync(content);
}
