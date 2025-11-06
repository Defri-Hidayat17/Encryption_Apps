// ignore_for_file: use_build_context_synchronously

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'buatakunpage.dart';
import 'dart:math' as math;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'main.dart';

final messengerKey = rootScaffoldMessengerKey;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _remember = false;
  bool _isGoogleLoading = false;
  AnimationController? _colorController;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  Database? _database;

  @override
  void initState() {
    super.initState();
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _initDatabaseAndAutoLogin();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _initDatabaseAndAutoLogin() async {
    await _initDatabase();
    await _checkAutoLogin();
  }

  Future<void> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    _database = await openDatabase(
      join(dbPath, 'biodata.db'),
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE biodata (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE,
  nama TEXT,
  ttl TEXT,
  jenisKelamin TEXT,
  pekerjaan TEXT,
  tentang TEXT,
  foto BLOB
)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await db.execute('''
CREATE TABLE biodata_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE,
  nama TEXT,
  ttl TEXT,
  jenisKelamin TEXT,
  pekerjaan TEXT,
  tentang TEXT,
  foto BLOB
)
          ''');
          await db.execute('''
INSERT INTO biodata_new (email, nama, ttl, jenisKelamin, pekerjaan, tentang, foto)
SELECT email, nama, ttl, jenisKelamin, pekerjaan, tentang, foto FROM biodata
          ''');
          await db.execute('DROP TABLE biodata');
          await db.execute('ALTER TABLE biodata_new RENAME TO biodata');
        }
      },
    );
  }

  Future<void> _checkAutoLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _database != null) {
      final hasBiodata = await _checkBiodataExists(user.email!);
      if (hasBiodata) {
        Navigator.pushReplacementNamed(super.context, '/home');
      } else {
        Navigator.pushReplacementNamed(super.context, '/biodata');
      }
    }
  }

  Future<bool> _checkBiodataExists(String email) async {
    if (_database == null) return false;

    final List<Map<String, dynamic>> result = await _database!.query(
      'biodata',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  Future<void> _insertBiodata(String email) async {
    if (_database == null) return;

    await _database!.insert('biodata', {
      'email': email,
      'nama': '',
      'ttl': '',
      'jenisKelamin': '',
      'pekerjaan': '',
      'tentang': '',
      'foto': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  void dispose() {
    _colorController?.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _database?.close();
    super.dispose();
  }

  Color get _animatedColor {
    final t = _colorController?.value ?? 0.0;
    final hue = (t * 360) % 360;
    return HSVColor.fromAHSV(1, hue, 1, 1).toColor();
  }

  Future<void> _loginWithGoogle() async {
    try {
      setState(() => _isGoogleLoading = true);

      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final userEmail = userCredential.user?.email;

      if (userEmail != null) {
        final hasBiodata = await _checkBiodataExists(userEmail);
        if (!hasBiodata) {
          await _insertBiodata(userEmail);
          Navigator.pushReplacementNamed(super.context, '/biodata');
        } else {
          Navigator.pushReplacementNamed(super.context, '/home');
        }
      }

      messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text("Login dengan Google berhasil 🎉"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text("Gagal login dengan Google: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isGoogleLoading = false);
    }
  }

  void _loginWithEmailPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text("Email dan password tidak boleh kosong!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final userEmail = userCredential.user?.email;
      if (userEmail != null) {
        final hasBiodata = await _checkBiodataExists(userEmail);
        if (!hasBiodata) {
          await _insertBiodata(userEmail);
          Navigator.pushReplacementNamed(super.context, '/biodata');
        } else {
          Navigator.pushReplacementNamed(super.context, '/home');
        }
      }

      messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text("Login Berhasil 🎉"),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String msg = "Gagal masuk!";
      if (e.code == 'user-not-found') msg = "Email belum terdaftar!";
      if (e.code == 'wrong-password') msg = "Password salah!";
      if (e.code == 'invalid-email') msg = "Format email tidak valid!";
      messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? prefix,
    Widget? suffixWidget,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: prefix != null ? Icon(prefix, color: Colors.white60) : null,
        suffixIcon: suffixWidget,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.tealAccent.shade400, width: 1.2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // UI tetap sama persis
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF041413),
                  Color(0xFF062422),
                  Color(0xFF041413),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _GlowingHoneycombPainter()),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.tealAccent.withOpacity(0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/images/logoenkripsiapps.svg',
                            height: 80,
                          ),
                          const SizedBox(height: 18),
                          AnimatedBuilder(
                            animation: _colorController!,
                            builder: (context, _) {
                              return Text(
                                'Selamat Datang',
                                style: TextStyle(
                                  color: _animatedColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: _animatedColor.withOpacity(0.6),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Masuk ke EnkripsiApps untuk melanjutkan',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 26),
                          _buildTextField(
                            controller: _emailController,
                            hint: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            prefix: Icons.email_outlined,
                          ),
                          const SizedBox(height: 14),
                          _buildTextField(
                            controller: _passwordController,
                            hint: 'Password',
                            obscureText: _obscure,
                            prefix: Icons.lock_outline,
                            suffixWidget: IconButton(
                              onPressed:
                                  () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              GestureDetector(
                                onTap:
                                    () =>
                                        setState(() => _remember = !_remember),
                                child: Row(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color:
                                            _remember
                                                ? Colors.tealAccent.shade400
                                                    .withOpacity(0.8)
                                                : Colors.transparent,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.white54,
                                        ),
                                      ),
                                      child:
                                          _remember
                                              ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.black,
                                              )
                                              : null,
                                    ),
                                    const SizedBox(width: 9),
                                    const Text(
                                      'Ingat saya',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {},
                                child: const Text(
                                  'Lupa password?',
                                  style: TextStyle(color: Colors.tealAccent),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AnimatedBuilder(
                            animation: _colorController!,
                            builder: (context, _) {
                              final rgb = _animatedColor;
                              return Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      rgb,
                                      rgb.withOpacity(0.6),
                                      rgb.withOpacity(0.9),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _loginWithEmailPassword,
                                  child: const Text(
                                    'Masuk',
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: const [
                              Expanded(child: Divider(color: Colors.white24)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'atau login dengan',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white24)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: Colors.white.withOpacity(0.05),
                              ),
                              onPressed:
                                  _isGoogleLoading ? null : _loginWithGoogle,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedScale(
                                    duration: const Duration(milliseconds: 180),
                                    scale: _isGoogleLoading ? 0.85 : 1.0,
                                    child:
                                        _isGoogleLoading
                                            ? const SizedBox(
                                              height: 22,
                                              width: 22,
                                              child: CircularProgressIndicator(
                                                color: Colors.tealAccent,
                                                strokeWidth: 2,
                                              ),
                                            )
                                            : SvgPicture.asset(
                                              'assets/images/google.svg',
                                              height: 22,
                                            ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isGoogleLoading
                                        ? 'Sedang masuk...'
                                        : 'Masuk dengan Google',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Belum punya akun? ',
                                style: TextStyle(color: Colors.white70),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      transitionDuration: const Duration(
                                        milliseconds: 600,
                                      ),
                                      pageBuilder:
                                          (_, __, ___) => const BuatAkunPage(),
                                      transitionsBuilder:
                                          (_, anim, __, child) =>
                                              FadeTransition(
                                                opacity: CurvedAnimation(
                                                  parent: anim,
                                                  curve: Curves.easeInOut,
                                                ),
                                                child: child,
                                              ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Buat Akun',
                                  style: TextStyle(
                                    color: Colors.tealAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowingHoneycombPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.tealAccent.withOpacity(0.03)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7;

    const double hexRadius = 26;
    final double hexHeight = hexRadius * 2;
    final double hexWidth = 1.732 * hexRadius;
    final int cols = (size.width / hexWidth).ceil();
    final int rows = (size.height / (hexHeight * 0.75)).ceil();

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final dx = col * hexWidth + (row.isOdd ? hexWidth / 2 : 0);
        final dy = row * hexHeight * 0.75;
        final path = _hexagonPath(Offset(dx, dy), hexRadius);
        canvas.drawPath(path, paint);
      }
    }
  }

  Path _hexagonPath(Offset center, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * (math.pi / 180);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
