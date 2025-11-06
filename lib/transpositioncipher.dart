import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

class TranspositionCipherPage extends StatefulWidget {
  const TranspositionCipherPage({super.key});

  @override
  State<TranspositionCipherPage> createState() =>
      _TranspositionCipherPageState();
}

class _TranspositionCipherPageState extends State<TranspositionCipherPage> {
  final TextEditingController _plainController = TextEditingController();
  String _result = '';
  List<int> _autoKey = [];

  // ========================================
  // 🔑 Membuat kunci otomatis (urutan kolom)
  // ========================================
  List<int> _generateAutoKey(int length) {
    List<int> key = List.generate(length, (i) => i);
    key.shuffle(Random());
    return key;
  }

  // ========================================
  // 🔒 Enkripsi Columnar Transposition Cipher
  // ========================================
  String transpositionEncrypt(String text, List<int> key) {
    text = text.replaceAll(RegExp(r'\s+'), ''); // hapus spasi
    int col = key.length;
    int row = (text.length / col).ceil();

    // padding dengan 'X' jika perlu
    text = text.padRight(row * col, 'X');

    List<List<String>> matrix = List.generate(row, (_) => List.filled(col, ''));
    int index = 0;
    for (int r = 0; r < row; r++) {
      for (int c = 0; c < col; c++) {
        matrix[r][c] = text[index];
        index++;
      }
    }

    StringBuffer encrypted = StringBuffer();
    for (int k = 0; k < col; k++) {
      int c = key.indexOf(k); // urutkan kolom sesuai key
      for (int r = 0; r < row; r++) {
        encrypted.write(matrix[r][c]);
      }
    }

    return encrypted.toString();
  }

  void _autoEncrypt() {
    final text = _plainController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan teks terlebih dahulu!')),
      );
      return;
    }

    final key = _generateAutoKey(min(5, text.length)); // panjang kunci max 5
    final encrypted = transpositionEncrypt(text, key);

    setState(() {
      _autoKey = key;
      _result = encrypted;
    });
  }

  String _keyToString(List<int> key) => key.join(',');

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

    final keyStr = _keyToString(_autoKey);

    final message = '''
🧩 *Kode Cipher Enkripsi (Transposition)*

━━━━━━━━━━━━━━━
🔐 *Hasil Enkripsi:*
```$_result```

📜 *Petunjuk Dekripsi:*
Gunakan urutan kolom "$keyStr" untuk membuka pesan ini.
━━━━━━━━━━━━━━━

📘 _Pesan ini dibuat otomatis dari aplikasi Enkripsi by Defri_
''';

    await Clipboard.setData(ClipboardData(text: message));
    final encodedMessage = Uri.encodeComponent(message);
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

    final keyStr = _keyToString(_autoKey);

    final String message = '''
💀 ENCRYPTED MESSAGE - CYBER OPS TEAM (Transposition Cipher)

━━━━━━━━━━━━━━━━━━
🧠 Kode Enkripsi:
$_result

🔓 Petunjuk Dekripsi:
Gunakan urutan kolom "$keyStr" untuk membuka pesan ini.

━━━━━━━━━━━━━━━━━━

📘 Pesan ini dibuat otomatis dari aplikasi Enkripsi by Defri
''';

    final String subject = '🔐 Encrypted Message (Confidential)';
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
              height: 55,
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
                      iconSize: 20,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  SvgPicture.asset(
                    'assets/images/logoenkripsiapps.svg',
                    width: 45,
                    height: 45,
                  ),
                ],
              ),
            ),

            // BODY
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Masukkan teks untuk dienkripsi:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _plainController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        hintText: 'Tulis teks...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Center(
                      child: ElevatedButton(
                        onPressed: _autoEncrypt,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF041413),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Enkripsi Sekarang',
                          style: TextStyle(fontSize: 15, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Hasil Enkripsi:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SelectableText(
                        _result.isEmpty
                            ? 'Hasil akan muncul di sini...'
                            : _result,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (_result.isNotEmpty)
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _result));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Hasil disalin!')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF041413),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Salin Hasil'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () {
                              final info =
                                  'Gunakan urutan kolom "${_keyToString(_autoKey)}" untuk mendekripsi pesan ini.';
                              Clipboard.setData(ClipboardData(text: info));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Petunjuk disalin!')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF041413),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.info_outline, size: 18),
                            label: const Text('Salin Petunjuk Cipher'),
                          ),
                        ],
                      ),

                    const SizedBox(height: 30),
                    const Divider(),
                    const SizedBox(height: 8),

                    const Text(
                      '📘 Penjelasan Kriptografi:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const SelectableText(
                      'Transposition Cipher adalah metode enkripsi dengan cara menukar posisi huruf. '
                      'Salah satu contohnya adalah columnar transposition cipher, di mana teks ditulis ke dalam kolom, '
                      'lalu kolom dibaca berdasarkan urutan kunci.',
                      style: TextStyle(color: Colors.black87, height: 1.4),
                    ),

                    const SizedBox(height: 32),
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'Send encryption code to',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
                              GestureDetector(
                                onTap: _sendToWhatsApp,
                                child: Container(
                                  width: 65,
                                  height: 65,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: SvgPicture.asset(
                                      'assets/images/wa.svg',
                                      width: 32,
                                      height: 32,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 40),
                              GestureDetector(
                                onTap: _sendToGmail,
                                child: Container(
                                  width: 65,
                                  height: 65,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: SvgPicture.asset(
                                      'assets/images/gmail.svg',
                                      width: 20,
                                      height: 20,
                                    ),
                                  ),
                                ),
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
