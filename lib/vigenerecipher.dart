import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences

class VigenereCipherPage extends StatefulWidget {
  const VigenereCipherPage({super.key});

  @override
  State<VigenereCipherPage> createState() => _VigenereCipherPageState();
}

enum CipherMode { encrypt, decrypt } // Tambahkan enum untuk mode

class _VigenereCipherPageState extends State<VigenereCipherPage> {
  final TextEditingController _plainController = TextEditingController();
  final TextEditingController _cipherController =
      TextEditingController(); // Controller untuk teks terenkripsi
  final TextEditingController _decryptKeyController =
      TextEditingController(); // Controller untuk kunci dekripsi

  String _result = '';
  String _autoKey = ''; // 🔑 Kunci otomatis yang dibuat sistem (untuk enkripsi)
  CipherMode _currentMode = CipherMode.encrypt; // Default mode: enkripsi
  bool _useKeyForDecrypt = true; // Default: gunakan kunci untuk dekripsi

  // Keys for SharedPreferences
  static const String _plainTextKey = 'vigenerePlainText';
  static const String _cipherTextKey = 'vigenereCipherText'; // Key baru
  static const String _decryptKeyKey = 'vigenereDecryptKey'; // Key baru
  static const String _autoKeyKey = 'vigenereAutoKey';
  static const String _cipherModeKey = 'vigenereCipherMode'; // Key baru
  static const String _useKeyForDecryptKey =
      'vigenereUseKeyForDecrypt'; // Key baru

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
    _cipherController.addListener(_saveData); // Tambahkan listener
    _decryptKeyController.addListener(_saveData); // Tambahkan listener
  }

  @override
  void dispose() {
    // Remove listeners to prevent memory leaks
    _plainController.removeListener(_saveData);
    _cipherController.removeListener(_saveData); // Hapus listener
    _decryptKeyController.removeListener(_saveData); // Hapus listener

    _plainController.dispose();
    _cipherController.dispose(); // Dispose controller
    _decryptKeyController.dispose(); // Dispose controller
    super.dispose();
  }

  // ============================
  // 💾 Fungsi untuk menyimpan data ke SharedPreferences
  // ============================
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plainTextKey, _plainController.text);
    await prefs.setString(_cipherTextKey, _cipherController.text);
    await prefs.setString(_decryptKeyKey, _decryptKeyController.text);
    await prefs.setString(_autoKeyKey, _autoKey);
    await prefs.setInt(_cipherModeKey, _currentMode.index); // Simpan mode
    await prefs.setBool(
      _useKeyForDecryptKey,
      _useKeyForDecrypt,
    ); // Simpan status switch

    print('--- DATA SAVED ---');
    print('Plain Text: "${_plainController.text}"');
    print('Cipher Text: "${_cipherController.text}"');
    print('Decrypt Key: "${_decryptKeyController.text}"');
    print('Auto Key: "$_autoKey"');
    print('Mode: $_currentMode');
    print('Use Key for Decrypt: $_useKeyForDecrypt');
    print('------------------');
  }

  // ============================
  // 📥 Fungsi untuk memuat data dari SharedPreferences
  // ============================
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _plainController.text = prefs.getString(_plainTextKey) ?? '';
      _cipherController.text = prefs.getString(_cipherTextKey) ?? '';
      _decryptKeyController.text = prefs.getString(_decryptKeyKey) ?? '';
      _autoKey = prefs.getString(_autoKeyKey) ?? '';
      _currentMode =
          CipherMode.values[prefs.getInt(_cipherModeKey) ?? 0]; // Muat mode
      _useKeyForDecrypt =
          prefs.getBool(_useKeyForDecryptKey) ?? true; // Muat status switch

      print('--- DATA LOADED ---');
      print('Plain Text: "${_plainController.text}"');
      print(
        'Cipher Text (from prefs): "${_cipherController.text}"',
      ); // Debugging
      print('Decrypt Key: "${_decryptKeyController.text}"');
      print('Auto Key: "$_autoKey"');
      print('Mode: $_currentMode');
      print('Use Key for Decrypt: $_useKeyForDecrypt');
      print('-------------------');

      // Re-calculate result based on loaded data and mode
      if (_currentMode == CipherMode.encrypt &&
          _plainController.text.isNotEmpty &&
          _autoKey.isNotEmpty) {
        _result = vigenereEncrypt(_plainController.text, _autoKey);
        _cipherController.text =
            _result; // <--- BARIS YANG DITAMBAHKAN/DIPERBARUI
        print('Recalculated Encrypt Result: $_result');
        print(
          'Cipher Text (after sync): "${_cipherController.text}"',
        ); // Debugging
      } else if (_currentMode == CipherMode.decrypt &&
          _useKeyForDecrypt &&
          _cipherController.text.isNotEmpty &&
          _decryptKeyController.text.isNotEmpty) {
        _result = vigenereDecrypt(
          _cipherController.text,
          _decryptKeyController.text,
        );
        print('Recalculated Decrypt Result: $_result');
      } else {
        _result =
            ''; // Clear result if no relevant data or mode is inconsistent
        print('Result cleared due to inconsistent state.');
      }
    });
  }

  // ============================
  // 🔄 Fungsi untuk mengosongkan semua input dan hasil
  // ============================
  void _clearAll() {
    setState(() {
      _plainController.clear();
      _cipherController.clear();
      _decryptKeyController.clear();
      _result = '';
      _autoKey = '';
      _currentMode = CipherMode.encrypt; // Reset mode to encrypt
      _useKeyForDecrypt = true; // Reset switch
    });
    _saveData(); // Save the cleared state
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua input dan hasil telah dikosongkan!')),
    );
  }

  // ========================================
  // 🔒 Fungsi enkripsi Vigenere Cipher
  // ========================================
  String vigenereEncrypt(String text, String key) {
    if (key.isEmpty) return text;
    key = key.toUpperCase();

    final buffer = StringBuffer();
    int keyIndex = 0;

    for (var rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'[A-Za-z]').hasMatch(char)) {
        int base = char.toUpperCase() == char ? 65 : 97;
        int shift = key.codeUnitAt(keyIndex % key.length) - 65;
        int encrypted = ((rune - base + shift) % 26) + base;
        buffer.writeCharCode(encrypted);
        keyIndex++;
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  // ========================================
  // 🔓 Fungsi dekripsi Vigenere Cipher
  // ========================================
  String vigenereDecrypt(String text, String key) {
    if (key.isEmpty) return text;
    key = key.toUpperCase();

    final buffer = StringBuffer();
    int keyIndex = 0;

    for (var rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'[A-Za-z]').hasMatch(char)) {
        int base = char.toUpperCase() == char ? 65 : 97;
        int shift = key.codeUnitAt(keyIndex % key.length) - 65;
        // Tambahkan 26 sebelum modulo untuk memastikan hasilnya positif
        int decrypted = ((rune - base - shift + 26) % 26) + base;
        buffer.writeCharCode(decrypted);
        keyIndex++;
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  // ========================================
  // ⚙️ Membuat kunci otomatis
  // ========================================
  String _generateAutoKey(String text) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = Random();
    String key = '';
    // Generate a key with the same length as the alphabetic characters in the text
    for (int i = 0; i < text.length; i++) {
      if (RegExp(r'[A-Za-z]').hasMatch(text[i])) {
        key += alphabet[random.nextInt(alphabet.length)];
      }
    }
    return key;
  }

  // ========================================
  // 🚀 Enkripsi otomatis tanpa input kunci
  // ========================================
  void _autoEncrypt() {
    final text = _plainController.text.trim();

    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan teks terlebih dahulu!')),
      );
      return;
    }

    final key = _generateAutoKey(text);
    final encrypted = vigenereEncrypt(text, key);

    setState(() {
      _autoKey = key;
      _result = encrypted;
      _cipherController.text =
          encrypted; // Update cipher text field for potential decryption
    });
    // _saveData(); // Dihapus, karena sudah dihandle oleh listener atau panggilan di onPressed
  }

  // ========================================
  // 🔑 Dekripsi dengan kunci
  // ========================================
  void _decryptWithKey() {
    final text = _cipherController.text.trim();
    final key = _decryptKeyController.text.trim();

    if (text.isEmpty || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan teks terenkripsi dan kunci dekripsi!'),
        ),
      );
      return;
    }

    final decrypted = vigenereDecrypt(text, key);

    setState(() {
      _result = decrypted;
      _plainController.text =
          decrypted; // Update plain text field for potential re-encryption
    });
    // _saveData(); // Dihapus, karena sudah dihandle oleh listener atau panggilan di onPressed
  }

  // ========================================
  // 🚫 Pesan untuk dekripsi tanpa kunci
  // ========================================
  void _showKeyRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Vigenère Cipher sangat sulit didekripsi tanpa kunci yang benar. Silakan gunakan kunci untuk dekripsi.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
    setState(() {
      _result = 'Dekripsi tanpa kunci tidak disarankan untuk Vigenère Cipher.';
    });
  }

  // ============================
  // 📝 Fungsi untuk membuat pesan yang akan dibagikan
  // ============================
  String _buildMessageForSharing() {
    if (_currentMode == CipherMode.encrypt) {
      return '''
🧩 *Kode Cipher Enkripsi (Vigenère)*

━━━━━━━━━━━━━━━
🔐 *Hasil Enkripsi:*
```$_result```

📜 *Petunjuk Dekripsi:*
Gunakan *kunci "$_autoKey"* untuk membuka pesan ini.
━━━━━━━━━━━━━━━

📘 _Pesan ini dibuat otomatis dari aplikasi Enkripsi by Defri_
''';
    } else {
      return '''
🔓 *Hasil Dekripsi (Vigenère)*

━━━━━━━━━━━━━━━
🧠 *Hasil Dekripsi:*
```$_result```

🔑 *Kunci Digunakan:*
"${_decryptKeyController.text}"
━━━━━━━━━━━━━━━

📘 _Pesan ini dibuat otomatis dari aplikasi Enkripsi by Defri_
''';
    }
  }

  // ========================================
  // 💬 Kirim ke WhatsApp
  // ========================================
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

  // ========================================
  // 📧 Kirim ke Gmail
  // ========================================
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
            : '🔓 Decrypted Message';
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

  // ========================================
  // 🧱 UI
  // ========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFE6E6E6),
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
                          final oldMode = _currentMode;
                          final newMode =
                              index == 0
                                  ? CipherMode.encrypt
                                  : CipherMode.decrypt;

                          // Simpan hasil/input saat ini sebelum membersihkan
                          final String currentEncryptResult =
                              _result; // Ini adalah teks terenkripsi jika dalam mode enkripsi
                          final String currentAutoKey =
                              _autoKey; // Ini adalah kunci yang dibuat otomatis jika dalam mode enkripsi
                          final String currentDecryptResult =
                              _result; // Ini adalah teks terdekripsi jika dalam mode dekripsi

                          // Bersihkan semua input dan hasil terlebih dahulu
                          _plainController.clear();
                          _cipherController.clear();
                          _decryptKeyController.clear();
                          _result = '';
                          _autoKey = '';

                          _currentMode = newMode; // Perbarui mode
                          _useKeyForDecrypt =
                              true; // Reset switch untuk mode dekripsi

                          if (oldMode == CipherMode.encrypt &&
                              newMode == CipherMode.decrypt) {
                            // Transisi dari Enkripsi ke Dekripsi
                            if (currentEncryptResult.isNotEmpty) {
                              _cipherController.text =
                                  currentEncryptResult; // Teks terenkripsi menjadi input untuk dekripsi
                              _decryptKeyController.text =
                                  currentAutoKey; // Kunci otomatis menjadi kunci dekripsi
                            }
                          } else if (oldMode == CipherMode.decrypt &&
                              newMode == CipherMode.encrypt) {
                            // Transisi dari Dekripsi ke Enkripsi
                            if (currentDecryptResult.isNotEmpty) {
                              _plainController.text =
                                  currentDecryptResult; // Teks terdekripsi menjadi input untuk enkripsi
                            }
                          }

                          // Setelah mengatur controller, picu perhitungan ulang jika input tersedia
                          if (_currentMode == CipherMode.encrypt &&
                              _plainController.text.isNotEmpty) {
                            _autoEncrypt(); // Enkripsi ulang jika teks biasa ada
                          } else if (_currentMode == CipherMode.decrypt &&
                              _cipherController.text.isNotEmpty &&
                              _decryptKeyController.text.isNotEmpty) {
                            _decryptWithKey(); // Dekripsi ulang jika teks cipher dan kunci ada
                          }
                        });
                        _saveData(); // Simpan mode baru dan teks controller yang mungkin diperbarui
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
                        const Color(0xFF041413),
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
                      const SizedBox(height: 10),

                      if (_result.isNotEmpty) ...[
                        const Text(
                          'Kunci Otomatis Digunakan:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildResultContainer(_autoKey),
                      ],
                      const SizedBox(height: 10),

                      if (_result.isNotEmpty) _buildCopyButtons(),
                    ] else ...[
                      // UI untuk Dekripsi
                      const Text(
                        'Masukkan teks terenkripsi:',
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
                            'Gunakan Kunci Dekripsi',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          Switch(
                            value: _useKeyForDecrypt,
                            onChanged: (bool value) {
                              setState(() {
                                _useKeyForDecrypt = value;
                                _result = ''; // Clear result when mode changes
                                _decryptKeyController
                                    .clear(); // Clear key input
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

                      if (_useKeyForDecrypt) ...[
                        const Text(
                          'Masukkan Kunci Dekripsi:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          _decryptKeyController,
                          'Tulis kunci...',
                          TextInputType.text,
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        const SizedBox(
                          height: 20,
                        ), // Spasi jika input kunci disembunyikan
                      ],

                      _buildActionButton(
                        _useKeyForDecrypt
                            ? 'Dekripsi Teks'
                            : 'Coba Dekripsi Tanpa Kunci',
                        _useKeyForDecrypt
                            ? _decryptWithKey
                            : _showKeyRequiredMessage,
                        const Color(0xFF041413),
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

                      if (_result.isNotEmpty && _useKeyForDecrypt)
                        _buildCopyButtons(),
                      if (_result.isNotEmpty &&
                          !_useKeyForDecrypt) // Hanya tampilkan Salin Hasil jika tidak pakai key
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _result),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Hasil disalin!'),
                                    ),
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
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text(
                                  'Salin Hasil',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],

                    const SizedBox(height: 30),
                    const Divider(color: Colors.black12, thickness: 1.5),
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
                      'Vigenère Cipher adalah metode enkripsi/dekripsi menggunakan kunci teks berulang. '
                      'Setiap huruf pada pesan digeser berdasarkan huruf pada kunci. '
                      'Dekripsi tanpa kunci yang benar sangat sulit dan membutuhkan analisis frekuensi yang kompleks.',
                      style: TextStyle(color: Colors.black87, height: 1.4),
                    ),

                    const SizedBox(height: 32),
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'Kirim hasil ke',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
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

                          // 🔗 Sosial
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSocialButton(
                                'assets/images/wa.svg',
                                _sendToWhatsApp,
                              ),
                              const SizedBox(width: 40),
                              _buildSocialButton(
                                'assets/images/gmail.svg',
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
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // Hanya salin kunci saja, tanpa teks tambahan
              final String keyToCopy =
                  _currentMode == CipherMode.encrypt
                      ? _autoKey
                      : _decryptKeyController.text;
              Clipboard.setData(ClipboardData(text: keyToCopy));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Kunci "$keyToCopy" disalin!')),
              );
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
            icon: const Icon(Icons.info_outline, size: 18),
            label: Text(
              _currentMode == CipherMode.encrypt
                  ? 'Salin Kunci'
                  : 'Salin Kunci',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ),
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
