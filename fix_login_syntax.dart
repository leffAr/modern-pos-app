import 'dart:io';

void main() {
  final file = File('lib/features/auth/presentation/login_screen.dart');
  String content = file.readAsStringSync();
  
  final garbage = """    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error otentikasi: \$e')),
        );
      }
    }
  }""";
  
  if (content.contains(garbage)) {
    content = content.replaceFirst(garbage, "");
    file.writeAsStringSync(content);
    print("SUCCESS: removed garbage from login_screen");
  } else {
    print("ERROR: garbage not found");
  }
}
