import 'dart:io';

void main() {
  final file = File('lib/features/dashboard/presentation/dashboard_screen.dart');
  String content = file.readAsStringSync();
  
  final regex = RegExp(r"Row\(\s*children: \[\s*_buildQuickActionIcon\([\s\S]*?Stok Tipis[\s\S]*?\}\s*\)\s*,?\s*\]\s*,\s*\)");
  
  if (regex.hasMatch(content)) {
    final match = regex.firstMatch(content)!;
    final rowCode = match.group(0)!;
    
    final newCode = """Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 600),
                                        child: \$rowCode,
                                      ),
                                    )""";
                                    
    content = content.replaceFirst(rowCode, newCode);
    file.writeAsStringSync(content);
    print("SUCCESS");
  } else {
    print("FAILED");
  }
}
