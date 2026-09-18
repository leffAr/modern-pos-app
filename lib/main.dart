import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/dashboard/presentation/main_layout.dart';
import 'features/auth/presentation/login_screen.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'core/database/database.dart';
import 'package:drift/drift.dart' as drift;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  
  // Migrate old buggy data from "Admin Utama" to "U-1"
  await (appDb.update(appDb.transactions)..where((t) => t.userId.equals('Admin Utama'))).write(
    const TransactionsCompanion(userId: drift.Value('U-1'))
  );
  await (appDb.update(appDb.shifts)..where((s) => s.userId.equals('Admin Utama'))).write(
    const ShiftsCompanion(userId: drift.Value('U-1'))
  );

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final userRole = prefs.getString('userRole') ?? 'Kasir';
  final userName = prefs.getString('userName') ?? 'Kasir';
  final userId = prefs.getString('userId') ?? 'USR-DEFAULT-ADMIN';

  runApp(
    ProviderScope(
      child: ModernPOSApp(
        isLoggedIn: isLoggedIn,
        userRole: userRole,
        userName: userName,
        userId: userId,
      ),
    ),
  );
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => { 
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

class ModernPOSApp extends ConsumerWidget {
  final bool isLoggedIn;
  final String userRole;
  final String userName;
  final String userId;
  
  const ModernPOSApp({
    super.key,
    required this.isLoggedIn,
    required this.userRole,
    required this.userName,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Modern POS',
      scrollBehavior: MyCustomScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: isLoggedIn 
          ? StreamBuilder<User>(
              stream: (appDb.select(appDb.users)..where((u) => u.id.equals(userId))).watchSingle(),
              builder: (context, snapshot) {
                final liveName = snapshot.data?.name ?? userName;
                return MainLayout(userRole: userRole, userName: liveName, userId: userId);
              },
            ) 
          : const LoginScreen(),
    );
  }
}
