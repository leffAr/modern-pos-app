import 'dart:io';

void main() {
  final file = File('lib/features/users/presentation/users_screen.dart');
  String content = file.readAsStringSync();
  
  // 1. Add state variable
  content = content.replaceFirst(
    'String selectedRole = user?.roleId == \'role-admin\' ? \'role-admin\' : \'role-cashier\';',
    'String selectedRole = user?.roleId == \'role-admin\' ? \'role-admin\' : \'role-cashier\';\n    bool isBiometricAllowed = user?.allowBiometric ?? false;'
  );
  
  // 2. Add Switch UI
  final switchUI = """
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
""";
  content = content.replaceFirst('                  ],\n                ),\n              ),\n              actions:', switchUI + '\n              ),\n              actions:');
  
  // 3. Add to companion
  content = content.replaceFirst(
    'roleId: drift.Value(selectedRole),',
    'roleId: drift.Value(selectedRole),\n                        allowBiometric: drift.Value(isBiometricAllowed),'
  );
  
  file.writeAsStringSync(content);
  print("SUCCESS");
}
