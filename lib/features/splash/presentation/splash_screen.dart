import 'package:flutter/material.dart';
import '../../auth/presentation/login_screen.dart';
import '../../dashboard/presentation/main_layout.dart';
import '../../../core/database/database.dart';
import 'package:drift/drift.dart' as drift;

class SplashScreen extends StatefulWidget {
  final bool isLoggedIn;
  final String userRole;
  final String userName;
  final String userId;

  const SplashScreen({
    super.key,
    required this.isLoggedIn,
    required this.userRole,
    required this.userName,
    required this.userId,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Simulasi loading selama 2.5 detik agar animasi terlihat
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    if (widget.isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => StreamBuilder<User>(
            stream: (appDb.select(appDb.users)..where((u) => u.id.equals(widget.userId))).watchSingle(),
            builder: (context, snapshot) {
              final liveName = snapshot.data?.name ?? widget.userName;
              return MainLayout(
                userRole: widget.userRole,
                userName: liveName,
                userId: widget.userId,
              );
            },
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8), // Latar belakang abu-abu sangat muda/kebiruan
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Container untuk logo dan progress indicator melingkar
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress indicator di luar logo
                  const SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      color: Colors.blueAccent,
                      backgroundColor: Color(0xFFD6E4FF),
                    ),
                  ),
                  // Logo di tengah
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(6), // Margin putih sangat tipis seperti di gambar
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo_v3.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront, size: 60, color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Teks judul
            const Text(
              'Memuat Modern POS...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            // Teks subjudul
            const Text(
              'Menyiapkan aplikasi Anda',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
