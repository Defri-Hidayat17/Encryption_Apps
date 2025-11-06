import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Import halaman
import 'splash_screen.dart';
import 'onboarding_page.dart';
import 'home_page.dart';
import 'caesarcipher.dart';
import 'description_page.dart';
import 'profile_page.dart';
import 'loginpage.dart';
import 'biodata_page.dart';

// ✅ Tambahkan global key untuk ScaffoldMessenger
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('⚠️ Firebase initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey, // ✅ key global
      debugShowCheckedModeBanner: false,
      title: 'Enkripsi App',
      theme: ThemeData(
        colorSchemeSeed: Colors.tealAccent,
        scaffoldBackgroundColor: const Color(0xFFE6E6E6),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return GestureDetector(
          onTap: () {
            FocusScopeNode focus = FocusScope.of(context);
            if (!focus.hasPrimaryFocus && focus.focusedChild != null) {
              focus.focusedChild!.unfocus();
            }
          },
          child: child,
        );
      },
      home: const SplashScreen(),
      routes: {
        '/onboarding': (context) => const OnboardingPage(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/mainnav': (context) => const MainNavigationPage(),
        '/biodata': (context) => const BiodataPage(),
        '/profil': (context) => const ProfilePage(),
      },
    );
  }
}

// =======================================================
// 🔑 Halaman utama dengan Curved Navigation Bar
// =======================================================

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _currentIndex = 1;

  final List<Widget> _pages = [
    const DescriptionPage(),
    const CaesarCipherPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        height: 75, // beri tinggi pasti agar tidak "loncat"
        decoration: const BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.transparent, // hilangkan efek abu-abu
              blurRadius: 0,
              offset: Offset(0, 0),
            ),
          ],
        ),
        child: CurvedNavigationBar(
          index: _currentIndex,
          height: 60,
          backgroundColor: Colors.transparent, // penting biar gak abu-abu
          color: Colors.black,
          buttonBackgroundColor: Colors.white,
          animationDuration: const Duration(milliseconds: 350),
          items: [
            _buildNavItem(Icons.info_rounded, 0),
            _buildNavItem(Icons.vpn_key_rounded, 1),
            _buildNavItem(Icons.person_rounded, 2),
          ],
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final bool isActive = _currentIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(4), // jarak dari border biar gak nempel
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isActive ? Border.all(color: Colors.black, width: 2.2) : null,
      ),
      child: Icon(
        icon,
        size: isActive ? 27 : 25,
        color: isActive ? Colors.black : Colors.white,
      ),
    );
  }
}
