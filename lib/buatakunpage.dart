import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BuatAkunPage extends StatefulWidget {
  const BuatAkunPage({super.key});

  @override
  State<BuatAkunPage> createState() => _BuatAkunPageState();
}

class _BuatAkunPageState extends State<BuatAkunPage>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _passwordTyped = false;
  bool _isLoading = false;

  late AnimationController _colorController;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _colorController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Color get _animatedColor {
    final t = _colorController.value;
    final hue = (t * 360) % 360;
    return HSVColor.fromAHSV(1, hue, 1, 1).toColor();
  }

  bool get isLengthValid => _passwordController.text.length >= 8;
  bool get hasUpperLower =>
      RegExp(r'(?=.*[a-z])(?=.*[A-Z])').hasMatch(_passwordController.text);
  bool get hasNumber => RegExp(r'[0-9]').hasMatch(_passwordController.text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.tealAccent),
      ),
      body: Stack(
        children: [
          // Background gradient
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
          // Honeycomb overlay
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
                        children: [
                          SvgPicture.asset(
                            'assets/images/logoenkripsiapps.svg',
                            height: 70,
                          ),
                          const SizedBox(height: 18),
                          AnimatedBuilder(
                            animation: _colorController,
                            builder:
                                (context, _) => Text(
                                  'Buat Akun Baru',
                                  style: TextStyle(
                                    color: _animatedColor,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    shadows: [
                                      Shadow(
                                        color: _animatedColor.withOpacity(0.6),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Isi form di bawah untuk membuat akun baru',
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
                            prefix: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _passwordController,
                            hint: 'Password',
                            prefix: Icons.lock_outline,
                            obscureText: _obscure,
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
                            onChanged:
                                (val) => setState(
                                  () => _passwordTyped = val.isNotEmpty,
                                ),
                          ),
                          const SizedBox(height: 12),
                          if (_passwordTyped)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCheckItem(
                                  'Minimal 8 karakter',
                                  isLengthValid,
                                ),
                                _buildCheckItem(
                                  'Huruf besar & kecil',
                                  hasUpperLower,
                                ),
                                _buildCheckItem('Angka', hasNumber),
                              ],
                            ),
                          const SizedBox(height: 24),
                          AnimatedBuilder(
                            animation: _colorController,
                            builder: (context, _) {
                              return SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor:
                                        _isLoading
                                            ? Colors.grey
                                            : _animatedColor,
                                  ),
                                  onPressed: _isLoading ? null : _createAccount,
                                  child:
                                      _isLoading
                                          ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.black87,
                                            ),
                                          )
                                          : const Text(
                                            'Buat Akun',
                                            style: TextStyle(
                                              color: Colors.black87,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Text(
                              'Sudah punya akun? Masuk',
                              style: TextStyle(
                                color: Colors.tealAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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

  Future<void> _createAccount() async {
    if (!(isLengthValid && hasUpperLower && hasNumber)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password belum memenuhi kriteria ❌')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Akun berhasil dibuat ✅')));

      Navigator.pushReplacementNamed(context, '/biodata');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'Terjadi kesalahan';
      if (e.code == 'email-already-in-use')
        message =
            'Email sudah digunakan\nSilahkan Log in dengan Email yang terdatar';
      if (e.code == 'invalid-email') message = 'Format email salah';
      if (e.code == 'weak-password') message = 'Password terlalu lemah';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCheckItem(String text, bool valid) => Row(
    children: [
      Icon(
        valid ? Icons.check_circle : Icons.cancel,
        size: 16,
        color: valid ? Colors.tealAccent : Colors.redAccent,
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: TextStyle(
          color: valid ? Colors.white70 : Colors.white38,
          fontSize: 13,
        ),
      ),
    ],
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? prefix,
    Widget? suffixWidget,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Function(String)? onChanged,
  }) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscureText,
    onChanged: onChanged,
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

// Background Honeycomb
class _GlowingHoneycombPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.tealAccent.withOpacity(0.03)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7;

    const double hexRadius = 26;
    final hexHeight = hexRadius * 2;
    final hexWidth = 1.732 * hexRadius;
    final cols = (size.width / hexWidth).ceil();
    final rows = (size.height / (hexHeight * 0.75)).ceil();

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
