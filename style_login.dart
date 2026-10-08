import 'dart:io';

void main() {
  final file = File('lib/features/auth/presentation/login_screen.dart');
  String content = file.readAsStringSync();

  // 1. Centering and styling the Store Name
  final oldLeftContent = """    final leftContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamBuilder<Business?>(
            stream:
                (appDb.select(appDb.businesses)..limit(1)).watchSingleOrNull(),
            builder: (context, snapshot) {
              final business = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business?.name ?? 'Modern POS',
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Online inventory management system',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4B5563)),
                  ),
                ],
              );
            }),""";

  final newLeftContent = """    final leftContent = Column(
      crossAxisAlignment: CrossAxisAlignment.center, // CENTERED
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamBuilder<Business?>(
            stream:
                (appDb.select(appDb.businesses)..limit(1)).watchSingleOrNull(),
            builder: (context, snapshot) {
              final business = snapshot.data;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center, // CENTERED
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      business?.name ?? 'Modern POS',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 42, // LEBIH BESAR
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.white), // Harus putih agar gradient muncul
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Online inventory management system',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Color(0xFF6B7280)),
                  ),
                ],
              );
            }),""";

  // 2. Styling the "Modern POS" text on the right side
  final oldRightText = """                              Text(
                                'Modern POS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),""";
                              
  final newRightText = """                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: [Colors.blue.shade900, Colors.blue.shade600],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: const Text(
                                  'MODERN POS',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3.0,
                                    color: Colors.white,
                                  ),
                                ),
                              ),""";

  bool changed = false;
  if (content.contains(oldLeftContent)) {
    content = content.replaceFirst(oldLeftContent, newLeftContent);
    print("SUCCESS: Left content updated");
    changed = true;
  } else {
    print("ERROR: Left content not found");
  }

  if (content.contains(oldRightText)) {
    content = content.replaceFirst(oldRightText, newRightText);
    print("SUCCESS: Right text updated");
    changed = true;
  } else {
    print("ERROR: Right text not found");
  }

  if (changed) {
    file.writeAsStringSync(content);
  }
}
