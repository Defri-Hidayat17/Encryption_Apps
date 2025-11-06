import 'package:encryptionapps/rot13.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'caesarcipher.dart';
import 'vigenerecipher.dart';
import 'description_page.dart';
import 'playfaircipher.dart';
import 'hillcipher.dart';
import 'transpositioncipher.dart';
import 'profile_page.dart';

// ===========================
// 🔹 HALAMAN UTAMA (HOME PAGE)
// ===========================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  double _opacity = 0;
  double _scale = 0.95;
  int _selectedIndex = 1;

  final navigationKey = GlobalKey<CurvedNavigationBarState>();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 180), () {
      setState(() {
        _opacity = 1;
        _scale = 1.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    final List<CardItem> cardItems = [
      CardItem(
        id: 1,
        title: 'Caesar Cipher',
        description:
            'Pergeseran huruf dalam alfabet. Contoh klasik untuk memahami dasar enkripsi.',
        imagePath: 'assets/images/15.png',
        route: '/caesar',
      ),
      CardItem(
        id: 2,
        title: 'Vigenère Cipher',
        description:
            'Menggunakan kata kunci untuk membuat pola pergeseran yang lebih kompleks.',
        imagePath: 'assets/images/16.png',
        route: '/vigenere',
      ),
      CardItem(
        id: 3,
        title: 'Playfair Cipher',
        description: 'Enkripsi pasangan huruf menggunakan matriks 5x5.',
        imagePath: 'assets/images/17.png',
        route: '/playfair',
      ),
      CardItem(
        id: 4,
        title: 'Hill Cipher',
        description: 'Menggunakan operasi matriks untuk enkripsi blok huruf.',
        imagePath: 'assets/images/18.png',
        route: '/hill',
      ),
      CardItem(
        id: 5,
        title: 'Transposition Cipher',
        description: 'Mengacak posisi huruf tanpa mengubah karakternya.',
        imagePath: 'assets/images/19.png',
        route: '/transposition',
      ),
      CardItem(
        id: 6,
        title: 'ROT13',
        description:
            'Setiap huruf digeser 13 posisi dalam alfabet. Versi sederhana dari Caesar Cipher.',
        imagePath: 'assets/images/20.png',
        route: '/rot13',
      ),
      CardItem(
        id: 7,
        title: 'RSA',
        description: 'Kunci publik/privat untuk komunikasi aman.',
        imagePath: 'assets/images/21.png',
        route: '/rsa',
      ),
      CardItem(
        id: 8,
        title: 'AES',
        description: 'Standar enkripsi modern untuk proteksi data skala luas.',
        imagePath: 'assets/images/22.png',
        route: '/aes',
      ),
      CardItem(
        id: 9,
        title: 'DES',
        description:
            'Algoritma lama yang historis tapi sudah tidak direkomendasikan.',
        imagePath: 'assets/images/23.png',
        route: '/des',
      ),
      CardItem(
        id: 10,
        title: 'One-Time Pad',
        description:
            'Enkripsi sempurna jika kunci benar-benar acak & satu kali pakai.',
        imagePath: 'assets/images/24.png',
        route: '/otp',
      ),
      CardItem(
        id: 11,
        title: 'Hash (SHA)',
        description:
            'Fungsi satu arah untuk integritas data & penyimpanan password.',
        imagePath: 'assets/images/25.png',
        route: '/hash',
      ),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFE6E6E6),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const DescriptionPage(),
          Column(
            children: [
              // ✅ HEADER
              Container(
                width: double.infinity,
                height: 90,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF041413), Color(0xFF093B2B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/images/logoenkripsiapps.svg',
                        height: 42,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'KRIPTOGRAFI',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF11E482),
                          letterSpacing: 0.8,
                          shadows: [
                            Shadow(
                              blurRadius: 3,
                              color: Colors.black26,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: _opacity,
                  curve: Curves.easeInOut,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 600),
                    scale: _scale,
                    curve: Curves.easeOutBack,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      itemCount: cardItems.length,
                      separatorBuilder:
                          (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = cardItems[index];
                        return CustomCardView(
                          id: item.id,
                          title: item.title,
                          description: item.description,
                          imagePath: item.imagePath,
                          onPressed: () {
                            if (item.id == 1) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CaesarCipherPage(),
                                ),
                              );
                            } else if (item.id == 2) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const VigenereCipherPage(),
                                ),
                              );
                            } else if (item.id == 3) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PlayfairCipherPage(),
                                ),
                              );
                            } else if (item.id == 4) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HillCipherPage(),
                                ),
                              );
                            } else if (item.id == 5) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => const TranspositionCipherPage(),
                                ),
                              );
                            } else if (item.id == 6) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const Rot13CipherPage(),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 0),
            ],
          ),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        key: navigationKey,
        index: _selectedIndex,
        height: 60,
        backgroundColor: Colors.transparent,
        color: const Color(0xFF041413), // Header gradient gelap pertama
        buttonBackgroundColor: const Color(
          0xFF041413,
        ), // Hijau cerah seperti teks header
        animationDuration: const Duration(milliseconds: 400),
        items: [
          Icon(
            Icons.lock_rounded,
            size: 28,
            color:
                _selectedIndex == 0
                    ? const Color.fromARGB(255, 255, 255, 255)
                    : Colors.white,
          ),
          Icon(
            Icons.vpn_key_rounded,
            size: 28,
            color:
                _selectedIndex == 1
                    ? const Color.fromARGB(255, 255, 255, 255)
                    : Colors.white,
          ),
          Icon(
            Icons.person_rounded,
            size: 28,
            color:
                _selectedIndex == 2
                    ? const Color.fromARGB(255, 255, 255, 255)
                    : Colors.white,
          ),
        ],
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}

// =====================================================
// 🔹 DATA CARD
// =====================================================
class CardItem {
  final int id;
  final String title;
  final String description;
  final String imagePath;
  final String route;
  CardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.route,
  });
}

// =====================================================
// 🔹 KOMPONEN CARD CUSTOM
// =====================================================
class CustomCardView extends StatefulWidget {
  final int id;
  final String title;
  final String description;
  final String imagePath;
  final VoidCallback onPressed;

  const CustomCardView({
    super.key,
    required this.id,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.onPressed,
  });

  @override
  State<CustomCardView> createState() => _CustomCardViewState();
}

class _CustomCardViewState extends State<CustomCardView>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(_) => setState(() => _scale = 0.9);
  void _onTapUp(_) => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE6E6E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child:
                    widget.imagePath.endsWith('.svg')
                        ? SvgPicture.asset(
                          widget.imagePath,
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                        )
                        : Image.asset(
                          widget.imagePath,
                          width: 55,
                          height: 55,
                          fit: BoxFit.contain,
                        ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              height: 60,
              width: 1.5,
              color: Colors.grey.shade300,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF041413),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTapDown: _onTapDown,
                    onTapUp: _onTapUp,
                    onTapCancel: () => setState(() => _scale = 1.0),
                    onTap: widget.onPressed,
                    child: AnimatedScale(
                      scale: _scale,
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      child: ElevatedButton(
                        onPressed: widget.onPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF041413),
                          fixedSize: const Size(85, 33),
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Algoritma',
                          style: TextStyle(fontSize: 13, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
