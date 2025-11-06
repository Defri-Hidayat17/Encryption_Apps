import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:encryptionapps/utils/crypto_utils.dart';

class CaesarCipherPage extends StatefulWidget {
  const CaesarCipherPage({super.key});

  @override
  State<CaesarCipherPage> createState() => _CaesarCipherPageState();
}

class _CaesarCipherPageState extends State<CaesarCipherPage> {
  final TextEditingController _plainController = TextEditingController();
  String _result = '';
  int _autoShift = 0;

  // ============================
  // 🔐 Fungsi kirim ke Gmail (langsung buka aplikasi Gmail)
  // ============================
  // Contoh: gunakan ini menggantikan implementasi lama _sendToGmail()

  Future<void> _sendToGmail() async {
    if (_result.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada hasil yang bisa dikirim.')),
      );
      return;
    }

    // Teks yang rapi — gunakan newline \n untuk baris baru
    final String message = '''
💀 ENCRYPTED MESSAGE - CYBER OPS TEAM

━━━━━━━━━━━━━━━━━━
🧠 Kode Enkripsi:
$_result

🔓 Petunjuk Dekripsi:
Gunakan shift $_autoShift untuk membuka pesan ini.

━━━━━━━━━━━━━━━━━━

🧬 📘 Pesan ini dibuat otomatis dari aplikasi Enkripsi by Defri
''';

    // Subject biasa (jangan encode pakai +)
    final String subject = '🔐 Encrypted Message (Confidential)';

    // Encode komponen menggunakan Uri.encodeComponent => spasi jadi %20, bukan +
    final String encodedSubject = Uri.encodeComponent(subject);
    final String encodedBody = Uri.encodeComponent(message);

    // Buat mailto dengan body & subject yang sudah di-encode
    final Uri mailtoUri = Uri.parse(
      'mailto:?subject=$encodedSubject&body=$encodedBody',
    );

    try {
      // Buka Gmail / app email default
      await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membuka aplikasi email...')),
      );
    } catch (e) {
      // fallback ke web Gmail jika perlu
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
        buffer.writeCharCode(((char - 65 + shift) % 26) + 65);
      } else if (char >= 97 && char <= 122) {
        buffer.writeCharCode(((char - 97 + shift) % 26) + 97);
      } else {
        buffer.writeCharCode(char);
      }
    }
    return buffer.toString();
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
    });
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

    final message = '''
🧩 *Kode Cipher Enkripsi (Caesar)*

━━━━━━━━━━━━━━━
🔐 *Hasil Enkripsi:*
```$_result```

📜 *Petunjuk Dekripsi:*
Gunakan *shift $_autoShift* untuk membuka pesan ini.
━━━━━━━━━━━━━━━

📘 _Pesan ini dibuat otomatis dari aplikasi Enkripsi by Defri_
''';

    // Otomatis salin teks ke clipboard
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

  // ============================
  // 🧱 UI
  // ============================
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
                      textInputAction: TextInputAction.done,
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
                          'Enkripsi Otomatis',
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
                                  'Gunakan shift $_autoShift untuk mendekripsi pesan ini.';
                              Clipboard.setData(ClipboardData(text: info));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Petunjuk "$info" disalin!'),
                                ),
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
                      'Caesar Cipher adalah teknik enkripsi sederhana dengan menggeser huruf alfabet sejumlah posisi tertentu.\n'
                      'Pada versi ini, pergeseran ditentukan otomatis oleh sistem (acak antara 1–25).\n'
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

                          // 🔗 IKON SOSIAL
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // WhatsApp
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

                              // Gmail
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
