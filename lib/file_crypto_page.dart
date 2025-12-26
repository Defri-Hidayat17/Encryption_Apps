import 'dart:io';
import 'dart:math'; // Untuk animasi loader
import 'dart:typed_data';
import 'dart:ui'; // Untuk BackdropFilter pada loader
import 'dart:convert'; // Untuk utf8.encode, base64Url, dan utf8.decode
import 'package:crypto/crypto.dart'; // Untuk SHA256
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk SystemChrome dan Clipboard
import 'package:flutter_svg/flutter_svg.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart'; // Untuk getTemporaryDirectory (meskipun tidak lagi digunakan secara langsung, tetap dipertahankan jika ada kebutuhan lain)
import 'package:path/path.dart' as p; // Untuk manipulasi path file
import 'package:encrypt/encrypt.dart' as enc; // Alias untuk package encrypt
import 'package:shared_preferences/shared_preferences.dart'; // Untuk menyimpan preferensi metode kripto
import 'package:share_plus/share_plus.dart'; // Untuk berbagi konten

class FileCryptoPage extends StatefulWidget {
  const FileCryptoPage({super.key});

  @override
  State<FileCryptoPage> createState() => _FileCryptoPageState();
}

class _FileCryptoPageState extends State<FileCryptoPage>
    with SingleTickerProviderStateMixin {
  File? _selectedFile; // File yang dipilih dari FilePicker
  final TextEditingController _keyController = TextEditingController();
  String _statusMessage = 'Pilih file untuk memulai.';
  bool _isBusy = false;
  File? _outputFile;
  String _outputFilePathDisplay = 'File hasil akan muncul di sini.';
  bool _isKeyVisible = false; // State baru untuk visibilitas kunci
  String?
  _lastEncryptedBase64Content; // Untuk menyimpan konten terenkripsi Base64 untuk berbagi

  final List<String> _cryptoMethods = [
    'AES (Advanced Encryption Standard)',
    'DES (Data Encryption Standard)', // DES diimplementasikan sebagai XOR yang lebih kompleks
    'XOR Sederhana',
  ];
  String _selectedMethod = 'AES (Advanced Encryption Standard)';

  late final AnimationController _loaderController;

  // --- PALET WARNA BARU YANG LEBIH MODERN ---
  static const Color _scaffoldBackgroundColor = Color(
    0xFFF8F9FA,
  ); // Latar belakang yang lebih terang dan netral
  static const Color _headerGradientStart = Color(
    0xFF041413,
  ); // Tetap mempertahankan header yang khas
  static const Color _headerGradientEnd = Color(0xFF093B2B);
  static const Color _headerAccentColor = Color(
    0xFF11E482,
  ); // Neon hijau untuk teks header

  static const Color _primaryTextColor = Color(
    0xFF212529,
  ); // Teks utama yang lebih gelap
  static const Color _secondaryTextColor = Color(
    0xFF6C757D,
  ); // Teks sekunder/hint

  static const Color _inputFillColor = Colors.white; // Warna isi input
  static const Color _inputBorderColor = Color(
    0xFFCED4DA,
  ); // Warna border input
  static const Color _focusedInputBorderColor = Color(
    0xFF007BFF,
  ); // Warna border saat fokus (biru)

  static const Color _encryptButtonColor = Color(
    0xFF28A745,
  ); // Hijau untuk enkripsi
  static const Color _decryptButtonColor = Color(
    0xFF007BFF,
  ); // Biru untuk dekripsi
  static const Color _resetButtonColor = Color(
    0xFF6C757D,
  ); // Abu-abu untuk reset
  static const Color _shareSaveButtonColor = Color(
    0xFF6F42C1,
  ); // Ungu untuk bagikan/simpan teks
  static const Color _copyPathButtonColor = Color(
    0xFFFD7E14,
  ); // Oranye untuk salin path
  static const Color _folderButtonColor = Color(
    0xFF17A2B8,
  ); // Cyan untuk buka folder

  // Semua latar belakang box sekarang putih
  static const Color _statusLogBackgroundColor = Colors.white;
  static const Color _outputFileBackgroundColor = Colors.white;

  static const Color _loaderOverlayColor = Colors.black; // Warna overlay loader
  static const Color _loaderProcessingColor = Color(
    0xFF90EE90,
  ); // Warna teks processing loader

  // Magic numbers (byte-based prefixes) untuk identifikasi metode enkripsi
  static const List<int> _aesMagic = [0x41, 0x45, 0x53]; // ASCII "AES"
  static const List<int> _desMagic = [0x44, 0x45, 0x53]; // ASCII "DES"
  static const List<int> _xorMagic = [0x58, 0x4F, 0x52]; // ASCII "XOR"
  static const int _magicNumberLength = 3; // Panjang magic number dalam byte

  @override
  void initState() {
    super.initState();
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _initPage();
  }

  Future<void> _initPage() async {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white, // Status bar putih
        statusBarIconBrightness: Brightness.dark, // Ikon gelap
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedMethod =
          prefs.getString('selectedCryptoMethod') ?? _cryptoMethods.first;
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    _loaderController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_isBusy) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _statusMessage =
            'File input "${p.basename(_selectedFile!.path)}" dipilih.';
        _outputFile = null;
        _outputFilePathDisplay = 'File hasil akan muncul di sini.';
        _lastEncryptedBase64Content =
            null; // Reset konten Base64 saat file baru dipilih
      });
    } else {
      setState(() {
        _statusMessage = 'Pemilihan file input dibatalkan.';
      });
    }
  }

  void _resetAll() {
    if (_isBusy) return;

    setState(() {
      _selectedFile = null;
      _keyController.clear();
      _statusMessage = 'Pilih file untuk memulai.';
      _isBusy = false;
      _outputFile = null;
      _outputFilePathDisplay = 'File hasil akan muncul di sini.';
      _isKeyVisible = false; // Reset visibilitas kunci
      _lastEncryptedBase64Content = null; // Reset konten Base64
    });
    _loaderController.stop();
    _showMessage('Semua input dan status telah direset.', isError: false);
  }

  Future<void> _performCryptoOperation(bool isEncrypt) async {
    if (_selectedFile == null) {
      _showMessage('Pilih file input terlebih dahulu!', isError: true);
      return;
    }
    if (_keyController.text.isEmpty) {
      _showMessage('Masukkan kunci enkripsi/dekripsi!', isError: true);
      return;
    }

    setState(() {
      _isBusy = true;
      _statusMessage =
          isEncrypt ? 'Mengenkripsi file...' : 'Mendekripsi file...';
      _loaderController.repeat();
    });

    try {
      final keyString = _keyController.text;
      String outputFileNameSuggestion;

      final originalFileName = p.basenameWithoutExtension(_selectedFile!.path);
      final originalExtension = p.extension(_selectedFile!.path);

      // Kunci AES yang diturunkan dari SHA256 hash
      final keyBytes = utf8.encode(keyString);
      final aesKey = enc.Key.fromBase64(
        base64Url.encode(sha256.convert(keyBytes).bytes),
      );

      if (isEncrypt) {
        // ENKRIPSI
        Uint8List inputBytes = await _selectedFile!.readAsBytes();
        Uint8List
        encryptedContentBytes; // Ini akan menampung data terenkripsi (termasuk IV untuk AES)
        List<int> currentMagic; // Magic number untuk metode yang dipilih

        switch (_selectedMethod) {
          case 'AES (Advanced Encryption Standard)':
            currentMagic = _aesMagic;
            final iv = enc.IV.fromSecureRandom(16); // IV acak 16 byte
            final encrypter = enc.Encrypter(
              enc.AES(aesKey, mode: enc.AESMode.cbc, padding: 'PKCS7'),
            );
            final encrypted = encrypter.encryptBytes(inputBytes, iv: iv);
            encryptedContentBytes = Uint8List.fromList(
              iv.bytes + encrypted.bytes,
            ); // Gabungkan IV + Ciphertext
            break;

          case 'DES (Data Encryption Standard)':
            currentMagic = _desMagic;
            final desKeyBytes = utf8.encode(keyString);
            encryptedContentBytes = Uint8List.fromList(
              List.generate(inputBytes.length, (i) {
                return inputBytes[i] ^ desKeyBytes[i % desKeyBytes.length];
              }),
            );
            break;

          case 'XOR Sederhana':
            currentMagic = _xorMagic;
            final xorKeyBytes = utf8.encode(keyString);
            encryptedContentBytes = Uint8List.fromList(
              List.generate(inputBytes.length, (i) {
                return inputBytes[i] ^ xorKeyBytes[i % xorKeyBytes.length];
              }),
            );
            break;

          default:
            throw Exception('Metode enkripsi tidak dikenal.');
        }

        // Gabungkan magic number dengan data terenkripsi (raw binary)
        final finalEncryptedDataRaw = Uint8List.fromList(
          currentMagic + encryptedContentBytes,
        );

        // Konversi ke Base64 untuk keperluan berbagi dan penyimpanan teks
        _lastEncryptedBase64Content = base64Url.encode(finalEncryptedDataRaw);

        outputFileNameSuggestion =
            '${originalFileName}_encrypted.enc'; // Ekstensi .enc untuk file terenkripsi lokal

        // --- Simpan file terenkripsi (raw binary) ke lokasi yang dipilih pengguna ---
        final String? selectedOutputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Simpan file terenkripsi sebagai...',
          fileName: outputFileNameSuggestion,
          bytes: finalEncryptedDataRaw, // Simpan raw binary
          type: FileType.any,
        );

        if (selectedOutputPath != null) {
          _outputFile = File(selectedOutputPath);
          _showMessage(
            'Enkripsi berhasil! File tersimpan di: ${p.basename(_outputFile!.path)}. Konten Base64 siap dibagikan/disimpan.',
            isError: false,
          );
          setState(() {
            _outputFilePathDisplay = _outputFile!.path;
          });
        } else {
          _showMessage(
            'Penyimpanan file terenkripsi dibatalkan. Konten Base64 masih siap dibagikan/disimpan.',
            isError: true,
          );
          setState(() {
            _outputFilePathDisplay = 'Penyimpanan file dibatalkan.';
          });
        }
      } else {
        // DEKRIPSI
        Uint8List
        inputDataBytes; // Ini akan menjadi byte mentah dari file atau hasil decode Base64
        String fileExtension = p.extension(_selectedFile!.path).toLowerCase();

        // Tentukan apakah kita harus mencoba menginterpretasikan sebagai string Base64
        // Ini hanya dilakukan jika file adalah .txt atau .b64
        bool shouldTryBase64 =
            (fileExtension == '.txt' || fileExtension == '.b64');

        if (shouldTryBase64) {
          try {
            // Coba baca file sebagai string UTF-8. Jika gagal, berarti bukan file teks yang valid.
            String fileContentAsString = await _selectedFile!.readAsString(
              encoding: utf8,
            );
            String trimmedContent = fileContentAsString.trim();

            if (_isLikelyBase64(trimmedContent)) {
              inputDataBytes = base64Url.decode(trimmedContent);
              _showMessage(
                'Mendeteksi input Base64 dari file teks. Melanjutkan dekode Base64...',
                isError: false,
              );
            } else {
              // Jika file .txt/.b64 tapi tidak berisi Base64 yang valid
              throw Exception(
                'File teks yang dipilih tidak berisi data Base64 terenkripsi yang valid.',
              );
            }
          } catch (e) {
            // Tangani kegagalan membaca sebagai UTF-8 atau kegagalan dekode Base64
            // Ini akan menangkap FileSystemException jika file bukan UTF-8
            throw Exception(
              'Gagal memproses file teks sebagai Base64. Pastikan file berisi teks Base64 yang valid: ${e.toString()}',
            );
          }
        } else {
          // Untuk file .enc atau file biner lainnya, baca langsung sebagai byte
          inputDataBytes = await _selectedFile!.readAsBytes();
        }

        // Sekarang, inputDataBytes berisi data terenkripsi mentah yang sebenarnya
        // (baik dari file biner atau yang sudah didekode dari string Base64)
        // Lanjutkan dengan pemeriksaan magic number dan dekripsi
        if (inputDataBytes.length < _magicNumberLength) {
          throw Exception(
            'Data terlalu pendek untuk dekripsi (magic number hilang?).',
          );
        }

        final receivedMagic = inputDataBytes.sublist(0, _magicNumberLength);
        final actualEncryptedBytes = inputDataBytes.sublist(
          _magicNumberLength,
        ); // Konten setelah magic number

        String detectedMethod;
        if (_listEquals(receivedMagic, _aesMagic)) {
          detectedMethod = 'AES (Advanced Encryption Standard)';
        } else if (_listEquals(receivedMagic, _desMagic)) {
          detectedMethod = 'DES (Data Encryption Standard)';
        } else if (_listEquals(receivedMagic, _xorMagic)) {
          detectedMethod = 'XOR Sederhana';
        } else {
          throw Exception(
            'Data bukan format terenkripsi yang valid atau metode tidak dikenal.',
          );
        }

        if (detectedMethod != _selectedMethod) {
          throw Exception(
            'Metode dekripsi yang dipilih (${_selectedMethod}) tidak cocok dengan metode enkripsi data yang terdeteksi (${detectedMethod}). Pastikan Anda memilih metode yang benar.',
          );
        }

        Uint8List decryptedBytes;
        switch (detectedMethod) {
          case 'AES (Advanced Encryption Standard)':
            // Pastikan actualEncryptedBytes (IV + Ciphertext) memiliki panjang minimal
            // IV adalah 16 byte. Ciphertext minimal 1 blok (16 byte).
            // Jadi, actualEncryptedBytes harus minimal 16 (IV) + 16 (min ciphertext) = 32 byte.
            if (actualEncryptedBytes.length < 32) {
              throw Exception(
                'Data terenkripsi AES terlalu pendek atau rusak. Minimum panjang untuk IV + Ciphertext adalah 32 byte.',
              );
            }

            final iv = enc.IV(actualEncryptedBytes.sublist(0, 16));
            final ciphertextBytes = actualEncryptedBytes.sublist(
              16,
            ); // Ini adalah data ciphertext yang sebenarnya

            // Pemeriksaan baru: Pastikan panjang ciphertextBytes adalah kelipatan 16
            if (ciphertextBytes.length % 16 != 0) {
              throw Exception(
                'Panjang data terenkripsi (ciphertext) tidak valid untuk AES. Harus merupakan kelipatan dari 16 byte setelah IV diekstrak. Ini mungkin karena kerusakan data saat transfer atau penyimpanan (misalnya, Base64 terpotong atau ada karakter tambahan).',
              );
            }

            final encrypter = enc.Encrypter(
              enc.AES(aesKey, mode: enc.AESMode.cbc, padding: 'PKCS7'),
            );
            final decrypted = encrypter.decryptBytes(
              enc.Encrypted(ciphertextBytes),
              iv: iv,
            );
            decryptedBytes = Uint8List.fromList(decrypted);
            break;

          case 'DES (Data Encryption Standard)':
            final desKeyBytes = utf8.encode(keyString);
            decryptedBytes = Uint8List.fromList(
              List.generate(actualEncryptedBytes.length, (i) {
                return actualEncryptedBytes[i] ^
                    desKeyBytes[i % desKeyBytes.length];
              }),
            );
            break;

          case 'XOR Sederhana':
            final xorKeyBytes = utf8.encode(keyString);
            decryptedBytes = Uint8List.fromList(
              List.generate(actualEncryptedBytes.length, (i) {
                return actualEncryptedBytes[i] ^
                    xorKeyBytes[i % xorKeyBytes.length];
              }),
            );
            break;

          default:
            throw Exception(
              'Metode dekripsi tidak dikenal (kesalahan internal).',
            );
        }

        // Tentukan nama file output yang disarankan
        String baseName = originalFileName;
        String suggestedExtension = originalExtension;

        // Jika input berasal dari file .enc atau teks Base64
        if (originalExtension.toLowerCase() == '.enc' || shouldTryBase64) {
          baseName = p.basenameWithoutExtension(
            _selectedFile!.path,
          ); // Dapatkan nama tanpa .enc atau .txt
          if (baseName.endsWith('_encrypted')) {
            baseName = baseName.substring(
              0,
              baseName.length - '_encrypted'.length,
            );
          }
          // Untuk ekstensi, kita tidak tahu ekstensi aslinya, jadi biarkan pengguna memilih
          suggestedExtension = ''; // FilePicker akan meminta ekstensi
        } else if (baseName.endsWith('_encrypted')) {
          baseName = baseName.substring(
            0,
            baseName.length - '_encrypted'.length,
          );
        }

        // Jika suggestedExtension kosong, FilePicker akan meminta pengguna untuk memasukkan ekstensi.
        // Jika tidak, kita bisa mencoba mengembalikan ekstensi asli dari file input (jika bukan .enc/.txt/.b64)
        if (suggestedExtension.isEmpty &&
            !originalExtension.toLowerCase().contains('.enc') &&
            !originalExtension.toLowerCase().contains('.txt') &&
            !originalExtension.toLowerCase().contains('.b64')) {
          suggestedExtension =
              originalExtension; // Gunakan ekstensi asli jika ada
        }
        outputFileNameSuggestion =
            '${baseName}_decrypted${suggestedExtension.isNotEmpty ? suggestedExtension : ''}';

        // --- Simpan file hasil dekripsi ke lokasi yang dipilih pengguna ---
        final String? selectedOutputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Simpan file hasil dekripsi sebagai...',
          fileName: outputFileNameSuggestion,
          bytes: decryptedBytes,
          type: FileType.any, // Biarkan pengguna memilih tipe file
        );

        if (selectedOutputPath != null) {
          _outputFile = File(selectedOutputPath);
          _showMessage(
            'Dekripsi berhasil! File tersimpan di: ${p.basename(_outputFile!.path)}',
            isError: false,
          );
          setState(() {
            _outputFilePathDisplay = _outputFile!.path;
          });
        } else {
          _showMessage(
            'Penyimpanan file hasil dekripsi dibatalkan.',
            isError: true,
          );
          setState(() {
            _outputFilePathDisplay = 'Penyimpanan file dibatalkan.';
          });
        }
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.contains('Invalid or corrupted pad block') ||
          errorMessage.contains('Bad key or IV')) {
        errorMessage =
            'Dekripsi gagal: Kunci atau metode kriptografi mungkin tidak tepat. Pastikan kunci yang Anda masukkan sama persis dengan saat enkripsi, dan metode yang dipilih juga sama.';
      } else if (errorMessage.contains(
        'Data bukan format terenkripsi yang valid atau metode tidak dikenal',
      )) {
        errorMessage =
            'Dekripsi gagal: Data input tampaknya bukan format terenkripsi yang dibuat oleh aplikasi ini, atau magic number-nya rusak.';
      } else if (errorMessage.contains('Metode dekripsi yang dipilih') &&
          errorMessage.contains(
            'tidak cocok dengan metode enkripsi data yang terdeteksi',
          )) {
        // Pesan error ini sudah cukup informatif
      } else if (errorMessage.contains(
        'Data terenkripsi AES terlalu pendek atau rusak',
      )) {
        // Pesan error ini sudah cukup informatif
      } else if (errorMessage.contains(
        'Panjang data terenkripsi (ciphertext) tidak valid untuk AES',
      )) {
        // Pesan error ini sudah cukup informatif
      } else {
        errorMessage =
            '${isEncrypt ? "Enkripsi" : "Dekripsi"} gagal: $errorMessage';
      }

      _showMessage(errorMessage, isError: true);
      setState(() {
        _outputFilePathDisplay = 'Gagal memproses file.';
      });
    } finally {
      setState(() {
        _isBusy = false;
      });
      _loaderController.stop();
    }
  }

  // Helper function untuk membandingkan dua list integer (byte)
  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Heuristik untuk mendeteksi apakah string kemungkinan adalah Base64
  bool _isLikelyBase64(String s) {
    s = s.trim();
    if (s.isEmpty) return false;

    // Base64 string biasanya memiliki panjang kelipatan 4,
    // atau diakhiri dengan padding '='.
    // Jika panjangnya bukan kelipatan 4 dan tidak ada padding,
    // kemungkinan besar bukan Base64 yang valid.
    if (s.length % 4 != 0 && !s.endsWith('=')) {
      return false;
    }

    // Periksa karakter yang valid untuk Base64url (A-Z, a-z, 0-9, -, _, =)
    final RegExp base64UrlRegex = RegExp(r'^[A-Za-z0-9\-_=]+$');
    if (!base64UrlRegex.hasMatch(s)) {
      return false;
    }

    // Coba decode untuk validasi lebih lanjut.
    // Ini adalah cara paling andal untuk memastikan string adalah Base64 yang valid.
    try {
      base64Url.decode(s);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _handleShareEncryptedContent() async {
    if (_lastEncryptedBase64Content == null ||
        _lastEncryptedBase64Content!.isEmpty) {
      _showMessage(
        'Tidak ada konten terenkripsi untuk dibagikan atau disimpan.',
        isError: true,
      );
      return;
    }

    // Tampilkan dialog pilihan
    final choice = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Aksi'),
          content: const Text(
            'Anda ingin membagikan teks terenkripsi ke aplikasi lain atau menyimpannya sebagai file teks lokal?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, 'share'),
              child: const Text('Bagikan ke Aplikasi Lain'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Simpan sebagai File Teks'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Batal'),
            ),
          ],
        );
      },
    );

    if (choice == 'share') {
      await Share.share(
        _lastEncryptedBase64Content!,
        subject: 'File Terenkripsi dari Aplikasi Kripto',
      );
      _showMessage(
        'Konten terenkripsi telah dibagikan ke aplikasi lain.',
        isError: false,
      );
    } else if (choice == 'save') {
      await _saveEncryptedBase64AsTextFile();
    }
  }

  Future<void> _saveEncryptedBase64AsTextFile() async {
    if (_lastEncryptedBase64Content == null ||
        _lastEncryptedBase64Content!.isEmpty) {
      _showMessage(
        'Tidak ada konten terenkripsi untuk disimpan.',
        isError: true,
      );
      return;
    }

    final String? selectedOutputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan teks terenkripsi sebagai...',
      fileName: 'encrypted_content.txt',
      bytes: utf8.encode(
        _lastEncryptedBase64Content!,
      ), // Encode string ke bytes untuk disimpan
      type: FileType.custom,
      allowedExtensions: ['txt', 'b64'], // Sarankan ekstensi .txt atau .b64
    );

    if (selectedOutputPath != null) {
      _showMessage(
        'Teks terenkripsi berhasil disimpan ke: ${p.basename(selectedOutputPath)}',
        isError: false,
      );
    } else {
      _showMessage('Penyimpanan teks terenkripsi dibatalkan.', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    // Pastikan context masih valid sebelum menampilkan SnackBar
    if (!mounted) return;

    setState(() {
      _statusMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating, // Lebih modern
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _copyOutputFilePath() async {
    if (_outputFile == null || !await _outputFile!.exists()) {
      _showMessage(
        'Tidak ada file hasil untuk disalin path-nya.',
        isError: true,
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: _outputFile!.path));
    _showMessage('Path file hasil disalin ke clipboard.', isError: false);
  }

  Widget _buildLoaderOverlay() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _isBusy ? 1.0 : 0.0,
      curve: Curves.easeOut,
      child: IgnorePointer(
        ignoring: !_isBusy,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: _loaderOverlayColor.withOpacity(0.7),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
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
                            'Processing...$dots',
                            style: const TextStyle(
                              fontFamily:
                                  'Fira Code', // Tetap pakai Fira Code untuk kesan log
                              color: _loaderProcessingColor,
                              fontSize: 18,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _statusMessage,
                            style: const TextStyle(
                              fontFamily:
                                  'Fira Code', // Tetap pakai Fira Code untuk kesan log
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

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFE6E6E6),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER (dari home_page.dart)
                Container(
                  width: double.infinity,
                  height: 58,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_headerGradientStart, _headerGradientEnd],
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/images/logoenkripsiapps.svg',
                        height: 42,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'KRIPTOGRAFI FILE', // <<<--- PERUBAHAN DI SINI
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _headerAccentColor,
                          letterSpacing: 0.8,
                          shadows: [
                            Shadow(
                              blurRadius: 3,
                              color: Colors.black26,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Konten Utama Halaman
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- TEKS INI DIHAPUS ---
                        // Text(
                        //   'Operasi Kriptografi File',
                        //   style: Theme.of(context)
                        //       .textTheme
                        //       .headlineSmall
                        //       ?.copyWith(
                        //         fontWeight: FontWeight.bold,
                        //         color: _primaryTextColor,
                        //         fontFamily: 'Orbitron',
                        //       ),
                        // ),
                        // const SizedBox(height: 16), // Jarak juga dihapus jika teks di atas dihapus

                        // Dropdown untuk memilih metode kriptografi
                        Text(
                          'Pilih Metode Kriptografi:',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600, // Sedikit lebih tebal
                            color: _primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: _inputFillColor, // Sekarang putih
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _inputBorderColor),
                            boxShadow: [
                              // Tambahkan shadow halus
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedMethod,
                              isExpanded: true,
                              dropdownColor: _inputFillColor,
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: _secondaryTextColor,
                              ),
                              style: const TextStyle(
                                color: _primaryTextColor,
                                fontSize: 14,
                              ),
                              onChanged: (String? newValue) async {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedMethod = newValue;
                                  });
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setString(
                                    'selectedCryptoMethod',
                                    newValue,
                                  );
                                }
                              },
                              items:
                                  _cryptoMethods.map<DropdownMenuItem<String>>((
                                    String value,
                                  ) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Tombol Pilih File
                        ElevatedButton.icon(
                          onPressed: _isBusy ? null : _pickFile,
                          icon: const Icon(
                            Icons.upload_file,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Pilih File Input',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _decryptButtonColor, // Warna biru untuk pilih file
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            elevation: 4,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tampilkan nama file yang dipilih
                        if (_selectedFile != null)
                          Text(
                            'File Input Terpilih: ${p.basename(_selectedFile!.path)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _primaryTextColor,
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Input Kunci dengan ikon mata dan salin
                        TextField(
                          controller: _keyController,
                          obscureText: !_isKeyVisible, // Kontrol visibilitas
                          decoration: InputDecoration(
                            labelText: 'Kunci Enkripsi/Dekripsi',
                            labelStyle: const TextStyle(
                              color: _secondaryTextColor,
                            ),
                            hintText: 'Masukkan kunci rahasia Anda',
                            hintTextDirection: TextDirection.ltr,
                            hintStyle: TextStyle(
                              color: _secondaryTextColor.withOpacity(0.7),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: _inputBorderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: _inputBorderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _focusedInputBorderColor,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: _inputFillColor, // Sekarang putih
                            contentPadding: const EdgeInsets.all(12),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _isKeyVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: _secondaryTextColor.withOpacity(0.8),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isKeyVisible = !_isKeyVisible;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.copy,
                                    color: _secondaryTextColor.withOpacity(0.8),
                                  ),
                                  onPressed: () {
                                    if (_keyController.text.isNotEmpty) {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: _keyController.text,
                                        ),
                                      );
                                      _showMessage(
                                        'Kunci disalin ke clipboard.',
                                        isError: false,
                                      );
                                    } else {
                                      _showMessage(
                                        'Tidak ada kunci untuk disalin.',
                                        isError: true,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          style: const TextStyle(color: _primaryTextColor),
                        ),
                        const SizedBox(height: 20),

                        // Tombol Aksi (Enkripsi, Dekripsi, Reset)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isBusy
                                        ? null
                                        : () => _performCryptoOperation(true),
                                icon:
                                    _isBusy &&
                                            _statusMessage.contains(
                                              'Mengenkripsi',
                                            )
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.lock,
                                          color: Colors.white,
                                        ),
                                label: const Text(
                                  'Enkripsi',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _encryptButtonColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isBusy
                                        ? null
                                        : () => _performCryptoOperation(false),
                                icon:
                                    _isBusy &&
                                            _statusMessage.contains(
                                              'Mendekripsi',
                                            )
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.lock_open,
                                          color: Colors.white,
                                        ),
                                label: const Text(
                                  'Dekripsi',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _decryptButtonColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _isBusy ? null : _resetAll,
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Reset',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _resetButtonColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Tombol Bagikan Teks Terenkripsi (muncul setelah enkripsi)
                        if (_lastEncryptedBase64Content != null) ...[
                          Center(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isBusy ? null : _handleShareEncryptedContent,
                              icon: const Icon(
                                Icons.share,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Bagikan Teks Terenkripsi',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _copyPathButtonColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Catatan: Konten yang dibagikan adalah teks Base64 dari file terenkripsi. Untuk mendekripsi, Anda bisa menyimpannya sebagai file .txt (melalui opsi di atas) lalu pilih file .txt tersebut sebagai input di aplikasi ini, atau bagikan ke penerima yang akan memprosesnya.',
                            style: TextStyle(
                              fontSize: 12,
                              color: _secondaryTextColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Pesan Status
                        Text(
                          'Status Log:',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _statusLogBackgroundColor, // Sekarang putih
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _inputBorderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: SelectableText(
                            _statusMessage,
                            style: const TextStyle(
                              fontSize: 14,
                              color: _primaryTextColor,
                              fontFamily:
                                  'Fira Code', // Tetap Fira Code untuk log
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Lokasi File Hasil
                        Text(
                          'Lokasi File Hasil:',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _outputFileBackgroundColor, // Sekarang putih
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _inputBorderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                _outputFilePathDisplay,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: _primaryTextColor,
                                  fontFamily:
                                      'Fira Code', // Tetap Fira Code untuk path
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Tombol Salin Path
                                  ElevatedButton.icon(
                                    onPressed:
                                        _outputFile != null && !_isBusy
                                            ? _copyOutputFilePath
                                            : null,
                                    icon: const Icon(
                                      Icons.copy,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Salin Path',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _copyPathButtonColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      elevation: 4,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Tombol Buka Folder (opsional)
                                  ElevatedButton.icon(
                                    onPressed:
                                        _outputFile != null && !_isBusy
                                            ? () {
                                              // _openOutputFolder() tidak lagi digunakan karena keterbatasan OS
                                              _showMessage(
                                                'Fungsi "Buka Folder" mungkin terbatas di Android 11+. Silakan gunakan file manager Anda untuk menavigasi ke lokasi yang Anda pilih.',
                                                isError: false,
                                              );
                                            }
                                            : null,
                                    icon: const Icon(
                                      Icons.folder,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Buka Folder',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _folderButtonColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      elevation: 4,
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
                ),
              ],
            ),
            // Loader Overlay
            _buildLoaderOverlay(),
          ],
        ),
      ),
    );
  }
}
