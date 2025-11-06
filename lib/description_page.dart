import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DescriptionPage extends StatefulWidget {
  const DescriptionPage({super.key});

  @override
  State<DescriptionPage> createState() => _DescriptionPageState();
}

class _DescriptionPageState extends State<DescriptionPage>
    with SingleTickerProviderStateMixin {
  // ===========================================================
  // --- controllers & state ----------------------------------
  // ===========================================================
  // Controller untuk input teks terenkripsi (besar, multiline)
  final TextEditingController _encryptedController = TextEditingController();

  // Controller untuk input key (opsional)
  final TextEditingController _keyController = TextEditingController();

  // Cipher yang dipilih sekarang (default Caesar)
  String _selectedCipher = 'Caesar Cipher';

  // Flag busy untuk overlay loader / disable button
  bool _busy = false;

  // Apakah user akan memakai key yang dimasukkan (kontrol Switch)
  bool _useKey = false;

  // Status dan hasil (ditampilkan di bawah)
  String _status = '';
  List<String> _results = [];

  // animation controller untuk loader
  late final AnimationController _loaderController;

  // ===========================================================
  // --- konfigurasi batas / konstanta -------------------------
  // ===========================================================
  final int _vigenereMaxKeyLen =
      4; // brute default (but we will skip brute if key provided)
  final int _playfairMaxKeyLen = 3;
  final int _transpositionMaxCols = 6;
  final int _maxDisplayedCandidates = 200;

  // Daftar cipher yang tersedia
  final List<String> _ciphers = [
    'Caesar Cipher',
    'Vigenère Cipher',
    'Playfair Cipher',
    'Transposition Cipher',
    'ROT13',
  ];

  // ===========================================================
  // --- lifecycle init/dispose --------------------------------
  // ===========================================================
  @override
  void initState() {
    super.initState();
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void dispose() {
    _loaderController.dispose();
    _encryptedController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  // ===========================================================
  // ---------------------- LOGIC (tidak diubah) ---------------
  // Semua fungsi cipher, scoring, brute, dsb. tetap utuh.
  // ===========================================================

  // ------------------------
  // unified english scoring (letters + common words boost)
  // ------------------------
  double englishScore(String text) {
    final s = text.toLowerCase();
    double score = 0.0;

    for (var r in s.runes) {
      final ch = String.fromCharCode(r);
      if (RegExp(r'[a-z]').hasMatch(ch))
        score += 1.0;
      else if (ch == ' ')
        score += 0.5;
      else if (RegExp(r'[0-9]').hasMatch(ch))
        score -= 0.1;
      else
        score -= 0.5;
    }

    const common = [
      ' the ',
      ' and ',
      ' to ',
      ' of ',
      ' is ',
      ' that ',
      ' dan ',
      ' yang ',
      ' di ',
      ' ke ',
      ' pada ',
    ];
    for (final w in common) {
      if (s.contains(w)) score += 8;
    }

    final counts = <String, int>{};
    int letters = 0;
    for (var r in s.runes) {
      final c = String.fromCharCode(r);
      if (RegExp(r'[a-z]').hasMatch(c)) {
        counts[c] = (counts[c] ?? 0) + 1;
        letters++;
      }
    }
    if (letters > 0) {
      final vowels = ['a', 'e', 'i', 'o', 'u'];
      int vcount = 0;
      for (var v in vowels) vcount += counts[v] ?? 0;
      final vowelRatio = vcount / letters;
      score += (1 - (vowelRatio - 0.35).abs()) * 5.0;
    }

    return score;
  }

  // ----------------------
  // Caesar
  // ----------------------
  String _caesarShift(String text, int shift) {
    final buf = StringBuffer();
    for (var r in text.runes) {
      if (r >= 65 && r <= 90) {
        buf.writeCharCode(((r - 65 - shift) % 26 + 26) % 26 + 65);
      } else if (r >= 97 && r <= 122) {
        buf.writeCharCode(((r - 97 - shift) % 26 + 26) % 26 + 97);
      } else {
        buf.writeCharCode(r);
      }
    }
    return buf.toString();
  }

  List<String> solveCaesarAll(String text) {
    final List<String> out = [];
    for (int s = 1; s < 26; s++) {
      out.add('Shift $s: ${_caesarShift(text, s)}');
    }
    return out;
  }

  int _deriveCaesarShiftFromKey(String key) {
    // try parse integer first
    final t = key.trim();
    if (t.isEmpty) return 0;
    final num = int.tryParse(t);
    if (num != null) return num.abs() % 26;
    // otherwise use first letter to derive shift: A/a -> 0, B ->1 ... add 1 so A->1 meaning small shift
    final first = t.codeUnitAt(0);
    if ((first >= 65 && first <= 90) || (first >= 97 && first <= 122)) {
      final up = String.fromCharCode(first).toUpperCase().codeUnitAt(0);
      return (up - 65) % 26;
    }
    return 0;
  }

  // ----------------------
  // ROT13
  // ----------------------
  String solveRot13(String text) {
    final buf = StringBuffer();
    for (var r in text.runes) {
      if (r >= 65 && r <= 90) {
        buf.writeCharCode(((r - 65 + 13) % 26) + 65);
      } else if (r >= 97 && r <= 122) {
        buf.writeCharCode(((r - 97 + 13) % 26) + 97);
      } else {
        buf.writeCharCode(r);
      }
    }
    return buf.toString();
  }

  // ----------------------
  // Vigenere
  // ----------------------
  String _vigenereDecryptWithKey(String cipher, String key) {
    if (key.isEmpty) return cipher;
    final cleanedKey = key.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    if (cleanedKey.isEmpty) return cipher;
    final out = StringBuffer();
    int ki = 0;
    final keyLen = cleanedKey.length;
    for (var r in cipher.runes) {
      final c = String.fromCharCode(r);
      if (RegExp(r'[A-Za-z]').hasMatch(c)) {
        final base = (r >= 65 && r <= 90) ? 65 : 97;
        final kch = cleanedKey.codeUnitAt(ki % keyLen);
        final k = kch - 65;
        final dec = ((r - base - k) % 26 + 26) % 26 + base;
        out.writeCharCode(dec);
        ki++;
      } else {
        out.write(c);
      }
    }
    return out.toString();
  }

  String tryDecryptWithProvidedKey(String cipher, String providedKey) {
    if (providedKey.trim().isEmpty) return cipher;
    final cleaned = providedKey.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return _vigenereDecryptWithKey(cipher, cleaned);
  }

  Iterable<String> _generateAlphaKeysUpToLen(int maxLen) sync* {
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    if (maxLen <= 0) return;
    for (int len = 1; len <= maxLen; len++) {
      if (len == 1) {
        for (int i = 0; i < 26; i++) yield letters[i];
      } else if (len == 2) {
        for (int i = 0; i < 26; i++) {
          for (int j = 0; j < 26; j++) {
            yield letters[i] + letters[j];
          }
        }
      } else if (len == 3) {
        for (int i = 0; i < 26; i++) {
          for (int j = 0; j < 26; j++) {
            for (int k = 0; k < 26; k++) {
              yield letters[i] + letters[j] + letters[k];
            }
          }
        }
      } else if (len == 4) {
        for (int i = 0; i < 26; i++) {
          for (int j = 0; j < 26; j++) {
            for (int k = 0; k < 26; k++) {
              for (int l = 0; l < 26; l++) {
                yield letters[i] + letters[j] + letters[k] + letters[l];
              }
            }
          }
        }
      }
    }
  }

  Future<List<String>> solveVigenereBrute(
    String cipher, {
    int maxLen = 3,
  }) async {
    final List<MapEntry<String, double>> scored = [];
    int tried = 0;
    final iter = _generateAlphaKeysUpToLen(maxLen);
    for (var key in iter) {
      tried++;
      final cand = _vigenereDecryptWithKey(cipher, key);
      final score = englishScore(cand);
      scored.add(MapEntry('key=${key.toUpperCase()} -> $cand', score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    final out = scored.map((e) => e.key).toList();
    out.insert(0, 'Tried keys: $tried (length 1..$maxLen)');
    return out;
  }

  // Automatic helpers (IOC & chi-squared)
  final List<double> _englishFreq = [
    8.167,
    1.492,
    2.782,
    4.253,
    12.702,
    2.228,
    2.015,
    6.094,
    6.966,
    0.153,
    0.772,
    4.025,
    2.406,
    6.749,
    7.507,
    1.929,
    0.095,
    5.987,
    6.327,
    9.056,
    2.758,
    0.978,
    2.360,
    0.150,
    1.974,
    0.074,
  ];

  double _indexOfCoincidence(String text) {
    final counts = List<int>.filled(26, 0);
    int total = 0;
    for (var r in text.runes) {
      final c = String.fromCharCode(r).toUpperCase();
      if (c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90) {
        counts[c.codeUnitAt(0) - 65]++;
        total++;
      }
    }
    if (total <= 1) return 0.0;
    double sum = 0;
    for (var v in counts) sum += v * (v - 1);
    return sum / (total * (total - 1));
  }

  List<int> _estimateKeyLengths(String cipher, {int maxKeyLen = 20}) {
    final cleaned = cipher.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    if (cleaned.isEmpty) return [1];
    final List<MapEntry<int, double>> scores = [];
    for (int kl = 1; kl <= maxKeyLen; kl++) {
      double avgIoc = 0.0;
      int count = 0;
      for (int i = 0; i < kl; i++) {
        final buf = StringBuffer();
        for (int j = i; j < cleaned.length; j += kl) buf.write(cleaned[j]);
        final ioc = _indexOfCoincidence(buf.toString());
        avgIoc += ioc;
        count++;
      }
      avgIoc = (count == 0) ? 0.0 : avgIoc / count;
      final score = (avgIoc - 0.038) * 100;
      scores.add(MapEntry(kl, score.abs()));
    }
    scores.sort((a, b) => a.value.compareTo(b.value));
    return scores.map((e) => e.key).take(6).toList();
  }

  double _chiSquared(List<int> counts, int total) {
    if (total == 0) return double.infinity;
    double sum = 0.0;
    for (int i = 0; i < 26; i++) {
      final expected = _englishFreq[i] * total / 100.0;
      final observed = counts[i].toDouble();
      final diff = observed - expected;
      sum += (diff * diff) / (expected == 0 ? 1 : expected);
    }
    return sum;
  }

  int _bestShiftForColumn(String col) {
    final cleaned = col.replaceAll(RegExp(r'[^A-Z]'), '');
    final countsBase = List<int>.filled(26, 0);
    for (var r in cleaned.runes) {
      final code = r;
      if (code >= 65 && code <= 90) countsBase[code - 65]++;
    }
    int bestShift = 0;
    double bestScore = double.infinity;
    final total = cleaned.length;
    if (total == 0) return 0;
    for (int shift = 0; shift < 26; shift++) {
      final shiftedCounts = List<int>.filled(26, 0);
      for (int i = 0; i < 26; i++)
        shiftedCounts[i] = countsBase[(i + shift) % 26];
      final score = _chiSquared(shiftedCounts, total);
      if (score < bestScore) {
        bestScore = score;
        bestShift = shift;
      }
    }
    return bestShift;
  }

  String _findKeyForLength(String cipher, int keyLen) {
    final cleaned = cipher.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final keyBuf = StringBuffer();
    for (int i = 0; i < keyLen; i++) {
      final col = StringBuffer();
      for (int j = i; j < cipher.length; j += keyLen) {
        final cr = cipher.codeUnitAt(j);
        if (cr >= 65 && cr <= 90) {
          col.writeCharCode(cr);
        } else if (cr >= 97 && cr <= 122) {
          col.writeCharCode(cr - 32);
        }
      }
      final bestShift = _bestShiftForColumn(col.toString());
      final keyChar = String.fromCharCode(65 + bestShift);
      keyBuf.write(keyChar);
    }
    return keyBuf.toString();
  }

  Map<String, String> automaticVigenereCrack(
    String cipher, {
    int maxKeyLen = 16,
  }) {
    final candidates = <MapEntry<String, double>>[];
    final keyLenCandidates = _estimateKeyLengths(cipher, maxKeyLen: maxKeyLen);
    for (final kl in keyLenCandidates) {
      final guessedKey = _findKeyForLength(cipher, kl);
      final plain = _vigenereDecryptWithKey(cipher, guessedKey);
      final score = englishScore(plain);
      candidates.add(MapEntry('$guessedKey|$kl', score));
    }
    for (int kl = 1; kl <= maxKeyLen; kl++) {
      final guessedKey = _findKeyForLength(cipher, kl);
      final plain = _vigenereDecryptWithKey(cipher, guessedKey);
      final score = englishScore(plain);
      candidates.add(MapEntry('$guessedKey|$kl', score));
    }
    candidates.sort((a, b) => b.value.compareTo(a.value));
    final best = candidates.first;
    final parts = best.key.split('|');
    final bestKey = parts[0];
    final bestPlain = _vigenereDecryptWithKey(cipher, bestKey);
    return {'key': bestKey, 'plain': bestPlain};
  }

  // ----------------------
  // Playfair
  // ----------------------
  String _normalizePlayfairText(String s) {
    final buffer = StringBuffer();
    for (var r in s.runes) {
      final c = String.fromCharCode(r);
      if (RegExp(r'[A-Za-z]').hasMatch(c)) {
        final low = c.toLowerCase();
        buffer.write(low == 'j' ? 'i' : low);
      }
    }
    return buffer.toString();
  }

  List<List<String>> _buildPlayfairMatrixFromKey(String rawKey) {
    final used = <String>{};
    final entries = <String>[];
    for (var r in rawKey.runes) {
      final ch = String.fromCharCode(r).toLowerCase();
      if (!RegExp(r'[a-z]').hasMatch(ch)) continue;
      final letter = (ch == 'j') ? 'i' : ch;
      if (!used.contains(letter)) {
        used.add(letter);
        entries.add(letter);
      }
    }
    for (var r in 'abcdefghijklmnopqrstuvwxyz'.runes) {
      final letter = String.fromCharCode(r);
      if (letter == 'j') continue;
      if (!used.contains(letter)) {
        used.add(letter);
        entries.add(letter);
      }
    }
    final matrix = List.generate(5, (_) => List<String>.filled(5, ''));
    int idx = 0;
    for (int rr = 0; rr < 5; rr++) {
      for (int cc = 0; cc < 5; cc++) {
        matrix[rr][cc] = entries[idx++];
      }
    }
    return matrix;
  }

  Map<String, Point<int>> _matrixPositions(List<List<String>> m) {
    final pos = <String, Point<int>>{};
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 5; c++) pos[m[r][c]] = Point(r, c);
    }
    return pos;
  }

  String _playfairDecryptWithMatrix(String cipher, List<List<String>> matrix) {
    final pos = _matrixPositions(matrix);
    final buf = StringBuffer();
    for (int i = 0; i < cipher.length; i += 2) {
      if (i + 1 >= cipher.length) {
        buf.write(cipher[i]);
        continue;
      }
      final a = cipher[i];
      final b = cipher[i + 1];
      if (!pos.containsKey(a) || !pos.containsKey(b)) continue;
      final pa = pos[a]!;
      final pb = pos[b]!;
      if (pa.x == pb.x) {
        final c1 = matrix[pa.x][(pa.y - 1 + 5) % 5];
        final c2 = matrix[pb.x][(pb.y - 1 + 5) % 5];
        buf.write(c1);
        buf.write(c2);
      } else if (pa.y == pb.y) {
        final c1 = matrix[(pa.x - 1 + 5) % 5][pa.y];
        final c2 = matrix[(pb.x - 1 + 5) % 5][pb.y];
        buf.write(c1);
        buf.write(c2);
      } else {
        final c1 = matrix[pa.x][pb.y];
        final c2 = matrix[pb.x][pa.y];
        buf.write(c1);
        buf.write(c2);
      }
    }
    return buf.toString();
  }

  Iterable<List<int>> _permutationsIndices(List<int> list) sync* {
    if (list.isEmpty) {
      yield <int>[];
      return;
    }
    for (int i = 0; i < list.length; i++) {
      final val = list[i];
      final remaining = List<int>.from(list)..removeAt(i);
      for (var perm in _permutationsIndices(remaining)) yield [val, ...perm];
    }
  }

  Iterable<String> _generatePlayfairKeysUpToLen(int maxLen) sync* {
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    final L = letters.split('');
    for (int i = 0; i < 26; i++) yield L[i];
    if (maxLen >= 2) {
      for (int i = 0; i < 26; i++) {
        for (int j = 0; j < 26; j++) {
          if (j == i) continue;
          yield L[i] + L[j];
        }
      }
    }
    if (maxLen >= 3) {
      for (int i = 0; i < 26; i++) {
        for (int j = 0; j < 26; j++) {
          if (j == i) continue;
          for (int k = 0; k < 26; k++) {
            if (k == i || k == j) continue;
            yield L[i] + L[j] + L[k];
          }
        }
      }
    }
  }

  Future<List<String>> solvePlayfairBrute(String cipherInput) async {
    final normalized = _normalizePlayfairText(cipherInput);
    final text =
        normalized.length % 2 == 0
            ? normalized
            : normalized.substring(0, normalized.length - 1);
    final List<MapEntry<String, double>> scored = [];
    int tried = 0;
    for (var key in _generatePlayfairKeysUpToLen(_playfairMaxKeyLen)) {
      tried++;
      final matrix = _buildPlayfairMatrixFromKey(key);
      final cand = _playfairDecryptWithMatrix(text, matrix);
      final score = englishScore(cand);
      scored.add(MapEntry('key=${key.toUpperCase()} -> $cand', score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    final out = scored.map((e) => e.key).toList();
    out.insert(
      0,
      'Tried Playfair keys (unique letters) count: $tried (len 1..$_playfairMaxKeyLen)',
    );
    return out;
  }

  // ----------------------
  // Columnar transposition
  // ----------------------
  String _colTranspositionDecrypt(String cipher, int cols, List<int> order) {
    final n = cipher.length;
    final rows = (n / cols).ceil();
    final base = n ~/ cols;
    final extra = n % cols;
    final colLens = List<int>.filled(cols, base);
    for (int i = 0; i < extra; i++) colLens[i]++;
    final colsContent = List<String>.filled(cols, '');
    int idx = 0;
    for (int k = 0; k < cols; k++) {
      final colIndex = order[k];
      final len = colLens[colIndex];
      if (idx + len > cipher.length) return '';
      colsContent[colIndex] = cipher.substring(idx, idx + len);
      idx += len;
    }
    final sb = StringBuffer();
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (r < colsContent[c].length) sb.write(colsContent[c][r]);
      }
    }
    return sb.toString();
  }

  List<int> _orderFromKey(String key) {
    final cleaned = key.split('');
    final pairs = <MapEntry<String, int>>[];
    for (int i = 0; i < cleaned.length; i++) {
      pairs.add(MapEntry(cleaned[i].toLowerCase(), i));
    }
    // sort by character then by index to stabilize duplicates
    pairs.sort((a, b) {
      final c = a.key.compareTo(b.key);
      if (c != 0) return c;
      return a.value.compareTo(b.value);
    });
    // return list where for rank k we give original index
    return pairs.map((e) => e.value).toList();
  }

  Future<List<String>> solveTranspositionBrute(String cipher) async {
    final List<MapEntry<String, double>> scored = [];
    int tried = 0;
    final maxCols = min(_transpositionMaxCols, max(2, cipher.length));
    for (int cols = 2; cols <= maxCols; cols++) {
      final baseIndices = List<int>.generate(cols, (i) => i);
      final perms = _permutationsIndices(baseIndices);
      for (var p in perms) {
        tried++;
        final cand = _colTranspositionDecrypt(cipher, cols, p);
        if (cand.isEmpty) continue;
        final score = englishScore(cand);
        scored.add(MapEntry('cols=$cols order=${p.join()} -> $cand', score));
      }
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    final out = scored.map((e) => e.key).toList();
    out.insert(0, 'Tried transposition combos: $tried (cols 2..$maxCols)');
    return out;
  }

  // ----------------------
  // Master dispatcher
  // ----------------------
  Future<void> _describeAction() async {
    final input = _encryptedController.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan teks terenkripsi dulu.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _status = 'Processing $_selectedCipher...';
      _results = [];
    });
    _loaderController.repeat();

    final List<String> out = [];
    try {
      await Future.delayed(const Duration(milliseconds: 200));

      final providedKey = _useKey ? _keyController.text.trim() : '';

      if (_selectedCipher == 'Caesar Cipher') {
        out.add('Cipher: Caesar');
        if (providedKey.isNotEmpty) {
          final shift = _deriveCaesarShiftFromKey(providedKey);
          final dec = _caesarShift(input, shift);
          out.add('Used key: $providedKey (shift=$shift)');
          out.add('Result: $dec');
        } else {
          final all = solveCaesarAll(input);
          out.add('No key: menampilkan semua shift 1..25');
          out.addAll(all);
        }
      } else if (_selectedCipher == 'ROT13') {
        final dec = solveRot13(input);
        out.add('Cipher: ROT13 (fixed shift 13)');
        out.add('Note: ROT13 tidak memakai key, field key akan diabaikan.');
        out.add('Result: $dec');
      } else if (_selectedCipher == 'Vigenère Cipher') {
        out.add('Cipher: Vigenère');
        if (providedKey.isNotEmpty) {
          final dec = tryDecryptWithProvidedKey(input, providedKey);
          out.add('Used key: $providedKey');
          out.add('Result: $dec');
        } else {
          out.add(
            'Auto: mencoba tebakan cepat + brute kecil (1..$_vigenereMaxKeyLen)',
          );
          final auto = automaticVigenereCrack(
            input,
            maxKeyLen: min(12, _vigenereMaxKeyLen),
          );
          final bestAuto = auto['plain'] ?? '';
          final bestKey = auto['key'] ?? '';
          out.add('Auto guess key: $bestKey');
          out.add(
            'Auto guess plain sample: ${bestAuto.length > 200 ? bestAuto.substring(0, 200) + '...' : bestAuto}',
          );
          final res = await solveVigenereBrute(
            input,
            maxLen: _vigenereMaxKeyLen,
          );
          out.addAll(res);
        }
      } else if (_selectedCipher == 'Playfair Cipher') {
        out.add('Cipher: Playfair');
        if (providedKey.isNotEmpty) {
          final matrix = _buildPlayfairMatrixFromKey(providedKey);
          final norm = _normalizePlayfairText(input);
          final text =
              norm.length % 2 == 0 ? norm : norm.substring(0, norm.length - 1);
          final cand = _playfairDecryptWithMatrix(text, matrix);
          out.add('Used key: $providedKey');
          out.add('Result: $cand');
        } else {
          out.add('Brute-force Playfair kecil (1..$_playfairMaxKeyLen)');
          final res = await solvePlayfairBrute(input);
          out.addAll(res);
        }
      } else if (_selectedCipher == 'Transposition Cipher') {
        out.add('Cipher: Columnar Transposition');
        if (providedKey.isNotEmpty) {
          final order = _orderFromKey(providedKey);
          final cols = providedKey.length;
          final cand = _colTranspositionDecrypt(input, cols, order);
          out.add('Used key: $providedKey -> order=${order.join()}');
          out.add('Result: $cand');
        } else {
          out.add(
            'No key: mencoba semua kombinasi kolom (2..$_transpositionMaxCols)',
          );
          final res = await solveTranspositionBrute(input);
          out.addAll(res);
        }
      }
    } catch (e) {
      out.add('Terjadi error saat processing: $e');
    }

    _loaderController.stop();
    setState(() {
      _busy = false;
      _status = 'Selesai';
      if (out.length > _maxDisplayedCandidates) {
        final head = out.sublist(0, 1);
        final body = out.sublist(1, min(out.length, _maxDisplayedCandidates));
        _results = [
          ...head,
          '--- Menampilkan top $_maxDisplayedCandidates dari ${out.length - 1} kandidat ---',
          ...body,
          'Untuk melihat semua kandidat, sesuaikan _maxDisplayedCandidates di kode.',
        ];
      } else {
        _results = out;
      }
    });
  }

  // ===========================================================
  // --- Reset semua field (dipanggil dari tombol Reset) ------
  // ===========================================================
  void _resetAll() {
    setState(() {
      _encryptedController.clear();
      _keyController.clear();
      _selectedCipher = _ciphers.first;
      _useKey = false;
      _results = [];
      _status = '';
      _busy = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Form di-reset.')));
  }

  // ===========================================================
  // --- Loader overlay (animasi dan tampilan ketika _busy) ----
  // ===========================================================
  Widget _buildLoaderOverlay({
    Duration duration = const Duration(milliseconds: 2000),
    double busyOpacity = 1.0,
  }) {
    return AnimatedOpacity(
      duration: duration,
      opacity: _busy ? busyOpacity : 0.0,
      curve: Curves.easeOut,
      child: IgnorePointer(
        ignoring: !_busy,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withOpacity(0.45),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: AnimatedBuilder(
                      animation: _loaderController,
                      builder: (context, _) {
                        final v = _loaderController.value;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.rotate(
                              angle: v * 2 * pi,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.greenAccent.shade400,
                                    width: 2.2,
                                  ),
                                ),
                              ),
                            ),
                            Transform.rotate(
                              angle: -v * 2 * pi * 1.25,
                              child: Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.lightGreenAccent.shade100,
                                    width: 2.0,
                                  ),
                                ),
                              ),
                            ),
                            Transform.rotate(
                              angle: v * 2 * pi * 2.2,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white70,
                                    width: 1.6,
                                  ),
                                  color: Colors.white.withOpacity(0.02),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.vpn_key_rounded,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedBuilder(
                    animation: _loaderController,
                    builder: (context, _) {
                      final t = (_loaderController.value * 3).floor() % 4;
                      final dots = '.' * t;
                      return Column(
                        children: [
                          Text(
                            'Decrypting...$dots',
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              color: Color(0xFF90EE90),
                              fontSize: 18,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _status,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================
  // ---------------------- UI BUILD ----------------------------
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // tap di luar untuk menutup keyboard (umum)
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: const Color(0xFFE6E6E6),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------------------------------------------------------
                // HEADER (tetap ada logo & judul)
                // NOTE: tombol reset di header DIHAPUS sesuai permintaan.
                // Reset sekarang ada di samping switch di bawah input text.
                // -------------------------------------------------------
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
                      children: [
                        // Logo aplikasi (SVG)
                        SvgPicture.asset(
                          'assets/images/logoenkripsiapps.svg',
                          height: 42,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'DESKRIPSI',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF11E482),
                          ),
                        ),
                        const Spacer(),
                        // NOTE: IconButton Reset di header dihilangkan agar Reset
                        // diposisikan sesuai permintaan (di samping switch).
                      ],
                    ),
                  ),
                ),

                // -------------------------------------------------------
                // BODY utama (scrollable)
                // Kita susun ulang: Dropdown -> Encrypted Input -> (Reset+Switch Row) -> Key Input
                // -------------------------------------------------------
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 90),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // -------------------------------------------------------
                        // Label: Pilih cipher
                        // -------------------------------------------------------
                        const Text(
                          'Pilih cipher:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        // -------------------------------------------------------
                        // Dropdown modern (dibungkus Container untuk styling)
                        // IMPORTANT: agar dropdown tidak memicu scroll/shift,
                        // kita panggil FocusScope.of(context).unfocus() sebelum setState.
                        // -------------------------------------------------------
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F7FB), // background lembut
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black12, width: 1),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCipher,
                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF1C8D70),
                                size: 26,
                              ),
                              dropdownColor: const Color(0xFFF6F7FB),
                              borderRadius: BorderRadius.circular(14),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                              items:
                                  _ciphers
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.lock_outline,
                                                  color: Colors.black45,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 10),
                                                Text(c),
                                              ],
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) {
                                // Hapus fokus keyboard dulu supaya scroll tidak berpindah
                                FocusScope.of(context).unfocus();
                                // Update pilihan cipher (tetap pakai state yang sekarang)
                                setState(() {
                                  _selectedCipher = v!;
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // -------------------------------------------------------
                        // LABEL + Input teks terenkripsi (UTAMA)
                        // Penempatan: berada di ATAS row Reset+Switch (sesuai permintaan)
                        // -------------------------------------------------------
                        const Text(
                          'Masukkan teks terenkripsi:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        // Kotak input teks (besar), jangan ubah controller / logika
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _encryptedController,
                            maxLines: 6,
                            decoration: const InputDecoration(
                              hintText: 'Tempel teks terenkripsi di sini...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // -------------------------------------------------------
                        // ROW: Reset button + Switch (posisi di tengah bawah input text)
                        // - Reset memanggil _resetAll() yang sudah ada
                        // - Switch mengontrol _useKey
                        // -------------------------------------------------------
                        // 🔁 Tombol Reset & Switch (modern style)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Tombol Reset - disamakan dengan Deskripsi Button
                            ElevatedButton.icon(
                              onPressed: _busy ? null : _resetAll,
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white, // ikon putih
                              ),
                              label: const Text(
                                'Reset',
                                style: TextStyle(
                                  color: Colors.white, // teks putih
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF041413,
                                ), // 🌿 warna sama seperti Deskripsi button
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 6, // bayangan lembut biar modern
                              ),
                            ),

                            const SizedBox(width: 18),

                            // 🧩 Switch + label - tampilan modern
                            Column(
                              children: [
                                const Text(
                                  'Gunakan key',
                                  style: TextStyle(
                                    color: Color(
                                      0xFF041413,
                                    ), // teks hijau senada
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Switch(
                                  value: _useKey,
                                  activeColor: const Color.fromARGB(
                                    255,
                                    255,
                                    255,
                                    255,
                                  ), // warna aktif neon hijau
                                  activeTrackColor: const Color(
                                    0xFF041413,
                                  ), // jalur switch hijau toska
                                  inactiveThumbColor: Colors.white,
                                  inactiveTrackColor: Colors.grey.shade400,
                                  onChanged: (v) => setState(() => _useKey = v),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // -------------------------------------------------------
                        // Input key (DI BAWAH row Reset+Switch) sesuai permintaan
                        // - Tidak mengubah perilaku _keyController maupun hint text
                        // -------------------------------------------------------
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _keyController,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.all(12),
                              hintText:
                                  'Masukkan key (opsional) — contoh: SECRET atau 3 untuk Caesar',
                              border: InputBorder.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // -------------------------------------------------------
                        // Tombol aksi: "Deskripsi" (tetap di posisi semula)
                        // - Tidak mengubah fungsionalitas / state handling
                        // -------------------------------------------------------
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _busy ? null : _describeAction,
                            icon:
                                _busy
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.description,
                                      color: Colors.white,
                                    ), // ikon putih
                            label: Text(
                              _busy ? 'Memproses...' : 'Deskripsi',
                              style: const TextStyle(
                                color: Colors.white, // 📝 warna teks
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFF041413,
                              ), // 🌿 bg hijau elegan
                              foregroundColor:
                                  Colors.white, // teks & ikon default putih
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 6,
                            ),
                          ),
                        ),

                        // -------------------------------------------------------
                        // Bagian hasil: menampilkan status dan daftar hasil
                        // (Tidak mengubah logik penempatan hasil / copy to clipboard)
                        // -------------------------------------------------------
                        const Text(
                          'Hasil:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (_status.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(_status),
                          ),
                        const SizedBox(height: 8),
                        if (_results.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Belum ada hasil. Tekan "Deskripsi" untuk mulai.',
                            ),
                          ),

                        // -------------------------------------------------------
                        // Daftar hasil (tappable -> copy to clipboard)
                        // -------------------------------------------------------
                        for (int i = 0; i < _results.length; i++)
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: _results[i]),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Teks disalin ke clipboard'),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: SelectableText(
                                _results[i],
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tampilkan loader overlay saat _busy true
          if (_busy) _buildLoaderOverlay(),
        ],
      ),
    );
  }
}
