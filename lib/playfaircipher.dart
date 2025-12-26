import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences

class PlayfairCipherPage extends StatefulWidget {
  const PlayfairCipherPage({super.key});

  @override
  State<PlayfairCipherPage> createState() => _PlayfairCipherPageState();
}

enum CipherMode { encrypt, decrypt } // Tambahkan enum untuk mode

class _PlayfairCipherPageState extends State<PlayfairCipherPage> {
  final TextEditingController _plainController = TextEditingController();
  final TextEditingController _cipherController =
      TextEditingController(); // Controller untuk teks terenkripsi
  final TextEditingController _decryptKeyController =
      TextEditingController(); // Controller untuk kunci dekripsi

  String _result = '';
  String _autoKey = ''; // Kunci otomatis yang dibuat sistem (untuk enkripsi)
  CipherMode _currentMode = CipherMode.encrypt; // Default mode: enkripsi
  bool _useKeyForDecrypt = true; // Default: gunakan kunci untuk dekripsi

  // Keys for SharedPreferences
  static const String _plainTextKey = 'playfairPlainText';
  static const String _cipherTextKey = 'playfairCipherText';
  static const String _decryptKeyKey = 'playfairDecryptKey';
  static const String _autoKeyKey = 'playfairAutoKey';
  static const String _cipherModeKey = 'playfairCipherMode';
  static const String _useKeyForDecryptKey = 'playfairUseKeyForDecrypt';

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
    await prefs.setString(_autoKeyKey, _autoKey);
    await prefs.setInt(_cipherModeKey, _currentMode.index);
    await prefs.setBool(_useKeyForDecryptKey, _useKeyForDecrypt);

    print('--- PLAYFAIR DATA SAVED ---');
    print('Plain Text: "${_plainController.text}"');
    print('Cipher Text: "${_cipherController.text}"');
    print('Decrypt Key: "${_decryptKeyController.text}"');
    print('Auto Key: "$_autoKey"');
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
      _autoKey = prefs.getString(_autoKeyKey) ?? '';
      _currentMode = CipherMode.values[prefs.getInt(_cipherModeKey) ?? 0];
      _useKeyForDecrypt = prefs.getBool(_useKeyForDecryptKey) ?? true;

      print('--- PLAYFAIR DATA LOADED ---');
      print('Plain Text: "${_plainController.text}"');
      print('Cipher Text (from prefs): "${_cipherController.text}"');
      print('Decrypt Key: "${_decryptKeyController.text}"');
      print('Auto Key: "$_autoKey"');
      print('Mode: $_currentMode');
      print('Use Key for Decrypt: $_useKeyForDecrypt');
      print('----------------------------');

      // Re-calculate result based on loaded data and mode
      if (_currentMode == CipherMode.encrypt &&
          _plainController.text.isNotEmpty &&
          _autoKey.isNotEmpty) {
        _result = playfairEncrypt(_plainController.text, _autoKey);
        // _cipherController.text is not directly updated here as it's for decryption input
        print('Recalculated Encrypt Result: $_result');
      } else if (_currentMode == CipherMode.decrypt &&
          _useKeyForDecrypt &&
          _cipherController.text.isNotEmpty &&
          _decryptKeyController.text.isNotEmpty) {
        _result = playfairDecrypt(
          _cipherController.text,
          _decryptKeyController.text,
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
      _autoKey = '';
      _currentMode = CipherMode.encrypt; // Reset mode to encrypt
      _useKeyForDecrypt = true; // Reset switch
    });
    _saveData(); // Save the cleared state
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua input dan hasil telah dikosongkan!')),
    );
  }

  // ===============================
  // 🔑 Membuat matriks 5x5 dari key
  // ===============================
  List<List<String>> _generateKeyMatrix(String key) {
    key = key
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '')
        .replaceAll('J', 'I');
    String seen = '';
    String matrixString = '';

    for (var c in key.split('')) {
      if (!seen.contains(c)) {
        seen += c;
        matrixString += c;
      }
    }

    // Tambahkan sisa alfabet
    const alphabet = 'ABCDEFGHIKLMNOPQRSTUVWXYZ';
    for (var c in alphabet.split('')) {
      if (!seen.contains(c) && c != 'J') {
        // Ensure J is not added
        matrixString += c;
      }
    }

    // Bentuk matriks 5x5
    List<List<String>> matrix = List.generate(5, (i) => List.filled(5, ''));
    for (int i = 0; i < 25; i++) {
      matrix[i ~/ 5][i % 5] = matrixString[i];
    }
    return matrix;
  }

  // ===============================
  // 🔒 Enkripsi Playfair
  // ===============================
  String playfairEncrypt(String text, String key) {
    if (key.isEmpty) return text;

    text = text
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '')
        .replaceAll('J', 'I');

    List<String> digrams = [];
    int i = 0;
    while (i < text.length) {
      String char1 = text[i];
      String char2;

      if (i + 1 < text.length) {
        char2 = text[i + 1];
        if (char1 == char2) {
          char2 = 'X'; // Insert X, keep original char2 for next digram
          // i is NOT incremented here, so the original text[i+1] will be char1 in the next iteration
        } else {
          i++; // Advance i to skip the char2 we just used
        }
      } else {
        char2 = 'X'; // Last character, pad with X
      }
      digrams.add(char1 + char2);
      i++; // Advance i for char1 (and potentially char2 if not skipped)
    }

    List<List<String>> matrix = _generateKeyMatrix(key);
    StringBuffer encrypted = StringBuffer();

    for (var pair in digrams) {
      var pos1 = _findPosition(matrix, pair[0]);
      var pos2 = _findPosition(matrix, pair[1]);

      if (pos1[0] == pos2[0]) {
        // Sama baris, geser ke kanan
        encrypted.write(matrix[pos1[0]][(pos1[1] + 1) % 5]);
        encrypted.write(matrix[pos2[0]][(pos2[1] + 1) % 5]);
      } else if (pos1[1] == pos2[1]) {
        // Sama kolom, geser ke bawah
        encrypted.write(matrix[(pos1[0] + 1) % 5][pos1[1]]);
        encrypted.write(matrix[(pos2[0] + 1) % 5][pos2[1]]);
      } else {
        // Bentuk persegi, tukar kolom
        encrypted.write(matrix[pos1[0]][pos2[1]]);
        encrypted.write(matrix[pos2[0]][pos1[1]]);
      }
    }

    return encrypted.toString();
  }

  // ===============================
  // 🔓 Dekripsi Playfair
  // ===============================
  String playfairDecrypt(String cipherText, String key) {
    if (key.isEmpty) return cipherText;

    cipherText = cipherText
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '')
        .replaceAll(
          'J',
          'I',
        ); // Ciphertext should not contain J, but for safety

    // Playfair ciphertext must have an even length
    if (cipherText.length % 2 != 0) {
      // This indicates invalid ciphertext for Playfair.
      // For robustness, we can append an 'X' to make it even,
      // but it's better to inform the user or handle as an error.
      // For now, let's assume valid even-length ciphertext.
      return 'Error: Ciphertext tidak valid (panjang ganjil).';
    }

    List<List<String>> matrix = _generateKeyMatrix(key);
    StringBuffer decryptedBuffer = StringBuffer();

    for (int i = 0; i < cipherText.length; i += 2) {
      String char1 = cipherText[i];
      String char2 = cipherText[i + 1];

      var pos1 = _findPosition(matrix, char1);
      var pos2 = _findPosition(matrix, char2);

      if (pos1[0] == pos2[0]) {
        // Same row, shift left
        decryptedBuffer.write(matrix[pos1[0]][(pos1[1] - 1 + 5) % 5]);
        decryptedBuffer.write(matrix[pos2[0]][(pos2[1] - 1 + 5) % 5]);
      } else if (pos1[1] == pos2[1]) {
        // Same column, shift up
        decryptedBuffer.write(matrix[(pos1[0] - 1 + 5) % 5][pos1[1]]);
        decryptedBuffer.write(matrix[(pos2[0] - 1 + 5) % 5][pos2[1]]);
      } else {
        // Rectangle, swap column indices
        decryptedBuffer.write(matrix[pos1[0]][pos2[1]]);
        decryptedBuffer.write(matrix[pos2[0]][pos1[1]]);
      }
    }

    // Post-process to remove inserted 'X's
    return _postProcessDecryptedText(decryptedBuffer.toString());
  }

  // ===============================
  // 🧹 Post-processing untuk menghapus 'X' yang disisipkan
  // ===============================
  String _postProcessDecryptedText(String preliminaryDecrypted) {
    StringBuffer finalPlaintext = StringBuffer();
    int i = 0;
    while (i < preliminaryDecrypted.length) {
      finalPlaintext.write(preliminaryDecrypted[i]);

      // Check for 'X' that was inserted due to repeated letters (e.g., LXL -> LL)
      // This happens if the current char is followed by 'X' and then by the same char.
      // Example: 'HELXLO' -> 'HELLO' (this logic is for the raw decrypted string before any 'X' removal)
      // If the encryption logic produces HE, LX, LO for HELLO, then decryption produces HE, LL, LO, so HELLO.
      // The 'X' is removed by the inverse logic itself.
      // The only 'X' that might remain is the padding 'X' at the very end.
      i++;
    }

    String resultWithoutInternalXs = finalPlaintext.toString();

    // Remove trailing 'X' if it was padding.
    // Heuristic: If the last character is 'X' and the original plaintext had an odd length.
    // Since we don't know the original length, a common heuristic is to remove it
    // if it's the last character AND the character before it is NOT 'X'.
    // This avoids removing 'X' from words that naturally end with 'X' or have 'XX'.
    if (resultWithoutInternalXs.isNotEmpty &&
        resultWithoutInternalXs.endsWith('X')) {
      if (resultWithoutInternalXs.length > 1 &&
          resultWithoutInternalXs[resultWithoutInternalXs.length - 2] != 'X') {
        resultWithoutInternalXs = resultWithoutInternalXs.substring(
          0,
          resultWithoutInternalXs.length - 1,
        );
      } else if (resultWithoutInternalXs.length == 1 &&
          resultWithoutInternalXs == 'X') {
        // Handle case where plaintext was just 'X' or empty and padded to 'X'
        resultWithoutInternalXs = '';
      }
    }

    return resultWithoutInternalXs;
  }

  List<int> _findPosition(List<List<String>> matrix, String c) {
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        if (matrix[i][j] == c) return [i, j];
      }
    }
    return [0, 0]; // Should not happen if input is properly filtered
  }

  // ===============================
  // ⚙️ Kunci otomatis
  // ===============================
  String _generateAutoKey(String text) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = Random();
    String key = '';
    // Generate a key with a reasonable fixed length for Playfair, e.g., 8-12 characters
    int desiredKeyLength = min(10, text.length > 0 ? text.length : 10);
    if (desiredKeyLength == 0) desiredKeyLength = 5;

    for (int i = 0; i < desiredKeyLength; i++) {
      key += alphabet[random.nextInt(alphabet.length)];
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
    final encrypted = playfairEncrypt(text, key);

    setState(() {
      _autoKey = key;
      _result = encrypted;
      _cipherController.text =
          encrypted; // Update cipher text field for potential decryption
    });
    _saveData();
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

    final decrypted = playfairDecrypt(text, key);

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
          'Playfair Cipher sangat sulit didekripsi tanpa kunci yang benar. Silakan gunakan kunci untuk dekripsi.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
    setState(() {
      _result = 'Dekripsi tanpa kunci tidak disarankan untuk Playfair Cipher.';
    });
  }

  // ============================
  // 📝 Fungsi untuk membuat pesan yang akan dibagikan
  // ============================
  String _buildMessageForSharing() {
    if (_currentMode == CipherMode.encrypt) {
      return '''
🧩 *Kode Cipher Enkripsi (Playfair)*

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
🔓 *Hasil Dekripsi (Playfair)*

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
                      ? _autoKey
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
                          final String currentAutoKey = _autoKey;
                          final String currentDecryptResult = _result;

                          // Bersihkan semua input dan hasil terlebih dahulu
                          _plainController.clear();
                          _cipherController.clear();
                          _decryptKeyController.clear();
                          _result = '';
                          _autoKey = '';

                          _currentMode = newMode;
                          _useKeyForDecrypt = true;

                          if (oldMode == CipherMode.encrypt &&
                              newMode == CipherMode.decrypt) {
                            if (currentEncryptResult.isNotEmpty) {
                              _cipherController.text = currentEncryptResult;
                              _decryptKeyController.text = currentAutoKey;
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
                              _saveData();
                            },
                            activeColor: const Color(0xFF041413),
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
                      'Playfair Cipher adalah metode enkripsi yang mengenkripsi pesan '
                      'dalam pasangan huruf (digram). Jika huruf sama (misal: "LL"), '
                      'huruf "X" disisipkan di antaranya (menjadi "LX"). '
                      'Huruf "J" diganti dengan "I" untuk menyesuaikan matriks 5x5. '
                      'Menggunakan matriks 5x5 dari kunci untuk menentukan substitusi huruf. '
                      'Aturannya: huruf di baris yang sama digeser kanan, '
                      'di kolom yang sama digeser ke bawah, selain itu tukar kolom. '
                      'Saat dekripsi, "X" yang disisipkan dan padding di akhir akan dihapus secara otomatis.',
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
