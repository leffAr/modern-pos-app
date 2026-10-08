import 'dart:io';

void main() {
  final file = File('lib/features/auth/presentation/login_screen.dart');
  String content = file.readAsStringSync();
  
  // Replace the build method and add _keepLoggedIn state
  final stateStart = content.indexOf('class _LoginScreenState extends ConsumerState<LoginScreen> {');
  if (stateStart != -1) {
    if (!content.contains('bool _keepLoggedIn = true;')) {
      content = content.replaceFirst(
        'class _LoginScreenState extends ConsumerState<LoginScreen> {',
        'class _LoginScreenState extends ConsumerState<LoginScreen> {\n  bool _keepLoggedIn = true;'
      );
    }
  }

  final buildRegex = RegExp(r"Widget build\(BuildContext context\) \{[\s\S]*");
  if (buildRegex.hasMatch(content)) {
    final newBuild = """Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    final loginCard = Card(
      elevation: 4,
      shadowColor: Colors.black26,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Login',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.person, color: Colors.blueGrey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock, color: Colors.amber),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Keep me logged in',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                Switch(
                  value: _keepLoggedIn,
                  activeColor: Colors.tealAccent.shade400,
                  onChanged: (v) {
                    setState(() => _keepLoggedIn = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF007BFF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _handleLogin,
              child: const Text('Log in',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      iconSize: 40,
                      color: Colors.blue,
                      icon: const Icon(Icons.fingerprint),
                      onPressed: _showPinLoginDialog,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Login With PIN',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            )
          ],
        ),
      ),
    );

    final leftContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        StreamBuilder<Business?>(
            stream: (appDb.select(appDb.businesses)..limit(1))
                .watchSingleOrNull(),
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
            }),
        const SizedBox(height: 48),
        loginCard,
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: isWide
          ? Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: leftContent,
                    ),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Container(
                    color: const Color(0xFFE3F2FD),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -100,
                          bottom: -100,
                          child: Container(
                            width: 600,
                            height: 600,
                            decoration: BoxDecoration(
                              color: const Color(0xFFBBDEFB),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          left: -50,
                          top: -50,
                          child: Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              color: const Color(0xFF90CAF9),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.point_of_sale_rounded,
                                  size: 250, color: Colors.blue.shade700),
                              const SizedBox(height: 24),
                              Text(
                                'Manage Your Store\nEfficiently & Easily',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            )
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: leftContent,
                ),
              ),
            ),
    );
  }
}
""";
    content = content.replaceFirst(buildRegex, newBuild);
    file.writeAsStringSync(content);
    print("SUCCESS");
  } else {
    print("FAILED");
  }
}
