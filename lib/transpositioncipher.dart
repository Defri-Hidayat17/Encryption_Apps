import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences

class TranspositionCipherPage extends StatefulWidget {
  const TranspositionCipherPage({super.key});

  @override
  State<TranspositionCipherPage> createState() =>
      _TranspositionCipherPageState();
}

enum CipherMode { encrypt, decrypt } // Tambahkan enum untuk mode

class _TranspositionCipherPageState extends State<TranspositionCipherPage> {
  final TextEditingController _plainController = TextEditingController();
  final TextEditingController _cipherController =
      TextEditingController(); // Controller untuk teks terenkripsi
  final TextEditingController _decryptKeyController =
      TextEditingController(); // Controller untuk kunci dekripsi

  String _result = '';
  List<int> _autoKey = []; // Kunci otomatis yang dibuat sistem (untuk enkripsi)
  int _originalPlaintextLength =
      0; // Untuk membantu dekripsi menghilangkan padding
  CipherMode _currentMode = CipherMode.encrypt; // Default mode: enkripsi
  bool _useKeyForDecrypt = true; // Default: gunakan kunci untuk dekripsi

  // Keys for SharedPreferences
  static const String _plainTextKey = 'transpositionPlainText';
  static const String _cipherTextKey = 'transpositionCipherText';
  static const String _decryptKeyKey = 'transpositionDecryptKey';
  static const String _autoKeyKey =
      'transpositionAutoKey'; // String representation of auto key
  static const String _originalPlaintextLengthKey =
      'transpositionOriginalPlaintextLength';
  static const String _cipherModeKey = 'transpositionCipherMode';
  static const String _useKeyForDecryptKey = 'transpositionUseKeyForDecrypt';

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
    _decryptKeyController.addListener(_saveData);
  }

  @override
  void dispose() {
    // Remove listeners to prevent memory leaks
    _plainController.removeListener(_saveData);
    _cipherController.removeListener(_saveData);
    _decryptKeyController.removeListener(_saveData);

    _plainController.dispose();
    _cipherController.dispose();
    _decryptKeyController.dispose();
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
    await prefs.setString(
      _autoKeyKey,
      _keyToString(_autoKey),
    ); // Simpan autoKey sebagai string
    await prefs.setInt(_originalPlaintextLengthKey, _originalPlaintextLength);
    await prefs.setInt(_cipherModeKey, _currentMode.index);
    await prefs.setBool(_useKeyForDecryptKey, _useKeyForDecrypt);

    print('--- TRANSPOSITION DATA SAVED ---');
    print('Plain Text: "${_plainController.text}"');
    print('Cipher Text: "${_cipherController.text}"');
    print('Decrypt Key: "${_decryptKeyController.text}"');
    print('Auto Key: "${_keyToString(_autoKey)}"');
    print('Original Length: $_originalPlaintextLength');
    print('Mode: $_currentMode');
    print('Use Key for Decrypt: $_useKeyForDecrypt');
    print('---------------------------');
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
      _autoKey = _stringToKey(
        prefs.getString(_autoKeyKey) ?? '',
      ); // Muat autoKey dari string
      _originalPlaintextLength = prefs.getInt(_originalPlaintextLengthKey) ?? 0;
      _currentMode = CipherMode.values[prefs.getInt(_cipherModeKey) ?? 0];
      _useKeyForDecrypt = prefs.getBool(_useKeyForDecryptKey) ?? true;

      print('--- TRANSPOSITION DATA LOADED ---');
      print('Plain Text: "${_plainController.text}"');
      print('Cipher Text (from prefs): "${_cipherController.text}"');
      print('Decrypt Key: "${_decryptKeyController.text}"');
      print('Auto Key: "${_keyToString(_autoKey)}"');
      print('Original Length: $_originalPlaintextLength');
      print('Mode: $_currentMode');
      print('Use Key for Decrypt: $_useKeyForDecrypt');
      print('----------------------------');

      // Re-calculate result based on loaded data and mode
      if (_currentMode == CipherMode.encrypt &&
          _plainController.text.isNotEmpty &&
          _autoKey.isNotEmpty) {
        _result = transpositionEncrypt(_plainController.text, _autoKey);
        print('Recalculated Encrypt Result: $_result');
      } else if (_currentMode == CipherMode.decrypt &&
          _useKeyForDecrypt &&
          _cipherController.text.isNotEmpty &&
          _decryptKeyController.text.isNotEmpty) {
        _result = transpositionDecrypt(
          _cipherController.text,
          _stringToKey(_decryptKeyController.text),
          _originalPlaintextLength,
        );
        print('Recalculated Decrypt Result: $_result');
      } else {
        _result = '';
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
      _autoKey = [];
      _originalPlaintextLength = 0;
      _currentMode = CipherMode.encrypt; // Reset mode to encrypt
      _useKeyForDecrypt = true; // Reset switch
    });
    _saveData(); // Save the cleared state
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua input dan hasil telah dikosongkan!')),
    );
  }

  // ========================================
  // 🔑 Helper untuk Kunci
  // ========================================

  // Membuat kunci otomatis (urutan kolom)
  List<int> _generateAutoKey(int length) {
    List<int> key = List.generate(length, (i) => i);
    key.shuffle(Random());
    return key;
  }

  // Konversi kunci List<int> ke String
  String _keyToString(List<int> key) => key.join(',');

  // Konversi kunci String ke List<int>
  List<int> _stringToKey(String keyString) {
    if (keyString.isEmpty) return [];
    try {
      return keyString.split(',').map((valStr) => int.parse(valStr)).toList();
    } catch (e) {
      print('Error parsing key string: $e');
      return [];
    }
  }

  // ========================================
  // 🔒 Enkripsi Columnar Transposition Cipher
  // ========================================
  String transpositionEncrypt(String text, List<int> key) {
    text = text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z]'),
      '',
    ); // Hanya huruf A-Z

    setState(() {
      _originalPlaintextLength = text.length; // Simpan panjang asli
    });

    int col = key.length;
    if (col == 0) return text; // Hindari pembagian dengan nol

    int row = (text.length / col).ceil();
    // padding dengan 'X' jika perlu
    text = text.padRight(row * col, 'X');

    List<List<String>> matrix = List.generate(row, (_) => List.filled(col, ''));
    int textIndex = 0;
    for (int r = 0; r < row; r++) {
      for (int c = 0; c < col; c++) {
        matrix[r][c] = text[textIndex];
        textIndex++;
      }
    }

    StringBuffer encrypted = StringBuffer();
    for (int k = 0; k < col; k++) {
      int colToRead = key.indexOf(
        k,
      ); // temukan kolom yang sesuai dengan urutan kunci
      for (int r = 0; r < row; r++) {
        encrypted.write(matrix[r][colToRead]);
      }
    }

    return encrypted.toString();
  }

  // ========================================
  // 🔓 Dekripsi Columnar Transposition Cipher
  // ========================================
  String transpositionDecrypt(
    String cipherText,
    List<int> key,
    int originalPlaintextLength,
  ) {
    cipherText = cipherText.toUpperCase().replaceAll(
      RegExp(r'[^A-Z]'),
      '',
    ); // Hanya huruf A-Z

    int col = key.length;
    if (col == 0) return cipherText; // Hindari pembagian dengan nol

    if (cipherText.length % col != 0) {
      return 'Error: Ciphertext tidak valid (panjang bukan kelipatan ${col}).';
    }

    int row = cipherText.length ~/ col;

    List<List<String>> matrix = List.generate(row, (_) => List.filled(col, ''));
    int cipherIndex = 0;

    // Isi matriks kolom per kolom sesuai urutan kunci
    for (int k = 0; k < col; k++) {
      int originalColIndex = key.indexOf(
        k,
      ); // Kolom ini adalah kolom ke-k dalam ciphertext
      for (int r = 0; r < row; r++) {
        matrix[r][originalColIndex] = cipherText[cipherIndex];
        cipherIndex++;
      }
    }

    // Baca matriks baris per baris untuk mendapatkan plaintext
    StringBuffer decrypted = StringBuffer();
    for (int r = 0; r < row; r++) {
      for (int c = 0; c < col; c++) {
        decrypted.write(matrix[r][c]);
      }
    }

    // Hapus padding 'X' jika ada, berdasarkan panjang teks asli
    String finalDecrypted = decrypted.toString();
    if (finalDecrypted.length > originalPlaintextLength) {
      finalDecrypted = finalDecrypted.substring(0, originalPlaintextLength);
    }

    return finalDecrypted;
  }

  // ========================================
  // 🚀 Enkripsi otomatis
  // ========================================
  void _autoEncrypt() {
    final text = _plainController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan teks terlebih dahulu!')),
      );
      return;
    }

    // Batasi panjang kunci (jumlah kolom) agar tidak terlalu besar
    // Misalnya, antara 3 hingga 7 kolom, atau min(5, text.length / 2)
    int keyLength = min(7, max(3, (text.length / 3).ceil()));
    if (keyLength == 0)
      keyLength = 3; // Minimal 3 kolom jika teks sangat pendek

    final key = _generateAutoKey(keyLength);
    final encrypted = transpositionEncrypt(text, key);

    setState(() {
      _autoKey = key;
      _result = encrypted;
      _cipherController.text =
          encrypted; // Update cipher text field for potential decryption
      _decryptKeyController.text = _keyToString(
        key,
      ); // Update key input for decryption
    });
    _saveData();
  }

  // ========================================
  // 🔑 Dekripsi dengan kunci
  // ========================================
  void _decryptWithKey() {
    final cipherText = _cipherController.text.trim();
    final keyString = _decryptKeyController.text.trim();

    if (cipherText.isEmpty || keyString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan teks terenkripsi dan kunci dekripsi!'),
        ),
      );
      return;
    }

    List<int> key = _stringToKey(keyString);
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format kunci tidak valid. Contoh: "2,0,1"'),
        ),
      );
      return;
    }

    // Validasi kunci: harus merupakan permutasi dari 0 hingga key.length-1
    List<int> sortedKey = List.from(key)..sort();
    bool isValidKey = true;
    for (int i = 0; i < sortedKey.length; i++) {
      if (sortedKey[i] != i) {
        isValidKey = false;
        break;
      }
    }
    if (!isValidKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kunci tidak valid. Harus berupa permutasi angka dari 0 sampai (panjang kunci - 1). Contoh: "2,0,1" untuk kunci panjang 3.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    // Untuk dekripsi, kita perlu panjang plaintext asli.
    // Jika user memasukkan secara manual, kita tidak punya info ini.
    // Untuk kasus ini, kita bisa berasumsi panjang aslinya adalah panjang ciphertext
    // atau memberikan opsi input panjang asli.
    // Untuk demo, kita akan menggunakan _originalPlaintextLength yang tersimpan
    // atau panjang ciphertext jika tidak ada.
    int lengthForDecryption = _originalPlaintextLength;
    if (_originalPlaintextLength == 0 && _currentMode == CipherMode.decrypt) {
      // Jika tidak ada panjang asli yang tersimpan (misal: user langsung ke mode dekripsi atau restart)
      // Kita bisa berasumsi tidak ada padding, atau memberikan peringatan.
      // Untuk demo, kita akan gunakan panjang ciphertext dan berharap tidak ada padding X.
      lengthForDecryption = cipherText.length;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Panjang teks asli tidak diketahui, padding "X" mungkin tidak dihapus dengan benar.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }

    final decrypted = transpositionDecrypt(
      cipherText,
      key,
      lengthForDecryption,
    );

    setState(() {
      _result = decrypted;
      _plainController.text =
          decrypted; // Update plain text field for potential re-encryption
    });
    _saveData();
  }

  // ========================================
  // 🚫 Pesan untuk dekripsi tanpa kunci
  // ========================================
  void _showKeyRequiredMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Transposition Cipher tidak dapat didekripsi tanpa kunci yang benar.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
    setState(() {
      _result =
          'Dekripsi tanpa kunci tidak mungkin untuk Transposition Cipher.';
    });
  }

  // ============================
  // 📝 Fungsi untuk membuat pesan yang akan dibagikan
  // ============================
  String _buildMessageForSharing() {
    if (_currentMode == CipherMode.encrypt) {
      return '''
🧩 *Kode Cipher Enkripsi (Transposition Cipher)*

━━━━━━━━━━━━━━━
🔐 *Hasil Enkripsi:*
```$_result```

📜 *Petunjuk Dekripsi:*
Gunakan urutan kolom "${_keyToString(_autoKey)}" untuk membuka pesan ini.
━━━━━━━━━━━━━━━

📘 _Pesan ini dibuat otomatis dari aplikasi Enkripsi by Defri_
''';
    } else {
      return '''
🔓 *Hasil Dekripsi (Transposition Cipher)*

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
  // 🧱 UI Helper Widgets (Konsisten dengan VigenereCipherPage)
  // ========================================

  Widget _buildTextField(
    TextEditingController controller,
    String hintText,
    TextInputType keyboardType,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF041413), width: 2),
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
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shadowColor: Colors.black.withOpacity(0.3),
          elevation: 8,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildResultContainer(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
        style: const TextStyle(color: Colors.black87, fontSize: 16),
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
              backgroundColor: const Color(0xFF041413),
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
              final String keyToCopy =
                  _currentMode == CipherMode.encrypt
                      ? _keyToString(_autoKey)
                      : _decryptKeyController.text;
              Clipboard.setData(ClipboardData(text: keyToCopy));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Kunci "$keyToCopy" disalin!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF041413),
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
                  : 'Salin Kunci Dekripsi',
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
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: SvgPicture.asset(assetPath, width: 32, height: 32),
        ),
      ),
    );
  }

  // ========================================
  // 🧱 UI Utama
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
              height: 70,
              width: double.infinity,
              color: const Color(0xFF041413),
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
                      iconSize: 24,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  SvgPicture.asset(
                    'assets/images/logoenkripsiapps.svg',
                    width: 50,
                    height: 50,
                  ),
                  Positioned(
                    right: 12,
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      iconSize: 24,
                      onPressed: _clearAll,
                    ),
                  ),
                ],
              ),
            ),

            // Mode Toggle
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 15.0,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
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

                          final String currentEncryptResult = _result;
                          final List<int> currentAutoKey = _autoKey;
                          final int currentOriginalPlaintextLength =
                              _originalPlaintextLength;
                          final String currentDecryptResult = _result;

                          // Bersihkan semua input dan hasil terlebih dahulu
                          _plainController.clear();
                          _cipherController.clear();
                          _decryptKeyController.clear();
                          _result = '';
                          _autoKey = [];
                          _originalPlaintextLength = 0;

                          _currentMode = newMode;
                          _useKeyForDecrypt = true;

                          if (oldMode == CipherMode.encrypt &&
                              newMode == CipherMode.decrypt) {
                            if (currentEncryptResult.isNotEmpty) {
                              _cipherController.text = currentEncryptResult;
                              _decryptKeyController.text = _keyToString(
                                currentAutoKey,
                              );
                              _originalPlaintextLength =
                                  currentOriginalPlaintextLength;
                            }
                          } else if (oldMode == CipherMode.decrypt &&
                              newMode == CipherMode.encrypt) {
                            if (currentDecryptResult.isNotEmpty) {
                              _plainController.text = currentDecryptResult;
                            }
                          }

                          // Setelah mengatur controller, picu perhitungan ulang jika input tersedia
                          if (_currentMode == CipherMode.encrypt &&
                              _plainController.text.isNotEmpty) {
                            _autoEncrypt();
                          } else if (_currentMode == CipherMode.decrypt &&
                              _cipherController.text.isNotEmpty &&
                              _decryptKeyController.text.isNotEmpty) {
                            _decryptWithKey();
                          }
                        });
                        _saveData();
                      },
                      borderRadius: BorderRadius.circular(10),
                      selectedColor: Colors.white,
                      color: Colors.black87,
                      fillColor: const Color(0xFF041413),
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
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Text(
                                'Enkripsi',
                                style: TextStyle(
                                  fontSize: 15,
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
                                horizontal: 10,
                                vertical: 10,
                              ),
                              child: Text(
                                'Dekripsi',
                                style: TextStyle(
                                  fontSize: 15,
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

            // BODY
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                          'Kunci Otomatis Digunakan (Urutan Kolom):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildResultContainer(_keyToString(_autoKey)),
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
                              _saveData();
                            },
                            activeColor: const Color(0xFF041413),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_useKeyForDecrypt) ...[
                        const Text(
                          'Masukkan Kunci Dekripsi (urutan kolom, cth: 2,0,1):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          _decryptKeyController,
                          'Contoh: 2,0,1',
                          TextInputType.text,
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        const SizedBox(height: 20),
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
                      if (_result.isNotEmpty && !_useKeyForDecrypt)
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
                                  backgroundColor: const Color(0xFF041413),
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
                      'Transposition Cipher adalah metode enkripsi dengan cara menukar posisi huruf. '
                      'Salah satu contohnya adalah columnar transposition cipher, di mana teks diubah '
                      'menjadi huruf besar, spasi dihilangkan, dan padding "X" ditambahkan jika perlu. '
                      'Kemudian teks ditulis ke dalam matriks baris per baris, '
                      'lalu kolom dibaca berdasarkan urutan kunci. '
                      'Untuk dekripsi, ciphertext diisi kembali ke matriks berdasarkan urutan kunci, '
                      'lalu dibaca baris per baris. Padding "X" di akhir akan dihapus.',
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
}
