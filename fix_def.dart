import 'dart:io';

void main() {
  final file = File('lib/features/dashboard/presentation/dashboard_screen.dart');
  String content = file.readAsStringSync();
  
  final regex = RegExp(r"Widget _buildQuickActionIcon\(\{[\s\S]*?\}\s*\)\s*\{\s*return Expanded\([\s\S]*?\}\s*,\s*\)\s*;\s*\}", multiLine: true);
  
  final newDef = """
Widget _buildQuickActionIcon({
  required BuildContext context,
  required IconData icon,
  required Color color,
  required String title,
  required VoidCallback onTap,
  Widget? badge,
}) {
  final iconWidget = Container(
    padding: const EdgeInsets.symmetric(vertical: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Icon(icon, size: 40, color: color),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color.withOpacity(0.8),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: badge != null
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                iconWidget,
                Positioned(
                  top: -8,
                  right: -8,
                  child: badge,
                ),
              ],
            )
          : iconWidget,
    ),
  );
}
""";

  if (regex.hasMatch(content)) {
    content = content.replaceFirst(regex, newDef);
    file.writeAsStringSync(content);
    print("SUCCESS");
  } else {
    print("FAILED");
  }
}
