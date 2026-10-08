import 'dart:io';

void main() {
  final file = File('lib/features/dashboard/presentation/dashboard_screen.dart');
  String content = file.readAsStringSync();

  final regex = RegExp(r'childAspectRatio:\s*isMobile\s*\?\s*1\.3\s*:\s*1\.8,');
  
  if (content.contains(regex)) {
    content = content.replaceFirst(
      regex,
      'childAspectRatio: isMobile ? 1.3 : 2.5,'
    );
    
    // Also, wrap the GridView.count in Center and ConstrainedBox?
    // Actually, `childAspectRatio: 2.5` alone will make them significantly shorter and look much sleeker (smaller) vertically on PC/Tablet. 
    // Let's just do `childAspectRatio: 2.8` maybe? Let's stick to 2.5.
    
    file.writeAsStringSync(content);
    print("SUCCESS");
  } else {
    print("ERROR: Not found");
  }
}
