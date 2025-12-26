import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences

class HillCipherPage extends StatefulWidget {
  const HillCipherPage({super.key});

  @override
  State<HillCipherPage> createState() => _HillCipherPageState();
}

enum CipherMode { encrypt, decrypt } // Tambahkan enum untuk mode

class _HillCipherPageState extends State<HillCipherPage> {
  final TextEditingController _plainController = TextEditingController();
  final TextEditingController _cipherController =
      TextEditingController(); // Controller untuk teks terenkripsi
  final TextEditingController _decryptKeyController =
      TextEditingController(); // Controller untuk kunci dekripsi (dalam format string)

  String _result = '';
  List<List<int>> _autoKeyMatrix = []; // Matriks kunci otomatis
  int _originalPlaintextLength =
      0; // Untuk membantu dekripsi menghilangkan padding
  CipherMode _currentMode = CipherMode.encrypt; // Default mode: enkripsi
  bool _useKeyForDecrypt = true; // Default: gunakan kunci untuk dekripsi

  // Keys for SharedPreferences
  static const String _plainTextKey = 'hillPlainText';
  static const String _cipherTextKey = 'hillCipherText';
  static const String _decryptKeyKey =
      'hillDecryptKey'; // String representation of key matrix
  static const String _originalPlaintextLengthKey =
      'hillOriginalPlaintextLength';
  static const String _cipherModeKey = 'hillCipherMode';
  static const String _useKeyForDecryptKey = 'hillUseKeyForDecrypt';

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
    await prefs.setString(
      _decryptKeyKey,
      _matrixToString(_autoKeyMatrix),
    ); // Simpan matriks kunci
    await prefs.setInt(_originalPlaintextLengthKey, _originalPlaintextLength);
    await prefs.setInt(_cipherModeKey, _currentMode.index);
    await prefs.setBool(_useKeyForDecryptKey, _useKeyForDecrypt);

    print('--- HILL DATA SAVED ---');
    print('Plain Text: "${_plainController.text}"');
    print('Cipher Text: "${_cipherController.text}"');
    print('Decrypt Key Matrix: "${_matrixToString(_autoKeyMatrix)}"');
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
      _decryptKeyController.text =
          prefs.getString(_decryptKeyKey) ?? ''; // String dari matriks
      _originalPlaintextLength = prefs.getInt(_originalPlaintextLengthKey) ?? 0;
      _currentMode = CipherMode.values[prefs.getInt(_cipherModeKey) ?? 0];
      _useKeyForDecrypt = prefs.getBool(_useKeyForDecryptKey) ?? true;

      // Konversi string matriks kembali ke List<List<int>>
      String storedKeyMatrixString = prefs.getString(_decryptKeyKey) ?? '';
      _autoKeyMatrix = _stringToMatrix(storedKeyMatrixString);

      print('--- HILL DATA LOADED ---');
      print('Plain Text: "${_plainController.text}"');
      print('Cipher Text (from prefs): "${_cipherController.text}"');
      print(
        'Decrypt Key Matrix (from prefs): "${_matrixToString(_autoKeyMatrix)}"',
      );
      print('Original Length: $_originalPlaintextLength');
      print('Mode: $_currentMode');
      print('Use Key for Decrypt: $_useKeyForDecrypt');
      print('----------------------------');

      // Re-calculate result based on loaded data and mode
      if (_currentMode == CipherMode.encrypt &&
          _plainController.text.isNotEmpty &&
          _autoKeyMatrix.isNotEmpty) {
        _result = hillEncrypt(_plainController.text, _autoKeyMatrix);
        print('Recalculated Encrypt Result: $_result');
      } else if (_currentMode == CipherMode.decrypt &&
          _useKeyForDecrypt &&
          _cipherController.text.isNotEmpty &&
          _autoKeyMatrix.isNotEmpty) {
        _result = hillDecrypt(
          _cipherController.text,
          _autoKeyMatrix,
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
      _autoKeyMatrix = [];
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
  // 🔑 Helper untuk Matriks Kunci
  // ========================================

  // Konversi matriks ke string untuk penyimpanan
  String _matrixToString(List<List<int>> matrix) {
    if (matrix.isEmpty) return '';
    return matrix
        .map((row) => row.map((v) => v.toString()).join(','))
        .join(';');
  }

  // Konversi string ke matriks
  List<List<int>> _stringToMatrix(String matrixString) {
    if (matrixString.isEmpty) return [];
    try {
      return matrixString.split(';').map((rowStr) {
        return rowStr.split(',').map((valStr) => int.parse(valStr)).toList();
      }).toList();
    } catch (e) {
      print('Error parsing matrix string: $e');
      return [];
    }
  }

  // Menghitung determinan matriks 2x2
  int _calculateDeterminant2x2(List<List<int>> matrix) {
    if (matrix.length != 2 || matrix[0].length != 2) {
      throw ArgumentError('Matrix must be 2x2');
    }
    return (matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0]) % 26;
  }

  // Menghitung invers modular (a^-1 mod m)
  int _modInverse(int a, int m) {
    a = a % m;
    for (int x = 1; x < m; x++) {
      if ((a * x) % m == 1) {
        return x;
      }
    }
    return -1; // Tidak ada invers modular
  }

  // Memeriksa apakah matriks dapat diinvers
  bool _isInvertible(List<List<int>> matrix) {
    int det = _calculateDeterminant2x2(matrix);
    // Determinant harus coprime dengan 26 (tidak boleh habis dibagi 2 atau 13)
    return det != 0 && _modInverse(det, 26) != -1;
  }

  // Menghasilkan matriks kunci 2x2 yang dapat diinvers
  List<List<int>> _generateInvertibleKeyMatrix2x2() {
    final random = Random();
    List<List<int>> matrix;
    do {
      matrix = List.generate(2, (_) => List.filled(2, 0));
      for (int i = 0; i < 2; i++) {
        for (int j = 0; j < 2; j++) {
          matrix[i][j] = random.nextInt(26);
        }
      }
    } while (!_isInvertible(matrix));
    return matrix;
  }

  // Menghitung invers matriks 2x2 modulo 26
  List<List<int>> _getInverseKeyMatrix2x2(List<List<int>> keyMatrix) {
    int det = _calculateDeterminant2x2(keyMatrix);
    int detInverse = _modInverse(det, 26);
    if (detInverse == -1) {
      throw ArgumentError('Key matrix is not invertible modulo 26');
    }

    // Adjugate matrix for 2x2: [[d, -b], [-c, a]]
    int a = keyMatrix[0][0];
    int b = keyMatrix[0][1];
    int c = keyMatrix[1][0];
    int d = keyMatrix[1][1];

    List<List<int>> adjugate = [
      [d, -b],
      [-c, a],
    ];

    List<List<int>> inverseMatrix = List.generate(2, (_) => List.filled(2, 0));
    for (int i = 0; i < 2; i++) {
      for (int j = 0; j < 2; j++) {
        inverseMatrix[i][j] = (adjugate[i][j] * detInverse) % 26;
        if (inverseMatrix[i][j] < 0) {
          inverseMatrix[i][j] += 26; // Pastikan hasilnya positif
        }
      }
    }
    return inverseMatrix;
  }

  // ========================================
  // 🔒 Enkripsi Hill Cipher
  // ========================================
  String hillEncrypt(String text, List<List<int>> keyMatrix) {
    int n = keyMatrix.length; // Ukuran matriks kunci (misal: 2 untuk 2x2)
    text = text.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');

    setState(() {
      _originalPlaintextLength = text.length; // Simpan panjang asli
    });

    // Tambahkan padding 'X' jika teks tidak kelipatan n
    while (text.length % n != 0) {
      text += 'X';
    }

    StringBuffer encrypted = StringBuffer();

    for (int i = 0; i < text.length; i += n) {
      List<int> vector = [];
      for (int j = 0; j < n; j++) {
        vector.add(text.codeUnitAt(i + j) - 65); // Konversi char ke int (0-25)
      }

      List<int> cipherVector = List.filled(n, 0);
      for (int row = 0; row < n; row++) {
        int sum = 0;
        for (int col = 0; col < n; col++) {
          sum += keyMatrix[row][col] * vector[col];
        }
        cipherVector[row] = sum % 26;
      }

      for (int val in cipherVector) {
        encrypted.write(String.fromCharCode(val + 65)); // Konversi int ke char
      }
    }

    return encrypted.toString();
  }

  // ========================================
  // 🔓 Dekripsi Hill Cipher
  // ========================================
  String hillDecrypt(
    String cipherText,
    List<List<int>> keyMatrix,
    int originalPlaintextLength,
  ) {
    int n = keyMatrix.length;
    cipherText = cipherText.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');

    if (cipherText.length % n != 0) {
      // Ini seharusnya tidak terjadi jika enkripsi benar
      return 'Error: Ciphertext tidak valid (panjang bukan kelipatan ${n}).';
    }

    List<List<int>> inverseKeyMatrix;
    try {
      inverseKeyMatrix = _getInverseKeyMatrix2x2(keyMatrix);
    } catch (e) {
      return 'Error: Matriks kunci tidak dapat diinvers: $e';
    }

    StringBuffer decrypted = StringBuffer();

    for (int i = 0; i < cipherText.length; i += n) {
      List<int> vector = [];
      for (int j = 0; j < n; j++) {
        vector.add(cipherText.codeUnitAt(i + j) - 65);
      }

      List<int> plainVector = List.filled(n, 0);
      for (int row = 0; row < n; row++) {
        int sum = 0;
        for (int col = 0; col < n; col++) {
          sum += inverseKeyMatrix[row][col] * vector[col];
        }
        plainVector[row] = sum % 26;
      }

      for (int val in plainVector) {
        decrypted.write(String.fromCharCode(val + 65));
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

    // Generate matriks kunci 2x2 yang dapat diinvers
    final keyMatrix = _generateInvertibleKeyMatrix2x2();
    final encrypted = hillEncrypt(text, keyMatrix);

    setState(() {
      _autoKeyMatrix = keyMatrix;
      _result = encrypted;
      _cipherController.text =
          encrypted; // Update cipher text field for potential decryption
      _decryptKeyController.text = _matrixToString(
        keyMatrix,
      ); // Update key input for decryption
    });
    _saveData();
  }

  // ========================================
  // 🔑 Dekripsi dengan kunci
  // ========================================
  void _decryptWithKey() {
    final cipherText = _cipherController.text.trim();
    final keyMatrixString = _decryptKeyController.text.trim();

    if (cipherText.isEmpty || keyMatrixString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Masukkan teks terenkripsi dan matriks kunci dekripsi!',
          ),
        ),
      );
      return;
    }

    List<List<int>> keyMatrix = _stringToMatrix(keyMatrixString);
    if (keyMatrix.isEmpty ||
        keyMatrix.length != 2 ||
        keyMatrix[0].length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Format matriks kunci tidak valid (harus 2x2). Contoh: "1,2;3,4"',
          ),
        ),
      );
      return;
    }
    if (!_isInvertible(keyMatrix)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Matriks kunci tidak dapat diinvers modulo 26. Coba matriks lain.',
          ),
        ),
      );
      return;
    }

    // Untuk dekripsi, kita perlu panjang plaintext asli.
    // Jika user memasukkan secara manual, kita tidak punya info ini.
    // Untuk kasus ini, kita bisa berasumsi panjang aslinya adalah panjang ciphertext
    // atau memberikan opsi input panjang asli.
    // Untuk kesederhanaan, kita akan menggunakan _originalPlaintextLength yang tersimpan
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

    final decrypted = hillDecrypt(cipherText, keyMatrix, lengthForDecryption);

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
          'Hill Cipher tidak dapat didekripsi tanpa matriks kunci yang benar.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
    setState(() {
      _result = 'Dekripsi tanpa kunci tidak mungkin untuk Hill Cipher.';
    });
  }

  // ============================
  // 📝 Fungsi untuk membuat pesan yang akan dibagikan
  // ============================
  String _buildMessageForSharing() {
    if (_currentMode == CipherMode.encrypt) {
      return '''
🧩 *Kode Cipher Enkripsi (Hill Cipher)*

━━━━━━━━━━━━━━━
🔐 *Hasil Enkripsi:*
```$_result```

📜 *Petunjuk Dekripsi:*
Gunakan matriks kunci "${_matrixToString(_autoKeyMatrix)}" untuk membuka pesan ini.
━━━━━━━━━━━━━━━

📘 _Pesan ini dibuat otomatis dari aplikasi Enkripsi by Defri_
''';
    } else {
      return '''
🔓 *Hasil Dekripsi (Hill Cipher)*

━━━━━━━━━━━━━━━
🧠 *Hasil Dekripsi:*
```$_result```

🔑 *Matriks Kunci Digunakan:*
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
                      ? _matrixToString(_autoKeyMatrix)
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
                  ? 'Salin Matriks Kunci'
                  : 'Salin Matriks Kunci Dekripsi',
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
                          final List<List<int>> currentAutoKeyMatrix =
                              _autoKeyMatrix;
                          final int currentOriginalPlaintextLength =
                              _originalPlaintextLength;
                          final String currentDecryptResult = _result;

                          // Bersihkan semua input dan hasil terlebih dahulu
                          _plainController.clear();
                          _cipherController.clear();
                          _decryptKeyController.clear();
                          _result = '';
                          _autoKeyMatrix = [];
                          _originalPlaintextLength = 0;

                          _currentMode = newMode;
                          _useKeyForDecrypt = true;

                          if (oldMode == CipherMode.encrypt &&
                              newMode == CipherMode.decrypt) {
                            if (currentEncryptResult.isNotEmpty) {
                              _cipherController.text = currentEncryptResult;
                              _decryptKeyController.text = _matrixToString(
                                currentAutoKeyMatrix,
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
                        'Enkripsi Otomatis (Matriks 2x2)',
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
                          'Matriks Kunci Otomatis Digunakan:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildResultContainer(_matrixToString(_autoKeyMatrix)),
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
                            'Gunakan Matriks Kunci Dekripsi',
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
                          'Masukkan Matriks Kunci Dekripsi (format: a,b;c,d):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildTextField(
                          _decryptKeyController,
                          'Contoh: 1,2;3,4',
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
                      'Hill Cipher adalah metode enkripsi polialfabetik berbasis matriks. '
                      'Teks diubah menjadi vektor angka (A=0, B=1, dst.), lalu dikalikan dengan matriks kunci modulo 26. '
                      'Untuk dekripsi, diperlukan invers dari matriks kunci modulo 26. '
                      'Matriks kunci harus memiliki determinan yang tidak habis dibagi 2 atau 13 agar dapat diinvers. '
                      'Teks akan diproses dalam blok sesuai ukuran matriks (misal: 2 huruf untuk matriks 2x2). '
                      'Jika panjang teks tidak sesuai, padding "X" akan ditambahkan secara otomatis.',
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
