import 'dart:io';

void main() {
  final file = File('lib/features/dashboard/presentation/dashboard_screen.dart');
  String content = file.readAsStringSync();

  final regex = RegExp(r'return\s*LayoutBuilder\(\s*builder:\s*\(context,\s*constraints\)\s*\{\s*List<FlSpot>\s*spots\s*=\s*\[\];[\s\S]*?return\s*Container\(\s*child:\s*AspectRatio\(\s*aspectRatio:\s*constraints\.maxWidth\s*<\s*600\s*\?\s*1\.2\s*:\s*2\.5,');

  if (content.contains('aspectRatio: constraints.maxWidth < 600 ? 1.2 : 2.5,')) {
    // Replace the AspectRatio line
    content = content.replaceFirst(
      'aspectRatio: constraints.maxWidth < 600 ? 1.2 : 2.5,',
      'aspectRatio: constraints.maxWidth < 600 ? 1.2 : 3.5,'
    );
    
    // Wrap the Container that has AspectRatio inside a ConstrainedBox
    // We'll replace `return Container(\n        child: AspectRatio(` with `return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: AspectRatio(`
    content = content.replaceFirst(
      'return Container(\n      child: AspectRatio(',
      'return Center(\n      child: ConstrainedBox(\n        constraints: const BoxConstraints(maxWidth: 1000),\n        child: AspectRatio('
    );
    // Wait, it might be `child: Container(\n          padding: const EdgeInsets.all(20),`
    
    file.writeAsStringSync(content);
    print("SUCCESS");
  } else {
    print("ERROR: Not found");
  }
}
