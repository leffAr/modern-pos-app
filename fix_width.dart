import 'dart:io';

void main() {
  final file = File('lib/features/dashboard/presentation/dashboard_screen.dart');
  String content = file.readAsStringSync();
  
  final regex = RegExp(r"Widget _buildQuickActionIcon\(\{[\s\S]*?\}\s*\)\s*\{\s*final iconWidget = Container\(\s*padding: const EdgeInsets\.symmetric\(vertical: 24\),");
  
  final newBlock = """Widget _buildQuickActionIcon({
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
  
  if (regex.hasMatch(content)) {
    content = content.replaceFirst(regex, newBlock);
    file.writeAsStringSync(content);
    print("SUCCESS");
  } else {
    print("FAILED");
  }
}
