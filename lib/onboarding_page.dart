import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';
import 'loginpage.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  bool isLastPage = false;

  bool _isNextPressed = false;
  bool _isSkipPressed = false;

  @override
  Widget build(BuildContext context) {
    // Atur warna status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // =========================================
            // PAGE VIEW
            // =========================================
            PageView(
              controller: _controller,
              onPageChanged: (index) {
                setState(() => isLastPage = (index == 2));
              },
              children: [
                // PAGE 1
                Container(
                  color: Colors.white,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      const CircleAvatar(
                        radius: 70,
                        backgroundImage: AssetImage(
                          'assets/images/fotodefri.png',
                        ),
                        backgroundColor: Colors.transparent,
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Selamat Datang',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Defri Lugas Hidayat',
                        style: TextStyle(fontSize: 16),
                      ),
                      const Text(
                        'Universitas Pelita Bangsa',
                        style: TextStyle(fontSize: 15),
                      ),
                      const Text('312310272', style: TextStyle(fontSize: 15)),
                      const Text(
                        'defrilugas46@gmail.com',
                        style: TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),

                // PAGE 2
                Container(
                  color: Colors.white,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/animations/hacker.json',
                        width: 220,
                        height: 200,
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Melindungi Data dengan Kriptografi',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                          'Setiap pesan punya rahasia.\nDengan kriptografi, hanya penerima yang berhak yang bisa membacanya.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),

                // PAGE 3
                Container(
                  color: Colors.white,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Lottie.asset(
                        'assets/animations/security.json',
                        width: 230,
                        height: 210,
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        'Kunci Aman di Genggamanmu',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                          'Sistem Enkripsi memastikan setiap file, pesan, dan media terlindungi dari ancaman dan akses tidak sah.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // =========================================
            // INDIKATOR DOT (Hilangkan di page 3)
            // =========================================
            Positioned(
              bottom: 55,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: isLastPage ? 0 : 1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  child: SmoothPageIndicator(
                    controller: _controller,
                    count: 3,
                    effect: const ExpandingDotsEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      activeDotColor: Color(0xFF041413),
                    ),
                  ),
                ),
              ),
            ),

            // =========================================
            // TOMBOL SKIP & PANAH (Hilang di page 3)
            // =========================================
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: AnimatedOpacity(
                opacity: isLastPage ? 0 : 1,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                child: AnimatedScale(
                  scale: isLastPage ? 0.8 : 1,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTapDown: (_) => setState(() => _isSkipPressed = true),
                        onTapUp: (_) {
                          setState(() => _isSkipPressed = false);
                          _controller.jumpToPage(2);
                        },
                        onTapCancel:
                            () => setState(() => _isSkipPressed = false),
                        child: AnimatedScale(
                          scale: _isSkipPressed ? 1.1 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeInOut,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF041413),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTapDown: (_) => setState(() => _isNextPressed = true),
                        onTapUp: (_) {
                          setState(() => _isNextPressed = false);
                          if (isLastPage) {
                            Navigator.pushReplacementNamed(context, '/home');
                          } else {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        onTapCancel:
                            () => setState(() => _isNextPressed = false),
                        child: AnimatedScale(
                          scale: _isNextPressed ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeInOut,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF041413),
                            ),
                            child: const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // =========================================
            // TOMBOL "NEXT" DI TENGAH (MUNCUL DI PAGE 3)
            // =========================================
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: isLastPage ? 1 : 0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  child: AnimatedScale(
                    scale: isLastPage ? 1 : 0.8,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _isNextPressed = true),
                      onTapUp: (_) async {
                        setState(() => _isNextPressed = false);

                        // animasi kecil biar smooth
                        await Future.delayed(const Duration(milliseconds: 100));

                        // navigasi ke LoginPage (sebelum Home)
                        Navigator.pushReplacement(
                          context,
                          PageRouteBuilder(
                            transitionDuration: const Duration(
                              milliseconds: 700,
                            ),
                            pageBuilder: (_, __, ___) => const LoginPage(),
                            transitionsBuilder: (_, animation, __, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                      onTapCancel: () => setState(() => _isNextPressed = false),
                      child: AnimatedScale(
                        scale: _isNextPressed ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeInOut,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF041413),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
