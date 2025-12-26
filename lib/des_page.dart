import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences

/// ----------------------
/// Utilities: bit conversions & group formatting
/// ----------------------
List<int> _stringToBits64(String s) {
  final t = s.padRight(8, ' '); // Pad with space to 8 characters
  List<int> bits = [];
  for (final r in t.runes) {
    int v = r & 0xFF; // Ensure 8-bit ASCII
    for (int i = 7; i >= 0; i--) bits.add((v >> i) & 1);
  }
  return bits;
}

String _bitsToGroupedString(List<int> bits, {int group = 8}) {
  final sb = StringBuffer();
  for (int i = 0; i < bits.length; i++) {
    sb.write(bits[i]);
    if ((i + 1) % group == 0 && i != bits.length - 1) sb.write(' ');
  }
  return sb.toString();
}

String _bitsToHex(List<int> bits) {
  final sb = StringBuffer();
  for (int i = 0; i < bits.length; i += 4) {
    final val = bits.sublist(i, i + 4).fold(0, (p, e) => (p << 1) | e);
    sb.write(val.toRadixString(16).toUpperCase());
  }
  return sb.toString();
}

List<int> _bitsFromHex(String hex) {
  final clean = hex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
  List<int> bits = [];
  for (int i = 0; i < clean.length; i++) {
    final v = int.parse(clean[i], radix: 16);
    for (int b = 3; b >= 0; b--) bits.add((v >> b) & 1);
  }
  // ensure 64 bits
  if (bits.length < 64) {
    final pad = List<int>.filled(64 - bits.length, 0);
    bits = pad + bits;
  }
  if (bits.length > 64) bits = bits.sublist(bits.length - 64);
  return bits;
}

List<int> _permute(List<int> bits, List<int> table) =>
    table.map((idx) => bits[idx - 1]).toList();

List<int> _leftShift(List<int> bits, int n) =>
    bits.sublist(n) + bits.sublist(0, n);

List<int> _xor(List<int> a, List<int> b) =>
    List<int>.generate(a.length, (i) => a[i] ^ b[i]);

List<int> _concat(List<int> a, List<int> b) => List<int>.from(a)..addAll(b);

/// -----------------------------
/// DES tables (standard)
/// -----------------------------
const List<int> _pc1 = [
  57,
  49,
  41,
  33,
  25,
  17,
  9,
  1,
  58,
  50,
  42,
  34,
  26,
  18,
  10,
  2,
  59,
  51,
  43,
  35,
  27,
  19,
  11,
  3,
  60,
  52,
  44,
  36,
  63,
  55,
  47,
  39,
  31,
  23,
  15,
  7,
  62,
  54,
  46,
  38,
  30,
  22,
  14,
  6,
  61,
  53,
  45,
  37,
  29,
  21,
  13,
  5,
  28,
  20,
  12,
  4,
];

const List<int> _pc2 = [
  14,
  17,
  11,
  24,
  1,
  5,
  3,
  28,
  15,
  6,
  21,
  10,
  23,
  19,
  12,
  4,
  26,
  8,
  16,
  7,
  27,
  20,
  13,
  2,
  41,
  52,
  31,
  37,
  47,
  55,
  30,
  40,
  51,
  45,
  33,
  48,
  44,
  49,
  39,
  56,
  34,
  53,
  46,
  42,
  50,
  36,
  29,
  32,
];

const List<int> _shifts = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1];

const List<int> _initialPermutation = [
  58,
  50,
  42,
  34,
  26,
  18,
  10,
  2,
  60,
  52,
  44,
  36,
  28,
  20,
  12,
  4,
  62,
  54,
  46,
  38,
  30,
  22,
  14,
  6,
  64,
  56,
  48,
  40,
  32,
  24,
  16,
  8,
  57,
  49,
  41,
  33,
  25,
  17,
  9,
  1,
  59,
  51,
  43,
  35,
  27,
  19,
  11,
  3,
  61,
  53,
  45,
  37,
  29,
  21,
  13,
  5,
  63,
  55,
  47,
  39,
  31,
  23,
  15,
  7,
];

const List<int> _finalPermutation = [
  40,
  8,
  48,
  16,
  56,
  24,
  64,
  32,
  39,
  7,
  47,
  15,
  55,
  23,
  63,
  31,
  38,
  6,
  46,
  14,
  54,
  22,
  62,
  30,
  37,
  5,
  45,
  13,
  53,
  21,
  61,
  29,
  36,
  4,
  44,
  12,
  52,
  20,
  60,
  28,
  35,
  3,
  43,
  11,
  51,
  19,
  59,
  27,
  34,
  2,
  42,
  10,
  50,
  18,
  58,
  26,
  33,
  1,
  41,
  9,
  49,
  17,
  57,
  25,
];

const List<int> _expansionTable = [
  32,
  1,
  2,
  3,
  4,
  5,
  4,
  5,
  6,
  7,
  8,
  9,
  8,
  9,
  10,
  11,
  12,
  13,
  12,
  13,
  14,
  15,
  16,
  17,
  16,
  17,
  18,
  19,
  20,
  21,
  20,
  21,
  22,
  23,
  24,
  25,
  24,
  25,
  26,
  27,
  28,
  29,
  28,
  29,
  30,
  31,
  32,
  1,
];

const List<int> _pPermutation = [
  16,
  7,
  20,
  21,
  29,
  12,
  28,
  17,
  1,
  15,
  23,
  26,
  5,
  18,
  31,
  10,
  2,
  8,
  24,
  14,
  32,
  27,
  3,
  9,
  19,
  13,
  30,
  6,
  22,
  11,
  4,
  25,
];

const List<List<List<int>>> _sBoxes = [
  [
    [14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7],
    [0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8],
    [4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0],
    [15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13],
  ],
  [
    [15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10],
    [3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5],
    [0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15],
    [13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9],
  ],
  [
    [10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8],
    [13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1],
    [13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7],
    [1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12],
  ],
  [
    [7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15],
    [13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9],
    [10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4],
    [3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14],
  ],
  [
    [2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9],
    [14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6],
    [4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14],
    [11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3],
  ],
  [
    [12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11],
    [10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8],
    [9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6],
    [4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13],
  ],
  [
    [4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1],
    [13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6],
    [1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2],
    [6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12],
  ],
  [
    [13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7],
    [1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2],
    [7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8],
    [2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11],
  ],
];

/// -----------------------------
/// Data record classes for steps
/// -----------------------------
class DesRoundRecord {
  final int round;
  final List<int> leftBits; // 32 bits
  final List<int> rightBits; // 32 bits
  final List<int> subkey; // 48
  final List<int> expandedR; // 48
  final List<int> xored; // 48
  final List<int> sboxOut; // 32
  final List<int> pOut; // 32
  final List<int> lNext;
  final List<int> rNext;
  DesRoundRecord({
    required this.round,
    required this.leftBits,
    required this.rightBits,
    required this.subkey,
    required this.expandedR,
    required this.xored,
    required this.sboxOut,
    required this.pOut,
    required this.lNext,
    required this.rNext,
  });
}

class DesResult {
  final String plaintext;
  final List<int> plaintextBits; // 64
  final String key;
  final List<int> keyBits; // 64
  final List<int> pc1; // 56
  final List<List<int>> subkeys; // 16 x 48
  final List<int> ip; // 64
  final List<DesRoundRecord> rounds; // 16
  final List<int> preOutput; // 64
  final List<int> cipherBits; // 64
  final String cipherHex;
  DesResult({
    required this.plaintext,
    required this.plaintextBits,
    required this.key,
    required this.keyBits,
    required this.pc1,
    required this.subkeys,
    required this.ip,
    required this.rounds,
    required this.preOutput,
    required this.cipherBits,
    required this.cipherHex,
  });
}

/// -----------------------------
/// DES core functions (generate subkeys, s-box, encrypt/decrypt)
/// -----------------------------
List<List<int>> _generateSubkeys(List<int> keyBits) {
  final pc1Res = _permute(keyBits, _pc1); // 56
  List<int> c = pc1Res.sublist(0, 28);
  List<int> d = pc1Res.sublist(28, 56);
  List<List<int>> subs = [];
  for (int i = 0; i < 16; i++) {
    c = _leftShift(c, _shifts[i]);
    d = _leftShift(d, _shifts[i]);
    final cd = _concat(c, d);
    final ki = _permute(cd, _pc2);
    subs.add(ki);
  }
  return subs;
}

List<int> _applySBoxes(List<int> in48) {
  List<int> out32 = [];
  for (int i = 0; i < 8; i++) {
    final block = in48.sublist(i * 6, i * 6 + 6);
    final row = (block[0] << 1) | block[5];
    final col = block.sublist(1, 5).fold(0, (p, e) => (p << 1) | e);
    final val = _sBoxes[i][row][col];
    for (int b = 3; b >= 0; b--) out32.add((val >> b) & 1);
  }
  return out32;
}

DesResult desEncryptWithSteps(String plaintext, String key) {
  final ptBits = _stringToBits64(plaintext);
  final keyBits = _stringToBits64(key);

  final pc1Res = _permute(keyBits, _pc1); // 56
  final subkeys = _generateSubkeys(keyBits); // 16 x 48

  final ip = _permute(ptBits, _initialPermutation);
  List<int> left = ip.sublist(0, 32);
  List<int> right = ip.sublist(32, 64);

  final rounds = <DesRoundRecord>[];

  for (int r = 0; r < 16; r++) {
    final prevL = List<int>.from(left);
    final prevR = List<int>.from(right);

    final expandedR = _permute(prevR, _expansionTable);
    final xored = _xor(expandedR, subkeys[r]);
    final sboxOut = _applySBoxes(xored);
    final pOut = _permute(sboxOut, _pPermutation);

    final lNext = List<int>.from(prevR);
    final rNext = _xor(prevL, pOut);

    rounds.add(
      DesRoundRecord(
        round: r + 1,
        leftBits: prevL,
        rightBits: prevR,
        subkey: subkeys[r],
        expandedR: expandedR,
        xored: xored,
        sboxOut: sboxOut,
        pOut: pOut,
        lNext: lNext,
        rNext: rNext,
      ),
    );

    left = lNext;
    right = rNext;
  }

  final preOutput = _concat(right, left);
  final cipherBits = _permute(preOutput, _finalPermutation);
  final cipherHex = _bitsToHex(cipherBits);

  return DesResult(
    plaintext: plaintext,
    plaintextBits: ptBits,
    key: key,
    keyBits: keyBits,
    pc1: pc1Res,
    subkeys: subkeys,
    ip: ip,
    rounds: rounds,
    preOutput: preOutput,
    cipherBits: cipherBits,
    cipherHex: cipherHex,
  );
}

/// Decrypt (take cipherHex and key)
DesResult desDecryptWithSteps(String cipherHex, String key) {
  final cipherBits = _bitsFromHex(cipherHex).sublist(0, 64);
  final keyBits = _stringToBits64(key);
  final pc1Res = _permute(keyBits, _pc1);
  final subkeys = _generateSubkeys(keyBits);

  final ip = _permute(cipherBits, _initialPermutation);
  List<int> left = ip.sublist(0, 32);
  List<int> right = ip.sublist(32, 64);

  final rounds = <DesRoundRecord>[];

  // Decryption uses subkeys in reverse order
  for (int r = 0; r < 16; r++) {
    final prevL = List<int>.from(left);
    final prevR = List<int>.from(right);

    final expandedR = _permute(prevR, _expansionTable);
    final xored = _xor(expandedR, subkeys[15 - r]); // Subkey order reversed
    final sboxOut = _applySBoxes(xored);
    final pOut = _permute(sboxOut, _pPermutation);

    final lNext = List<int>.from(prevR);
    final rNext = _xor(prevL, pOut);

    rounds.add(
      DesRoundRecord(
        round: r + 1,
        leftBits: prevL,
        rightBits: prevR,
        subkey: subkeys[15 - r], // Store the used subkey
        expandedR: expandedR,
        xored: xored,
        sboxOut: sboxOut,
        pOut: pOut,
        lNext: lNext,
        rNext: rNext,
      ),
    );

    left = lNext;
    right = rNext;
  }

  final preOutput = _concat(right, left); // Swap L and R for final permutation
  final plainBits = _permute(preOutput, _finalPermutation);

  // convert to ascii 8 bytes
  String plaintext = '';
  for (int i = 0; i < 8; i++) {
    int val = 0;
    for (int j = 0; j < 8; j++) {
      val = (val << 1) | plainBits[i * 8 + j];
    }
    // Only append if it's a printable ASCII character
    if (val >= 32 && val <= 126) {
      plaintext += String.fromCharCode(val);
    } else {
      // Replace non-printable with a placeholder or just skip
      plaintext += ''; // Unicode replacement character
    }
  }

  return DesResult(
    plaintext: plaintext.trim(), // Trim padding spaces
    plaintextBits: plainBits,
    key: key,
    keyBits: keyBits,
    pc1: pc1Res,
    subkeys: subkeys,
    ip: ip,
    rounds: rounds,
    preOutput: preOutput,
    cipherBits: cipherBits,
    cipherHex: cipherHex.toUpperCase(),
  );
}

/// -----------------------------
/// UI: DesPage (both frames)
/// -----------------------------
class DesPage extends StatefulWidget {
  const DesPage({super.key});

  @override
  State<DesPage> createState() => _DesPageState();
}

class _DesPageState extends State<DesPage> {
  // controllers
  final TextEditingController _plainController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();

  final TextEditingController _cipherController = TextEditingController();
  final TextEditingController _keyDecryptController = TextEditingController();

  bool _isEncrypt = true;
  DesResult? _encryptResult;
  DesResult? _decryptResult;
  String _errorMessage = ''; // Untuk menampilkan pesan error

  // theme / harmony
  final Color _primary = const Color(0xFF041413);
  final Color _bg = const Color(0xFFE6E6E6);
  final Color _card = Colors.white; // Changed to white for consistency
  final Color _border = const Color(0xFFDDDDDD);
  final Color _muted = Colors.black87;

  // Keys for SharedPreferences
  static const String _isEncryptKey = 'desIsEncrypt';
  static const String _plainTextKey = 'desPlainText';
  static const String _keyEncryptKey = 'desKeyEncrypt';
  static const String _cipherTextKey = 'desCipherText';
  static const String _keyDecryptKey = 'desKeyDecrypt';

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.dark.copyWith(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        statusBarColor: Colors.white,
      ),
    );
    _loadData(); // Muat data tersimpan

    // Tambahkan listener untuk auto-save
    _plainController.addListener(_saveData);
    _keyController.addListener(_saveData);
    _cipherController.addListener(_saveData);
    _keyDecryptController.addListener(_saveData);
  }

  @override
  void dispose() {
    // Hapus listener untuk mencegah memory leak
    _plainController.removeListener(_saveData);
    _keyController.removeListener(_saveData);
    _cipherController.removeListener(_saveData);
    _keyDecryptController.removeListener(_saveData);

    _plainController.dispose();
    _keyController.dispose();
    _cipherController.dispose();
    _keyDecryptController.dispose();
    super.dispose();
  }

  // ============================
  // 💾 Fungsi untuk menyimpan data ke SharedPreferences
  // ============================
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isEncryptKey, _isEncrypt);
    await prefs.setString(_plainTextKey, _plainController.text);
    await prefs.setString(_keyEncryptKey, _keyController.text);
    await prefs.setString(_cipherTextKey, _cipherController.text);
    await prefs.setString(_keyDecryptKey, _keyDecryptController.text);
  }

  // ============================
  // 📥 Fungsi untuk memuat data dari SharedPreferences
  // ============================
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isEncrypt = prefs.getBool(_isEncryptKey) ?? true;
      _plainController.text = prefs.getString(_plainTextKey) ?? '';
      _keyController.text = prefs.getString(_keyEncryptKey) ?? '';
      _cipherController.text = prefs.getString(_cipherTextKey) ?? '';
      _keyDecryptController.text = prefs.getString(_keyDecryptKey) ?? '';

      // Re-run encryption/decryption if inputs are present
      if (_isEncrypt &&
          _plainController.text.isNotEmpty &&
          _keyController.text.isNotEmpty) {
        _runEncrypt(silent: true);
      } else if (!_isEncrypt &&
          _cipherController.text.isNotEmpty &&
          _keyDecryptController.text.isNotEmpty) {
        _runDecrypt(silent: true);
      }
    });
  }

  // ============================
  // 🔄 Fungsi untuk mengosongkan semua input dan hasil
  // ============================
  void _clearAll() {
    setState(() {
      _plainController.clear();
      _keyController.clear();
      _cipherController.clear();
      _keyDecryptController.clear();
      _isEncrypt = true; // Reset to encrypt mode
      _encryptResult = null;
      _decryptResult = null;
      _errorMessage = '';
    });
    _saveData(); // Simpan state yang sudah dikosongkan
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua input dan hasil telah dikosongkan!'),
        ),
      );
    }
  }

  // header exact (user provided) - Adjusted height and added refresh button
  Widget _header() {
    return Container(
      height: 70, // Consistent with RSA page
      width: double.infinity,
      color: _primary,
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
              iconSize: 24, // Consistent size
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SvgPicture.asset(
            'assets/images/logoenkripsiapps.svg',
            width: 50, // Consistent size
            height: 50, // Consistent size
          ),
          Positioned(
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              iconSize: 24, // Consistent size
              onPressed: _clearAll,
            ),
          ),
        ],
      ),
    );
  }

  // section card builder with border & title
  Widget _sectionCard({
    required String title,
    required Widget child,
    String? subtitle,
    EdgeInsetsGeometry margin = const EdgeInsets.symmetric(vertical: 8),
  }) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16), // Increased padding for better look
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12), // Consistent radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.08).round()),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16, // Consistent font size
              color: Colors.black87,
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Text(
                subtitle,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ),
          const SizedBox(height: 10), // Consistent spacing
          child,
        ],
      ),
    );
  }

  // Custom TextField widget for consistency
  Widget _buildTextField(
    TextEditingController controller,
    String hintText,
    TextInputType keyboardType, {
    int? maxLines,
    bool readOnly = false,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.08).round()),
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
        maxLines: maxLines,
        readOnly: readOnly,
        maxLength: maxLength,
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
          counterText: '', // Hide default maxLength counter
        ),
      ),
    );
  }

  // Custom Action Button widget for consistency
  Widget _buildActionButton(String text, VoidCallback onPressed, Color color) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shadowColor: Colors.black.withAlpha((255 * 0.3).round()),
        elevation: 8,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // monospace widget
  Widget _mono(String s) => SelectableText(
    s,
    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
  );

  // Custom Social Button widget for consistency
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
              color: Colors.black.withAlpha((255 * 0.15).round()),
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

  // ================= actions
  void _runEncrypt({bool silent = false}) {
    setState(() {
      _errorMessage = ''; // Clear previous errors
      _encryptResult = null;
    });

    final pt = _plainController.text;
    final key = _keyController.text;

    if (pt.isEmpty) {
      setState(() {
        _errorMessage = 'Masukkan plaintext (maks 8 karakter).';
      });
      return;
    }
    if (key.length != 8) {
      setState(() {
        _errorMessage = 'Kunci harus tepat 8 karakter.';
      });
      return;
    }

    try {
      setState(() {
        _encryptResult = desEncryptWithSteps(pt, key);
      });
      if (!silent && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Enkripsi DES berhasil!')));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal enkripsi: $e';
      });
    }
    _saveData(); // Save state after operation
  }

  void _runDecrypt({bool silent = false}) {
    setState(() {
      _errorMessage = ''; // Clear previous errors
      _decryptResult = null;
    });

    final cipher = _cipherController.text.trim();
    final key = _keyDecryptController.text;

    if (cipher.isEmpty) {
      setState(() {
        _errorMessage = 'Masukkan cipher HEX (16 digit).';
      });
      return;
    }
    if (cipher.length != 16) {
      setState(() {
        _errorMessage = 'Cipher HEX harus tepat 16 digit.';
      });
      return;
    }
    if (key.length != 8) {
      setState(() {
        _errorMessage = 'Kunci harus tepat 8 karakter.';
      });
      return;
    }

    try {
      setState(() {
        _decryptResult = desDecryptWithSteps(cipher, key);
      });
      if (!silent && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dekripsi DES berhasil!')));
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal dekripsi: $e';
      });
    }
    _saveData(); // Save state after operation
  }

  // share to Gmail
  Future<void> _sendToGmail(String subject, String body) async {
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(body);
    final uri = Uri.parse('mailto:?subject=$encodedSubject&body=$encodedBody');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      final web = Uri.parse(
        'https://mail.google.com/mail/?view=cm&fs=1&su=$encodedSubject&body=$encodedBody',
      );
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  // share to WA
  Future<void> _sendToWhatsApp(String message) async {
    final encoded = Uri.encodeComponent(message);
    final wa = Uri.parse('whatsapp://send?text=$encoded');
    final web = Uri.parse('https://wa.me/?text=$encoded');
    try {
      if (await canLaunchUrl(wa)) {
        await launchUrl(wa, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(web, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  // build top summary card (plaintext, key, ip, subkeys)
  Widget _buildTopSummary(DesResult r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionCard(
          title: '1) Plaintext → ASCII → Binary (8 bytes)',
          subtitle: 'Plaintext di-pad ke 8 byte jika kurang',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plaintext: "${r.plaintext}"'),
              const SizedBox(height: 6),
              const Text(
                'Binary (8-bit groups):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _mono(_bitsToGroupedString(r.plaintextBits, group: 8)),
            ],
          ),
        ),
        _sectionCard(
          title: '2) Key → Binary & PC-1 (56-bit)',
          subtitle: 'Key 8 bytes di-convert lalu PC-1 mengurangi parity bits',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Key: "${r.key}"'),
              const SizedBox(height: 6),
              const Text(
                'Key (8 bytes binary):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _mono(_bitsToGroupedString(r.keyBits, group: 8)),
              const SizedBox(height: 8),
              const Text(
                'PC-1 result (56-bit):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _mono(_bitsToGroupedString(r.pc1, group: 7)),
            ],
          ),
        ),
        _sectionCard(
          title: '3) Key Schedule — 16 Subkeys (PC-2) (48-bit tiap putaran)',
          child: SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: r.subkeys.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final k = r.subkeys[i];
                return Container(
                  width: 220,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'K${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      _mono(_bitsToGroupedString(k, group: 6)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        _sectionCard(
          title: '4) Initial Permutation (IP) → hasil 64-bit',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'IP output (binary, grouped 8-bit):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _mono(_bitsToGroupedString(r.ip, group: 8)),
              const SizedBox(height: 8),
              const Text(
                'L0 (32-bit) & R0 (32-bit):',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'L0',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        _mono(
                          _bitsToGroupedString(r.ip.sublist(0, 32), group: 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'R0',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        _mono(
                          _bitsToGroupedString(r.ip.sublist(32, 64), group: 4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // build rounds detail (each round in bordered small block)
  Widget _buildRounds(DesResult r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final rec in r.rounds)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Round ${rec.round}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'L_prev',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          _mono(_bitsToGroupedString(rec.leftBits, group: 4)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'R_prev',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          _mono(_bitsToGroupedString(rec.rightBits, group: 4)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Expansion E(R) → 48-bit (6-bit groups shown):',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                _mono(_bitsToGroupedString(rec.expandedR, group: 6)),
                const SizedBox(height: 6),
                const Text(
                  'XOR (E(R) XOR Ki) → 48-bit:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                _mono(_bitsToGroupedString(rec.xored, group: 6)),
                const SizedBox(height: 6),
                const Text(
                  'S-Box output (32-bit, 4-bit groups):',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                _mono(_bitsToGroupedString(rec.sboxOut, group: 4)),
                const SizedBox(height: 6),
                const Text(
                  'Permutation P-out (32-bit):',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                _mono(_bitsToGroupedString(rec.pOut, group: 4)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'L_next',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          _mono(_bitsToGroupedString(rec.lNext, group: 4)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'R_next',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          _mono(_bitsToGroupedString(rec.rNext, group: 4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  // build final block
  Widget _buildFinal(DesResult r) {
    return _sectionCard(
      title: 'Final: Pre-output (R16 || L16) → Final Permutation (FP) → Cipher',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pre-output (R16 || L16) (8-bit groups):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          _mono(_bitsToGroupedString(r.preOutput, group: 8)),
          const SizedBox(height: 8),
          const Text(
            'Final Permutation (cipher bits):',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          _mono(_bitsToGroupedString(r.cipherBits, group: 8)),
          const SizedBox(height: 8),
          const Text(
            'Cipher (HEX):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _mono(r.cipherHex)),
              const SizedBox(width: 8),
              _buildActionButton('Salin', () {
                Clipboard.setData(ClipboardData(text: r.cipherHex));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cipher disalin!')),
                );
              }, _primary),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Bagikan hasil:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSocialButton('assets/images/wa.svg', () {
                final msg = '''
🧩 Kode Cipher Enkripsi (DES)

━━━━━━━━━━━━━━━
🔐 Hasil Enkripsi:
${r.cipherHex}

🔑 Kunci Enkripsi:
${r.key}

📜 Petunjuk Dekripsi:
Gunakan kunci "${r.key}" untuk mendekripsi cipher HEX "${r.cipherHex}".
━━━━━━━━━━━━━━━

📘 Pesan ini dibuat otomatis dari aplikasi Enkripsi by Defri
''';
                _sendToWhatsApp(msg);
              }),
              const SizedBox(width: 40),
              _buildSocialButton('assets/images/gmail.svg', () {
                final subject = 'Kode Cipher Enkripsi (DES)';
                final body = '''
━━━━━━━━━━━━━━━
🔐 Hasil Enkripsi:
${r.cipherHex}

🔑 Kunci Enkripsi:
${r.key}

📜 Petunjuk Dekripsi:
Gunakan kunci "${r.key}" untuk mendekripsi cipher HEX "${r.cipherHex}".
━━━━━━━━━━━━━━━

📘 Pesan ini dibuat otomatis dari aplikasi Enkripsi by Defri
''';
                _sendToGmail(subject, body);
              }),
            ],
          ),
        ],
      ),
    );
  }

  // Widget untuk penjelasan kriptografi (dipindahkan ke dalam SingleChildScrollView)
  Widget _buildCryptographyExplanation() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 0.0,
        vertical: 20.0,
      ), // Padding disesuaikan
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            'DES (Data Encryption Standard) adalah algoritma kriptografi simetris yang mengenkripsi data dalam blok 64-bit menggunakan kunci 64-bit (efektif 56-bit). '
            'Ini melibatkan 16 putaran Feistel, di mana setiap putaran menggunakan subkunci yang berbeda. '
            'Meskipun secara historis penting, DES sekarang dianggap tidak aman untuk aplikasi modern karena panjang kuncinya yang pendek, '
            'sehingga rentan terhadap serangan brute-force. Implementasi ini untuk tujuan edukasi.',
            style: TextStyle(color: Colors.black87, height: 1.4),
          ),
          const SizedBox(height: 20), // Padding di bagian paling bawah
        ],
      ),
    );
  }

  // ================== UI frames ==================
  Widget _encryptFrame() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          _sectionCard(
            title: 'Input — Enkripsi (maks 8 karakter)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Masukkan Plaintext:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                _buildTextField(
                  _plainController,
                  'Tulis teks...',
                  TextInputType.text,
                  maxLines: 1,
                  maxLength: 8, // Max 8 characters
                ),
                const SizedBox(height: 10),
                const Text(
                  'Masukkan Key (8 karakter):',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                _buildTextField(
                  _keyController,
                  'Contoh: mySecrK1',
                  TextInputType.text,
                  maxLines: 1,
                  maxLength: 8, // Exactly 8 characters
                ),
                const SizedBox(height: 12),
                Center(
                  child: _buildActionButton(
                    'Enkripsi DES',
                    _runEncrypt,
                    _primary,
                  ),
                ),
              ],
            ),
          ),

          _sectionCard(
            title: 'Hasil Singkat Enkripsi',
            child:
                _encryptResult == null
                    ? const Text(
                      'Hasil akan muncul di sini setelah enkripsi dijalankan.',
                      style: TextStyle(color: Colors.black54),
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cipher (HEX):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        _mono(_encryptResult!.cipherHex),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildActionButton('Salin Cipher', () {
                              Clipboard.setData(
                                ClipboardData(text: _encryptResult!.cipherHex),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cipher disalin!'),
                                ),
                              );
                            }, _primary),
                            const SizedBox(width: 8),
                            Expanded(
                              // Menggunakan Expanded untuk tombol agar tidak overflow
                              child: _buildActionButton(
                                'Lihat Proses Dekripsi',
                                () {
                                  setState(() {
                                    _isEncrypt = false;
                                    _cipherController.text =
                                        _encryptResult!.cipherHex;
                                  });
                                  _saveData();
                                },
                                const Color(
                                  0xFF455A64,
                                ), // Colors.blueGrey.shade700
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
          ),

          if (_encryptResult != null) ...[
            _buildTopSummary(_encryptResult!),
            _sectionCard(
              title: '5) 16 Round Feistel — detail tiap putaran',
              subtitle:
                  'Setiap putaran menampilkan expansion, XOR, S-box result, P-out, dan L/R next',
              child: _buildRounds(_encryptResult!),
            ),
            _buildFinal(_encryptResult!),
          ],
          _buildCryptographyExplanation(), // <--- Dipindahkan ke sini
        ],
      ),
    );
  }

  Widget _decryptFrame() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          _sectionCard(
            title: 'Input — Dekripsi',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Masukkan Cipher (HEX 16 digit):',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                _buildTextField(
                  _cipherController,
                  'Contoh: 0123ABCD...',
                  TextInputType.text,
                  maxLines: 1,
                  maxLength: 16, // Exactly 16 hex digits
                ),
                const SizedBox(height: 10),
                const Text(
                  'Masukkan Key (8 karakter):',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                _buildTextField(
                  _keyDecryptController,
                  'Contoh: mySecrK1',
                  TextInputType.text,
                  maxLines: 1,
                  maxLength: 8, // Exactly 8 characters
                ),
                const SizedBox(height: 12),
                Center(
                  child: _buildActionButton(
                    'Dekripsi DES',
                    _runDecrypt,
                    _primary,
                  ),
                ),
              ],
            ),
          ),

          _sectionCard(
            title: 'Hasil Singkat Dekripsi',
            child:
                _decryptResult == null
                    ? const Text(
                      'Hasil akan muncul di sini setelah dekripsi dijalankan.',
                      style: TextStyle(color: Colors.black54),
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Plaintext (ASCII):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        _mono(_decryptResult!.plaintext),
                        const SizedBox(height: 8),
                        const Text(
                          'Plaintext (binary):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        _mono(
                          _bitsToGroupedString(
                            _decryptResult!.plaintextBits,
                            group: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildActionButton('Salin Plaintext', () {
                          Clipboard.setData(
                            ClipboardData(text: _decryptResult!.plaintext),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Plaintext disalin!')),
                          );
                        }, _primary),
                      ],
                    ),
          ),

          if (_decryptResult != null) ...[
            _sectionCard(
              title: 'Key Schedule & Subkeys',
              child: SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _decryptResult!.subkeys.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final k = _decryptResult!.subkeys[i];
                    return Container(
                      width: 200,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'K${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          _mono(_bitsToGroupedString(k, group: 6)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            _sectionCard(
              title: '16 Round Feistel — Dekripsi (subkeys reversed)',
              child: Column(
                children: [
                  for (final rec in _decryptResult!.rounds)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Round ${rec.round}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('L_prev'),
                                    const SizedBox(height: 4),
                                    _mono(
                                      _bitsToGroupedString(
                                        rec.leftBits,
                                        group: 4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('R_prev'),
                                    const SizedBox(height: 4),
                                    _mono(
                                      _bitsToGroupedString(
                                        rec.rightBits,
                                        group: 4,
                                      ),
                                    ),
                                  ], // <--- Penutup children yang benar
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text('E(R):'),
                          const SizedBox(height: 4),
                          _mono(_bitsToGroupedString(rec.expandedR, group: 6)),
                          const SizedBox(height: 6),
                          const Text('XOR:'),
                          const SizedBox(height: 4),
                          _mono(_bitsToGroupedString(rec.xored, group: 6)),
                          const SizedBox(height: 6),
                          const Text('S-Box out:'),
                          const SizedBox(height: 4),
                          _mono(_bitsToGroupedString(rec.sboxOut, group: 4)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('L_next'),
                                    const SizedBox(height: 4),
                                    _mono(
                                      _bitsToGroupedString(rec.lNext, group: 4),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('R_next'),
                                    const SizedBox(height: 4),
                                    _mono(
                                      _bitsToGroupedString(rec.rNext, group: 4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _buildFinal(_decryptResult!),
          ],
          _buildCryptographyExplanation(), // <--- Dipindahkan ke sini
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(), // Updated header

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
                      color: Colors.black.withAlpha((255 * 0.08).round()),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final buttonWidth = (constraints.maxWidth - 8) / 2;

                    return ToggleButtons(
                      isSelected: [_isEncrypt, !_isEncrypt],
                      onPressed: (index) {
                        setState(() {
                          _isEncrypt = index == 0;
                          _errorMessage = ''; // Clear error when switching mode
                          // Clear relevant input fields when switching mode
                          if (_isEncrypt) {
                            _cipherController.clear();
                            _keyDecryptController.clear();
                            _decryptResult = null;
                          } else {
                            _plainController.clear();
                            _keyController.clear();
                            _encryptResult = null;
                          }
                        });
                        _saveData();
                      },
                      borderRadius: BorderRadius.circular(10),
                      selectedColor: Colors.white,
                      color: Colors.black87,
                      fillColor: _primary,
                      borderColor: Colors.transparent,
                      selectedBorderColor: Colors.transparent,
                      splashColor: _primary.withAlpha((255 * 0.2).round()),
                      highlightColor: _primary.withAlpha((255 * 0.1).round()),
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

            // Body frame
            Expanded(child: _isEncrypt ? _encryptFrame() : _decryptFrame()),
          ],
        ),
      ),
    );
  }
}
