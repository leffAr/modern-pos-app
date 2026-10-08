import 'dart:io';

void main() {
  final file = File('lib/features/dashboard/presentation/dashboard_screen.dart');
  String content = file.readAsStringSync();
  
  // 1. Constrain Row
  final regexRow = RegExp(r"Row\(\s*children: \[\s*_buildQuickActionIcon\([\s\S]*?Stok Tipis[\s\S]*?\}\s*\)\s*,?\s*\]\s*,\s*\)");
  if (regexRow.hasMatch(content)) {
    final match = regexRow.firstMatch(content)!;
    final rowCode = match.group(0)!;
    
    final newCode = """Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 600),
                                        child: $rowCode,
                                      ),
                                    )""";
                                    
    content = content.replaceFirst(rowCode, newCode);
    print("Row wrapped successfully!");
  } else {
    print("Row not found!");
  }

  // 2. Add width: double.infinity
  final regexWidth = RegExp(r"Widget _buildQuickActionIcon\(\{[\s\S]*?\}\s*\)\s*\{\s*final iconWidget = Container\(\s*padding: const EdgeInsets\.symmetric\(vertical: 24\),");
  
  final newWidthCode = """Widget _buildQuickActionIcon({
  required BuildContext context,
  required IconData icon,
  required Color color,
  required String title,
  required VoidCallback onTap,
  Widget? badge,
}) {
  final iconWidget = Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 24),""";
  
  if (regexWidth.hasMatch(content)) {
    content = content.replaceFirst(regexWidth, newWidthCode);
    print("Width added successfully!");
  } else {
    print("Width target not found!");
  }

  file.writeAsStringSync(content);
}
