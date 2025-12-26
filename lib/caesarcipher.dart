import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences

class CaesarCipherPage extends StatefulWidget {
  const CaesarCipherPage({super.key});

  @override
  State<CaesarCipherPage> createState() => _CaesarCipherPageState();
}

enum CipherMode { encrypt, decrypt }

class _CaesarCipherPageState extends State<CaesarCipherPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _plainController = TextEditingController();
  final TextEditingController _cipherController = TextEditingController();
  final TextEditingController _shiftDecryptController = TextEditingController();

  String _result = '';
  int _autoShift = 0; // Key for encryption
  CipherMode _currentMode = CipherMode.encrypt;
  bool _useShiftKeyForDecrypt = true; // Default: use key for decryption

  // Keys for SharedPreferences
  static const String _plainTextKey = 'plainText';
  static const String _cipherTextKey = 'cipherText';
  static const String _shiftDecryptKey = 'shiftDecrypt';
  static const String _cipherModeKey = 'cipherMode';
  static const String _useShiftKeyForDecryptKey = 'useShiftKeyForDecrypt';
  static const String _autoShiftKey =
      'autoShift'; // To save the auto-generated shift

  @override
  void initState() {
    super.initState();
    // Set status bar icons to dark (for white status bar)
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.dark.copyWith(
        statusBarIconBrightness: Brightness.dark, // For Android (dark icons)
        statusBarBrightness: Brightness.light, // For iOS (dark icons)
        statusBarColor:
            Colors
                .transparent, // Transparent status bar to show app's background
      ),
    );

    _loadData(); // Load saved data on init

    // Add listeners to controllers for auto-save
    _plainController.addListener(_saveData);
    _cipherController.addListener(_saveData);
    _shiftDecryptController.addListener(_saveData);
  }

  @override
  void dispose() {
    // Remove listeners to prevent memory leaks
    _plainController.removeListener(_saveData);
    _cipherController.removeListener(_saveData);
    _shiftDecryptController.removeListener(_saveData);

    _plainController.dispose();
    _cipherController.dispose();
    _shiftDecryptController.dispose();
    super.dispose();
  }

  // ============================
  // 💾 Fungsi untuk menyimpan data ke SharedPreferences
  // ============================
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plainTextKey, _plainController.text);
    await prefs.setString(_cipherTextKey, _cipherController.text);
    await prefs.setString(_shiftDecryptKey, _shiftDecryptController.text);
    await prefs.setInt(_cipherModeKey, _currentMode.index);
    await prefs.setBool(_useShiftKeyForDecryptKey, _useShiftKeyForDecrypt);
    await prefs.setInt(_autoShiftKey, _autoShift);
  }

  // ============================
  // 📥 Fungsi untuk memuat data dari SharedPreferences
  // ============================
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _plainController.text = prefs.getString(_plainTextKey) ?? '';
      _cipherController.text = prefs.getString(_cipherTextKey) ?? '';
      _shiftDecryptController.text = prefs.getString(_shiftDecryptKey) ?? '';
      _currentMode =
          CipherMode.values[prefs.getInt(_cipherModeKey) ??
              0]; // Default to encrypt
      _useShiftKeyForDecrypt = prefs.getBool(_useShiftKeyForDecryptKey) ?? true;
      _autoShift = prefs.getInt(_autoShiftKey) ?? 0;
    });
  }

  // ============================
  // 🔄 Fungsi untuk mengosongkan semua input dan hasil
  // ============================
  void _clearAll() {
    setState(() {
      _plainController.clear();
      _cipherController.clear();
      _shiftDecryptController.clear();
      _result = '';
      _autoShift = 0;
      _currentMode = CipherMode.encrypt; // Reset mode to encrypt
      _useShiftKeyForDecrypt = true; // Reset switch
    });
    _saveData(); // Save the cleared state
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua input dan hasil telah dikosongkan!')),
    );
  }

  // ============================
  // 📝 Fungsi untuk membuat pesan yang akan dibagikan
  // ============================
  String _buildMessageForSharing() {
    String message = '';
    if (_currentMode == CipherMode.encrypt) {
      message = '''
💀 ENCRYPTED MESSAGE - CYBER OPS TEAM

━━━━━━━━━━━━━━━━━━
🧠 Kode Enkripsi:
$_result

🔓 Petunjuk Dekripsi:
Gunakan shift $_autoShift untuk membuka pesan ini.

━━━━━━━━━━━━━━━━━━

📘 Pesan ini dibuat otomatis dari aplikasi Enkripsi by Defri
''';
    } else {
      if (_useShiftKeyForDecrypt) {
        // Manual Decryption
        final decryptedText =
            _result.split('\n').first; // Ambil baris pertama jika ada banyak
        message = '''
🔓 DECRYPTED MESSAGE - CYBER OPS TEAM

━━━━━━━━━━━━━━━━━━
🧠 Hasil Dekripsi:
$decryptedText

🔑 Key Digunakan:
${_shiftDecryptController.text}
━━━━━━━━━━━━━━━━━━

🧬 📘 Pesan ini dibuat otomatis dari aplikasi Enkripsi by Defri
''';
      } else {
        // Brute-Force Decryption
        message = '''
🕵️ BRUTE-FORCE DECRYPTION RESULTS - CYBER OPS TEAM

━━━━━━━━━━━━━━━━━━
🧠 Hasil Brute-Force:
$_result
━━━━━━━━━━━━━━━━━━

🧬 📘 Pesan ini dibuat otomatis dari aplikasi Enkripsi by Defri
''';
      }
    }
    return message;
  }

  // ============================
  // 🔐 Fungsi kirim ke Gmail (langsung buka aplikasi Gmail)
  // ============================
  Future<void> _sendToGmail() async {
    if (_result.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada hasil yang bisa dikirim.')),
      );
      return;
    }

    final String message = _buildMessageForSharing();
    final String subject =
        _currentMode == CipherMode.encrypt
            ? '🔐 Encrypted Message (Confidential)'
            : '🔓 Decrypted Message / Brute-Force Results';

    final String encodedSubject = Uri.encodeComponent(subject);
    final String encodedBody = Uri.encodeComponent(message);

    final Uri mailtoUri = Uri.parse(
      'mailto:?subject=$encodedSubject&body=$encodedBody',
    );

    try {
      await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membuka aplikasi email...')),
      );
    } catch (e) {
      final webGmailUrl = Uri.parse(
        'https://mail.google.com/mail/?view=cm&fs=1&su=$encodedSubject&body=$encodedBody',
      );
      try {
        await launchUrl(webGmailUrl, mode: LaunchMode.platformDefault);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membuka Gmail versi web...')),
        );
      } catch (e2) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal membuka Gmail: $e2')));
      }
    }
  }

  // ============================
  // 🔒 Fungsi Caesar Cipher
  // ============================
  String caesarEncrypt(String text, int shift) {
    final buffer = StringBuffer();
    for (var char in text.runes) {
      if (char >= 65 && char <= 90) {
        // Uppercase letters
        buffer.writeCharCode(((char - 65 + shift) % 26) + 65);
      } else if (char >= 97 && char <= 122) {
        // Lowercase letters
        buffer.writeCharCode(((char - 97 + shift) % 26) + 97);
      } else {
        buffer.writeCharCode(char); // Non-alphabetic characters
      }
    }
    return buffer.toString();
  }

  String caesarDecrypt(String text, int shift) {
    // Decryption is just encryption with a negative shift
    return caesarEncrypt(text, -shift);
  }

  // ============================
  // ⚙️ Fungsi enkripsi otomatis
  // ============================
  void _autoEncrypt() {
    final text = _plainController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan teks terlebih dahulu!')),
      );
      return;
    }

    final randomShift = Random().nextInt(25) + 1;
    final encrypted = caesarEncrypt(text, randomShift);

    setState(() {
      _autoShift = randomShift;
      _result = encrypted;
      _cipherController.text = encrypted; // Update cipher text field
    });
    _saveData(); // Save new autoShift and result
  }

  // ============================
  // ⚙️ Fungsi dekripsi manual (dengan key)
  // ============================
  void _manualDecryptWithKey() {
    final text = _cipherController.text.trim();
    final shiftText = _shiftDecryptController.text.trim();

    if (text.isEmpty || shiftText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan teks dan shift key terlebih dahulu!'),
        ),
      );
      return;
    }

    int? shift = int.tryParse(shiftText);
    if (shift == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift key harus berupa angka!')),
      );
      return;
    }

    final decrypted = caesarDecrypt(text, shift);

    setState(() {
      _result = decrypted;
      _plainController.text = decrypted; // Update plain text field
    });
    _saveData(); // Save new result
  }

  // ============================
  // ⚙️ Fungsi dekripsi brute-force (tanpa key)
  // ============================
  void _bruteForceDecrypt() {
    final text = _cipherController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan teks terenkripsi terlebih dahulu!'),
        ),
      );
      return;
    }

    final StringBuffer bruteForceResults = StringBuffer();
    for (int shift = 1; shift <= 25; shift++) {
      final decrypted = caesarDecrypt(text, shift);
      bruteForceResults.writeln('Shift $shift: $decrypted');
    }

    setState(() {
      _result = bruteForceResults.toString();
      _plainController.text =
          ''; // Clear plain text controller as it's multiple results
    });
    _saveData(); // Save new result
  }

  // ============================
  // 💬 Fungsi kirim ke WhatsApp
  // ============================
  Future<void> _sendToWhatsApp() async {
    if (_result.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada hasil yang bisa dikirim.')),
      );
      return;
    }

    final message = _buildMessageForSharing();
    final String whatsappMessage = message.replaceAll(
      '```',
      '',
    ); // WhatsApp doesn't render ``` as code blocks

    await Clipboard.setData(ClipboardData(text: whatsappMessage));

    final encodedMessage = Uri.encodeComponent(whatsappMessage);
    final whatsappUri = Uri.parse("whatsapp://send?text=$encodedMessage");

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesan disalin dan WhatsApp dibuka!')),
        );
      } else {
        final fallbackUrl = Uri.parse("https://wa.me/?text=$encodedMessage");
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuka WhatsApp: $e')));
    }
  }

  // ============================
  // 🧱 UI
  // ============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFE6E6E6), // Original background color
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              height: 70, // Slightly taller header for more premium feel
              width: double.infinity,
              color: const Color(0xFF041413), // Original header color (dark)
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 12,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                      iconSize: 24, // Slightly larger icon
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  SvgPicture.asset(
                    'assets/images/logoenkripsiapps.svg',
                    width: 50, // Slightly larger logo
                    height: 50,
                  ),
                  Positioned(
                    right: 12,
                    child: IconButton(
                      icon: const Icon(
                        Icons.refresh, // Refresh icon
                        color: Colors.white,
                      ),
                      iconSize: 24,
                      onPressed: _clearAll, // Call _clearAll function
                    ),
                  ),
                ],
              ),
            ),

            // Mode Toggle (STUCK DI BAWAH HEADER)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 15.0,
              ), // Padding horizontal untuk kontainer toggle
              child: Container(
                width: double.infinity, // Make container full width
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[200], // Subtle grey for toggle background
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final buttonWidth = (constraints.maxWidth - 8) / 2;

                    return ToggleButtons(
                      isSelected: [
                        _currentMode == CipherMode.encrypt,
                        _currentMode == CipherMode.decrypt,
                      ],
                      onPressed: (index) {
                        setState(() {
                          _currentMode =
                              index == 0
                                  ? CipherMode.encrypt
                                  : CipherMode.decrypt;
                          _result = ''; // Clear result on mode change
                          // Don't clear controllers here, let auto-save handle it
                          // _plainController.clear();
                          // _cipherController.clear();
                          // _shiftDecryptController.clear();
                          _useShiftKeyForDecrypt =
                              true; // Reset switch on mode change
                        });
                        _saveData(); // Save the new mode and switch state
                      },
                      borderRadius: BorderRadius.circular(10),
                      selectedColor: Colors.white, // White text for selected
                      color: Colors.black87, // Dark text for unselected
                      fillColor: const Color(
                        0xFF041413,
                      ), // Original header color for selected fill
                      borderColor: Colors.transparent,
                      selectedBorderColor: Colors.transparent,
                      splashColor: const Color(0xFF041413).withOpacity(0.2),
                      highlightColor: const Color(0xFF041413).withOpacity(0.1),
                      children: [
                        SizedBox(
                          width: buttonWidth,
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10, // Adjusted horizontal padding
                                vertical: 10, // Adjusted vertical padding
                              ),
                              child: Text(
                                'Enkripsi',
                                style: TextStyle(
                                  fontSize: 15, // Adjusted font size
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10, // Adjusted horizontal padding
                                vertical: 10, // Adjusted vertical padding
                              ),
                              child: Text(
                                'Dekripsi',
                                style: TextStyle(
                                  fontSize: 15, // Adjusted font size
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // BODY (BISA DI-SCROLL)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                ), // Padding horizontal untuk konten body
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentMode == CipherMode.encrypt) ...[
                      const Text(
                        'Masukkan teks untuk dienkripsi:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        _plainController,
                        'Tulis teks...',
                        TextInputType.text,
                      ),
                      const SizedBox(height: 20),
                      _buildActionButton(
                        'Enkripsi Otomatis',
                        _autoEncrypt,
                        const Color(0xFF041413), // Original button color
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Hasil Enkripsi:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildResultContainer(
                        _result.isEmpty
                            ? 'Hasil akan muncul di sini...'
                            : _result,
                      ),
                      // New: Key box for encryption
                      if (_result.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Shift Key Digunakan:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildResultContainer('$_autoShift'),
                      ],
                      const SizedBox(height: 10),
                      if (_result.isNotEmpty) _buildCopyButtons(),
                    ] else ...[
                      const Text(
                        'Masukkan teks untuk didekripsi:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildTextField(
                        _cipherController,
                        'Tulis teks terenkripsi...',
                        TextInputType.text,
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Gunakan Shift Key',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          Switch(
                            value: _useShiftKeyForDecrypt,
                            onChanged: (bool value) {
                              setState(() {
                                _useShiftKeyForDecrypt = value;
                                _result = ''; // Clear result when mode changes
                                _shiftDecryptController
                                    .clear(); // Clear shift key input
                              });
                              _saveData(); // Save new switch state
                            },
                            activeColor: const Color(
                              0xFF041413,
                            ), // Match header color
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      if (_useShiftKeyForDecrypt) ...[
                        const Text(
                          'Masukkan Shift Key:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          _shiftDecryptController,
                          'Contoh: 3',
                          TextInputType.number,
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        const SizedBox(
                          height: 20,
                        ), // Provide some spacing if key input is hidden
                      ],

                      _buildActionButton(
                        _useShiftKeyForDecrypt
                            ? 'Dekripsi Teks'
                            : 'Brute-Force Dekripsi',
                        _useShiftKeyForDecrypt
                            ? _manualDecryptWithKey
                            : _bruteForceDecrypt,
                        const Color(0xFF041413), // Original button color
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Hasil Dekripsi:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildResultContainer(
                        _result.isEmpty
                            ? 'Hasil akan muncul di sini...'
                            : _result,
                      ),
                      const SizedBox(height: 10),
                      if (_result.isNotEmpty) _buildCopyButtons(),
                    ],

                    const SizedBox(height: 30),
                    const Divider(
                      color: Colors.black12,
                      thickness: 1.5,
                    ), // Slightly thicker divider
                    const SizedBox(height: 8),

                    const Text(
                      '📘 Penjelasan Kriptografi:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const SelectableText(
                      'Caesar Cipher adalah teknik enkripsi sederhana dengan menggeser huruf alfabet sejumlah posisi tertentu.\n'
                      'Pada versi enkripsi, pergeseran ditentukan otomatis oleh sistem (acak antara 1–25).\n'
                      'Contoh: dengan shift 3, A → D, B → E, C → F, dst.',
                      style: TextStyle(color: Colors.black87, height: 1.4),
                    ),

                    const SizedBox(height: 32),
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'Send encryption code to',
                            style: TextStyle(
                              fontSize: 17, // Slightly larger font
                              fontWeight: FontWeight.w700, // Bolder
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),

                          Container(
                            width: 180,
                            height: 1.5,
                            color: Colors.black26,
                          ),
                          const SizedBox(height: 20),

                          // 🔗 IKON SOSIAL
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // WhatsApp
                              _buildSocialButton(
                                'assets/images/wa.svg',
                                _sendToWhatsApp,
                              ),
                              const SizedBox(width: 40),

                              // Gmail
                              _buildSocialButton(
                                'assets/images/gmail.svg', // Path sudah benar
                                _sendToGmail,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hintText,
    TextInputType keyboardType,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Original text field color
        borderRadius: BorderRadius.circular(
          12,
        ), // Slightly larger border radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // Subtle shadow
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.done,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[500]),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none, // Remove default border line
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF041413),
              width: 2,
            ), // Darker, more prominent focus border
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, VoidCallback onPressed, Color color) {
    return Center(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color, // Original button color
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shadowColor: Colors.black.withOpacity(0.3), // More prominent shadow
          elevation: 8, // Higher elevation
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ), // Stronger font weight
        ),
      ),
    );
  }

  Widget _buildResultContainer(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, // Original result container color
        borderRadius: BorderRadius.circular(
          12,
        ), // Slightly larger border radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SelectableText(
        text,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ), // Original text color
      ),
    );
  }

  Widget _buildCopyButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _result));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Hasil disalin!')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF041413), // Original button color
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              shadowColor: Colors.black.withOpacity(0.2),
              elevation: 4,
            ),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text(
              'Salin Hasil',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ),
        if (_currentMode == CipherMode.encrypt) ...[
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                final info =
                    'Gunakan shift $_autoShift untuk mendekripsi pesan ini.';
                Clipboard.setData(ClipboardData(text: info));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Petunjuk "$info" disalin!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(
                  0xFF041413,
                ), // Original button color
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                shadowColor: Colors.black.withOpacity(0.2),
                elevation: 4,
              ),
              icon: const Icon(Icons.info_outline, size: 18),
              label: const Text(
                'Salin Petunjuk',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSocialButton(String assetPath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white, // Original social button color
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                0.15,
              ), // Slightly more pronounced shadow
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: SvgPicture.asset(
            assetPath,
            width: 32,
            height: 32,
            // Removed ColorFilter to use original SVG colors, assuming they are dark/colored
          ),
        ),
      ),
    );
  }
}
