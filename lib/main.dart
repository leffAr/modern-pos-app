import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/splash/presentation/splash_screen.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'core/database/database.dart';
import 'package:drift/drift.dart' as drift;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  
  // Migrate old buggy data without blocking UI
  Future.microtask(() async {
    try {
      await (appDb.update(appDb.transactions)..where((t) => t.userId.equals('Admin Utama'))).write(
        const TransactionsCompanion(userId: drift.Value('U-1'))
      );
      await (appDb.update(appDb.shifts)..where((s) => s.userId.equals('Admin Utama'))).write(
        const ShiftsCompanion(userId: drift.Value('U-1'))
      );
    } catch (e) {
      print("Migration error: $e");
    }
  });

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
      theme: AppTheme.lightTheme,
      home: SplashScreen(
        isLoggedIn: isLoggedIn,
        userRole: userRole,
        userName: userName,
        userId: userId,
      ),
    );
  }
}
