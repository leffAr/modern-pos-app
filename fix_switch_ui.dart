import 'dart:io';

void main() {
  final file = File('lib/features/users/presentation/users_screen.dart');
  String content = file.readAsStringSync();
  
  // The block we want to replace:
  final target = "                  ),\n                ],\n              ),\n            ),\n            actions: [";
  
  final switchUI = """                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Izinkan Akses Biometrik (Sidik Jari/Wajah)',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      Switch(
                        value: isBiometricAllowed,
                        onChanged: (val) {
                          setStateSB(() => isBiometricAllowed = val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [""";

  if (content.contains(target)) {
    content = content.replaceFirst(target, switchUI);
    file.writeAsStringSync(content);
    print("SUCCESS: Inserted switch UI");
  } else {
    print("ERROR: Target block not found");
  }
}
