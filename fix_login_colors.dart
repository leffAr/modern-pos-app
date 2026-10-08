import 'dart:io';

void main() {
  final file = File('lib/features/auth/presentation/login_screen.dart');
  String content = file.readAsStringSync();

  // Revert Store Name gradient to solid dark blue
  final oldLeftText = """                  ShaderMask(
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
                  ),""";

  final newLeftText = """                  Text(
                    business?.name ?? 'Modern POS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.blue.shade900),
                  ),""";

  // Revert right side Modern POS text to solid dark blue
  final oldRightText = """                              ShaderMask(
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

  final newRightText = """                              Text(
                                'MODERN POS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3.0,
                                  color: Colors.blue.shade900,
                                ),
                              ),""";

  bool changed = false;
  if (content.contains(oldLeftText)) {
    content = content.replaceFirst(oldLeftText, newLeftText);
    changed = true;
  }
  if (content.contains(oldRightText)) {
    content = content.replaceFirst(oldRightText, newRightText);
    changed = true;
  }

  if (changed) {
    file.writeAsStringSync(content);
    print("SUCCESS");
  } else {
    print("ERROR: Texts not found");
  }
}
