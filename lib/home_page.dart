import 'package:encryptionapps/aes_page.dart';
import 'package:encryptionapps/rsa_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

// Import halaman cipher yang sudah diperbarui
import 'caesarcipher.dart'; // Pastikan ini adalah versi terbaru
import 'vigenerecipher.dart'; // Pastikan ini adalah versi terbaru
import 'file_crypto_page.dart';
import 'playfaircipher.dart'; // Pastikan ini adalah versi terbaru
import 'hillcipher.dart'; // Pastikan ini adalah versi terbaru
import 'transpositioncipher.dart'; // Pastikan ini adalah versi terbaru
import 'rot13.dart'; // Pastikan ini adalah versi terbaru
import 'des_page.dart';
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
    // Atur status bar saat halaman pertama kali dimuat
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white, // Status bar wajib putih
        statusBarIconBrightness:
            Brightness.dark, // Ikon gelap agar terlihat di status bar putih
      ),
    );

    Future.delayed(const Duration(milliseconds: 180), () {
      setState(() {
        _opacity = 1;
        _scale = 1.0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pastikan status bar style diterapkan kembali setiap kali build dipanggil
    // Ini penting agar style tetap konsisten saat kembali dari halaman lain
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white, // Status bar wajib putih
        statusBarIconBrightness:
            Brightness.dark, // Ikon gelap agar terlihat di status bar putih
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
      body: SafeArea(
        // SafeArea membungkus seluruh body
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            const FileCryptoPage(),
            Column(
              children: [
                // ✅ HEADER
                Container(
                  width: double.infinity,
                  height: 58, // Tinggi header disesuaikan
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
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .center, // Pusatkan konten secara vertikal
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
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          0,
                        ), // Padding bawah 0 karena bottomNavigationBar
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
                              // Menggunakan Navigator.push untuk berpindah halaman
                              Widget targetPage;
                              switch (item.id) {
                                case 1:
                                  targetPage = const CaesarCipherPage();
                                  break;
                                case 2:
                                  targetPage = const VigenereCipherPage();
                                  break;
                                case 3:
                                  targetPage = const PlayfairCipherPage();
                                  break;
                                case 4:
                                  targetPage = const HillCipherPage();
                                  break;
                                case 5:
                                  targetPage = const TranspositionCipherPage();
                                  break;
                                case 6:
                                  targetPage = const Rot13CipherPage();
                                  break;
                                case 7:
                                  targetPage = const RsaPage();
                                  break;
                                case 8:
                                  targetPage = const AesPage();
                                  break;
                                case 9:
                                  targetPage = const DesPage();
                                  break;
                                // Tambahkan case untuk cipher lainnya jika sudah dibuat
                                default:
                                  targetPage =
                                      const Placeholder(); // Halaman placeholder jika belum ada
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => targetPage),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const ProfilePage(),
          ],
        ),
      ), // End of SafeArea
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
  // Menggunakan _scale untuk efek tap pada seluruh card
  double _scale = 1.0;

  void _onTapDown(_) =>
      setState(() => _scale = 0.98); // Sedikit mengecil saat ditekan
  void _onTapUp(_) => setState(() => _scale = 1.0);
  void _onTapCancel() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // GestureDetector membungkus seluruh card
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed, // Panggil onPressed saat card ditekan
      child: AnimatedScale(
        // Animasi skala diterapkan pada seluruh card
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Card(
          elevation: 4,
          shadowColor: Colors.black26,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
                        overflow:
                            TextOverflow.ellipsis, // <-- Perbaikan di sini
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Tombol "Algoritma" sekarang hanya teks, tap ditangani oleh GestureDetector di atas
                      Container(
                        width: 85,
                        height: 33,
                        decoration: BoxDecoration(
                          color: const Color(0xFF041413),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Algoritma',
                          style: TextStyle(fontSize: 13, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
