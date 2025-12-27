// lib/profile_page.dart

// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _biodata;
  late Database _database;
  bool _isEditing = false;
  File? _profileImageFile;
  File? _coverImageFile;

  late TabController _tabController;

  final _namaController = TextEditingController();
  final _tanggalController = TextEditingController();
  String _genderValue = 'Laki-laki';
  final _teleponController = TextEditingController();
  final _alamatController = TextEditingController();
  final _pekerjaanController = TextEditingController();
  final _tentangController = TextEditingController();

  bool _vibrateOnNotification = false;
  bool _emailNotifications = true;
  bool _generalNotifications = true;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _initDatabase().then((_) => _loadBiodata());
    _loadNotificationSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _namaController.dispose();
    _tanggalController.dispose();
    _teleponController.dispose();
    _alamatController.dispose();
    _pekerjaanController.dispose();
    _tentangController.dispose();
    if (_database.isOpen) {
      _database.close();
    }
    super.dispose();
  }

  Future<void> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? "guest";
    final safeEmail = userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final path = p.join(dbPath, 'biodata_$safeEmail.db');

    _database = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE biodata(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nama TEXT,
            tanggalLahir TEXT,
            gender TEXT,
            telepon TEXT,
            alamat TEXT,
            pekerjaan TEXT,
            tentang TEXT,
            foto TEXT,
            coverFoto TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          var tableInfo = await db.rawQuery("PRAGMA table_info(biodata)");
          bool coverFotoExists = false;
          for (var column in tableInfo) {
            if (column['name'] == 'coverFoto') {
              coverFotoExists = true;
              break;
            }
          }
          if (!coverFotoExists) {
            await db.execute('ALTER TABLE biodata ADD COLUMN coverFoto TEXT;');
          }
        }
      },
    );
  }

  Future<void> _loadBiodata() async {
    final result = await _database.query(
      'biodata',
      orderBy: 'id DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      _biodata = result.first;
      _namaController.text = _biodata!['nama'] ?? '';
      _tanggalController.text = _biodata!['tanggalLahir'] ?? '';
      _genderValue = _biodata!['gender'] ?? 'Laki-laki';
      _teleponController.text = _biodata!['telepon'] ?? '';
      _alamatController.text = _biodata!['alamat'] ?? '';
      _pekerjaanController.text = _biodata!['pekerjaan'] ?? '';
      _tentangController.text = _biodata!['tentang'] ?? '';

      final fotoPath = _biodata!['foto'] ?? '';
      if (fotoPath.isNotEmpty) {
        final f = File(fotoPath);
        if (await f.exists()) {
          _profileImageFile = f;
        } else {
          _profileImageFile = null;
          _biodata!['foto'] = '';
        }
      } else {
        _profileImageFile = null;
      }

      final coverFotoPath = _biodata!['coverFoto'] ?? '';
      if (coverFotoPath.isNotEmpty) {
        final c = File(coverFotoPath);
        final exists = await c.exists();
        if (exists) {
          _coverImageFile = c;
        } else {
          _coverImageFile = null;
          _biodata!['coverFoto'] = '';
        }
      } else {
        _coverImageFile = null;
      }
    } else {
      _biodata = null;
      _namaController.clear();
      _tanggalController.clear();
      _genderValue = 'Laki-laki';
      _teleponController.clear();
      _alamatController.clear();
      _pekerjaanController.clear();
      _tentangController.clear();
      _profileImageFile = null;
      _coverImageFile = null;
    }
    setState(() {});
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vibrateOnNotification = prefs.getBool('vibrateOnNotification') ?? false;
      _emailNotifications = prefs.getBool('emailNotifications') ?? true;
      _generalNotifications = prefs.getBool('generalNotifications') ?? true;
    });
  }

  Future<void> _saveNotificationSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveBiodata() async {
    final Map<String, dynamic> data = {
      'nama': _namaController.text,
      'tanggalLahir': _tanggalController.text,
      'gender': _genderValue,
      'telepon': _teleponController.text,
      'alamat': _alamatController.text,
      'pekerjaan': _pekerjaanController.text,
      'tentang': _tentangController.text,
      'foto': _profileImageFile?.path ?? '',
      'coverFoto': _coverImageFile?.path ?? '',
    };

    if (_biodata == null || _biodata!['id'] == null) {
      final id = await _database.insert('biodata', data);
      data['id'] = id;
    } else {
      final id = _biodata!['id'] as int;
      await _database.update('biodata', data, where: 'id = ?', whereArgs: [id]);
      data['id'] = id;
    }

    setState(() {
      _biodata = data;
      _isEditing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(super.context).showSnackBar(
        const SnackBar(content: Text("✅ Biodata berhasil disimpan")),
      );
    }
  }

  Future<void> _showLogoutConfirmation() async {
    showDialog(
      context: super.context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                  size: 45,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Keluar dari akun?",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF041413),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Apakah kamu yakin ingin logout dari aplikasi ini?",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black87, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "Tidak",
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _logout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("Iya"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();

      if (super.context.mounted) {
        ScaffoldMessenger.of(
          super.context,
        ).showSnackBar(const SnackBar(content: Text("✅ Berhasil logout")));
        Navigator.pushNamedAndRemoveUntil(
          super.context,
          '/login',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          super.context,
        ).showSnackBar(SnackBar(content: Text("Gagal logout: $e")));
      }
    }
  }

  Future<void> _showDeleteAccountConfirmation() async {
    showDialog(
      context: super.context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_rounded, color: Colors.red, size: 45),
                const SizedBox(height: 10),
                const Text(
                  "Hapus Akun Anda?",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF041413),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Semua data Anda akan dihapus permanen. Tindakan ini tidak dapat dibatalkan. Apakah Anda yakin?",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black87, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey, width: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "Batal",
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _deleteAccount();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("Hapus"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak ada pengguna yang login.")),
        );
      }
      return;
    }

    try {
      if (_database.isOpen) {
        await _database.close();
      }

      final dbPath = await getDatabasesPath();
      final userEmail = user.email ?? "guest";
      final safeEmail = userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      final dbFile = File(p.join(dbPath, 'biodata_$safeEmail.db'));

      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      await user.delete();

      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Akun berhasil dihapus")),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Gagal menghapus akun.";
      if (e.code == 'requires-recent-login') {
        errorMessage =
            "Untuk menghapus akun, Anda perlu login kembali. Silakan logout, lalu login lagi, dan coba hapus akun.";
      } else {
        errorMessage = "Gagal menghapus akun: ${e.message}";
      }
      if (mounted) {
        ScaffoldMessenger.of(
          super.context,
        ).showSnackBar(SnackBar(content: Text("❌ $errorMessage")));
      }
      _initDatabase();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(super.context).showSnackBar(
          SnackBar(
            content: Text("❌ Terjadi kesalahan saat menghapus akun: $e"),
          ),
        );
      }
      _initDatabase();
    }
  }

  Future<File?> _pickAndSaveImage(
    ImageSource source, {
    String prefix = '',
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(picked.path);
      final newPath = '${appDir.path}/$prefix$fileName';
      try {
        final savedFile = await File(picked.path).copy(newPath);
        return savedFile;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            super.context,
          ).showSnackBar(SnackBar(content: Text("Gagal menyimpan gambar: $e")));
        }
        return null;
      }
    }
    return null;
  }

  Future<File?> _pickAndSaveImageFromFileManager({String prefix = ''}) async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (res != null && res.files.isNotEmpty) {
        final path = res.files.single.path;
        if (path != null) {
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = p.basename(path);
          final newPath = '${appDir.path}/$prefix$fileName';
          try {
            final savedFile = await File(path).copy(newPath);
            return savedFile;
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(super.context).showSnackBar(
                SnackBar(
                  content: Text("Gagal menyimpan gambar dari file manager: $e"),
                ),
              );
            }
            return null;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(super.context).showSnackBar(
          SnackBar(content: Text("Gagal membuka file manager: $e")),
        );
      }
    }
    return null;
  }

  void _showProfileImagePickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Ambil dari Kamera'),
                onTap: () async {
                  Navigator.pop(bc);
                  final picked = await _pickAndSaveImage(
                    ImageSource.camera,
                    prefix: 'profile_',
                  );
                  if (picked != null)
                    setState(() => _profileImageFile = picked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pilih dari Galeri'),
                onTap: () async {
                  Navigator.pop(bc);
                  final picked = await _pickAndSaveImage(
                    ImageSource.gallery,
                    prefix: 'profile_',
                  );
                  if (picked != null)
                    setState(() => _profileImageFile = picked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Pilih dari File Manager'),
                onTap: () async {
                  Navigator.pop(bc);
                  final picked = await _pickAndSaveImageFromFileManager(
                    prefix: 'profile_',
                  );
                  if (picked != null)
                    setState(() => _profileImageFile = picked);
                },
              ),
              if (_profileImageFile != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Hapus Foto Profil',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(bc);
                    _deleteProfileImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteProfileImage() async {
    try {
      if (_profileImageFile != null && await _profileImageFile!.exists()) {
        try {
          await _profileImageFile!.delete();
        } catch (_) {}
      }

      if (_biodata != null && _biodata!['id'] != null) {
        final id = _biodata!['id'] as int;
        await _database.update(
          'biodata',
          {'foto': ''},
          where: 'id = ?',
          whereArgs: [id],
        );
        _biodata!['foto'] = '';
      }

      setState(() {
        _profileImageFile = null;
        if (_biodata != null) _biodata!['foto'] = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(
          super.context,
        ).showSnackBar(const SnackBar(content: Text("✅ Foto profil dihapus")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(super.context).showSnackBar(
          SnackBar(content: Text("Gagal menghapus foto profil: $e")),
        );
      }
    }
  }

  void _showCoverImagePickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Ambil dari Kamera'),
                onTap: () async {
                  Navigator.pop(bc);
                  final picked = await _pickAndSaveImage(
                    ImageSource.camera,
                    prefix: 'cover_',
                  );
                  if (picked != null) setState(() => _coverImageFile = picked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pilih dari Galeri'),
                onTap: () async {
                  Navigator.pop(bc);
                  final picked = await _pickAndSaveImage(
                    ImageSource.gallery,
                    prefix: 'cover_',
                  );
                  if (picked != null) setState(() => _coverImageFile = picked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Pilih dari File Manager'),
                onTap: () async {
                  Navigator.pop(bc);
                  final picked = await _pickAndSaveImageFromFileManager(
                    prefix: 'cover_',
                  );
                  if (picked != null) setState(() => _coverImageFile = picked);
                },
              ),
              if (_coverImageFile != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Hapus Foto Sampul',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(bc);
                    _deleteCoverImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteCoverImage() async {
    try {
      if (_coverImageFile != null && await _coverImageFile!.exists()) {
        try {
          await _coverImageFile!.delete();
        } catch (_) {}
      }

      if (_biodata != null && _biodata!['id'] != null) {
        final id = _biodata!['id'] as int;
        await _database.update(
          'biodata',
          {'coverFoto': ''},
          where: 'id = ?',
          whereArgs: [id],
        );
        _biodata!['coverFoto'] = '';
      }

      setState(() {
        _coverImageFile = null;
        if (_biodata != null) _biodata!['coverFoto'] = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(
          super.context,
        ).showSnackBar(const SnackBar(content: Text("✅ Foto sampul dihapus")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(super.context).showSnackBar(
          SnackBar(content: Text("Gagal menghapus foto sampul: $e")),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    DateTime initialDate = DateTime.now();
    if (_tanggalController.text.isNotEmpty) {
      try {
        final parts = _tanggalController.text.split('/');
        if (parts.length == 3) {
          initialDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (_) {
        initialDate = DateTime.now();
      }
    }
    final date = await showDatePicker(
      context: super.context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF093B2B),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      _tanggalController.text =
          "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    bool enabled = true,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        enabled: enabled,
        readOnly: onTap != null || !enabled,
        onTap: onTap,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: TextStyle(color: enabled ? Colors.black87 : Colors.grey[700]),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: enabled ? Colors.black87 : Colors.grey[500],
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF093B2B)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF093B2B), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnly(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(color: Colors.black87, fontSize: 15),
          ),
          const Divider(color: Colors.black12, thickness: 0.6),
        ],
      ),
    );
  }

  Widget _buildDropdownGender() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: _genderValue,
        onChanged:
            _isEditing ? (val) => setState(() => _genderValue = val!) : null,
        items: const [
          DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
          DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
        ],
        decoration: InputDecoration(
          labelText: "Jenis Kelamin",
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  // Helper function for consistent white card styling
  Widget _buildWhiteCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 10),
      child: child,
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color color = const Color(0xFF041413),
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                trailing ??
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: Colors.grey,
                    ),
              ],
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

    // --- Konstanta Ukuran dan Jarak ---
    const double coverPhotoHeight = 180; // Tinggi foto sampul
    const double profilePicRadius = 60; // Radius foto profil (diameter 120)
    const double nameEmailCardHeight = 90; // Tinggi card nama/email
    const double tabBarHeight = 70; // Tinggi TabBar card
    const double horizontalMargin =
        20; // Margin horizontal untuk card dan TabBar
    const double verticalSpacingBetweenElements =
        12; // Jarak vertikal antar elemen

    // --- Perhitungan Posisi Vertikal dalam Stack ---
    // Posisi top untuk Foto Sampul (paling atas)
    const double coverPhotoTop = 0;

    // Posisi top untuk Foto Profil
    // Foto profil akan berada di tengah secara horizontal, dan bagian atasnya sedikit di atas batas bawah cover
    // sehingga bagian bawahnya menonjol keluar dari cover.
    // Disesuaikan agar pusat foto profil berada di sekitar batas bawah cover.
    final double profilePicTop = coverPhotoHeight - profilePicRadius;

    // Posisi top untuk Card Nama/Email
    // Dimulai dari batas bawah foto profil, ditambah jarak vertikal
    final double nameEmailCardTop =
        profilePicTop + (2 * profilePicRadius) + verticalSpacingBetweenElements;

    // Posisi top untuk TabBar Card
    // Dimulai dari batas bawah card nama/email, ditambah jarak vertikal
    final double tabBarCardTop =
        nameEmailCardTop + nameEmailCardHeight + verticalSpacingBetweenElements;

    // Tinggi keseluruhan Stack, agar semua elemen terlihat tanpa terpotong
    final double calculatedStackHeight = tabBarCardTop + tabBarHeight;

    return Scaffold(
      backgroundColor: const Color(0xFFE6E6E6),
      body: SafeArea(
        child: Column(
          children: [
            // ✅ HEADER (sesuai permintaan user)
            Container(
              width: double.infinity,
              height: 58, // Tinggi header disesuaikan
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
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .center, // Pusatkan konten secara vertikal
                children: [
                  SvgPicture.asset(
                    'assets/images/logoenkripsiapps.svg', // Pastikan path ini benar
                    height: 42,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'PROFIL',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF11E482),
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

            // Bagian Profil Utama: Cover, Foto Profil, Card Nama/Email, TabBar
            // Menggunakan Stack untuk mengelola posisi vertikal secara presisi
            SizedBox(
              height:
                  calculatedStackHeight, // Memberi tinggi eksplisit pada Stack
              width: double.infinity, // Stack mengambil lebar penuh
              child: Stack(
                clipBehavior:
                    Clip.none, // Memungkinkan children meluap di luar batas stack jika diperlukan (misal: shadow)
                children: [
                  // 1. FOTO SAMPUL
                  Positioned(
                    top: coverPhotoTop,
                    left: 0,
                    right: 0,
                    height: coverPhotoHeight,
                    child: GestureDetector(
                      onTap:
                          _isEditing
                              ? () => _showCoverImagePickerOptions(context)
                              : null,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300], // Warna placeholder
                          image:
                              _coverImageFile != null
                                  ? DecorationImage(
                                    image: FileImage(_coverImageFile!),
                                    fit: BoxFit.cover,
                                  )
                                  : null,
                        ),
                        child:
                            _isEditing
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _coverImageFile == null
                                            ? Icons.add_a_photo
                                            : Icons.edit,
                                        size: 40,
                                        color: Colors.grey[600],
                                      ),
                                      Text(
                                        _coverImageFile == null
                                            ? "Tambah Foto Sampul"
                                            : "Ubah Foto Sampul",
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : null,
                      ),
                    ),
                  ),

                  // 2. FOTO PROFIL
                  Positioned(
                    top: profilePicTop, // Posisi top yang sudah dihitung
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap:
                            _isEditing
                                ? () => _showProfileImagePickerOptions(context)
                                : null,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: profilePicRadius,
                              backgroundColor:
                                  Colors
                                      .white, // Latar belakang putih untuk foto profil
                              backgroundImage:
                                  _profileImageFile != null
                                      ? FileImage(_profileImageFile!)
                                      : null,
                              child:
                                  _profileImageFile == null
                                      ? Icon(
                                        Icons.person,
                                        size: profilePicRadius * 0.8,
                                        color: Colors.grey,
                                      )
                                      : null,
                            ),
                            if (_isEditing)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black54.withOpacity(0.5),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Card untuk Nama Lengkap dan Email
                  Positioned(
                    top: nameEmailCardTop, // Posisi top yang sudah dihitung
                    left: horizontalMargin,
                    right: horizontalMargin,
                    height: nameEmailCardHeight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _namaController.text.isNotEmpty
                                ? _namaController.text
                                : 'Nama Pengguna',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF041413),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            FirebaseAuth.instance.currentUser?.email ??
                                'email@example.com',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. TabBar untuk Navigasi (Profil, Akun, Notifikasi)
                  Positioned(
                    top: tabBarCardTop, // Posisi top yang sudah dihitung
                    left: horizontalMargin,
                    right: horizontalMargin,
                    height: tabBarHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF093B2B),
                        unselectedLabelColor: Colors.grey,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFFE0F2F1),
                        ),
                        tabs: const [
                          Tab(text: 'Profil', icon: Icon(Icons.person_outline)),
                          Tab(
                            text: 'Akun',
                            icon: Icon(Icons.settings_outlined),
                          ),
                          Tab(
                            text: 'Notifikasi',
                            icon: Icon(Icons.notifications_none),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // TabBarView untuk Konten Setiap Tab
            Expanded(
              // Memastikan TabBarView mengisi sisa ruang yang tersedia
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Konten Tab Profil
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ), // Tambah padding vertikal
                    child: _buildWhiteCard(
                      child: _buildProfileDetailsContent(),
                    ),
                  ),
                  // Konten Tab Akun
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ), // Tambah padding vertikal
                    child: _buildWhiteCard(
                      child: _buildAccountSettingsContent(),
                    ),
                  ),
                  // Konten Tab Notifikasi
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ), // Tambah padding vertikal
                    child: _buildWhiteCard(
                      child: _buildNotificationSettingsContent(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget untuk Konten Detail Profil ---
  Widget _buildProfileDetailsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Detail Profil",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF041413),
              ),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  _isEditing = !_isEditing;
                  if (!_isEditing) {
                    _loadBiodata();
                  }
                });
              },
              child: Row(
                children: [
                  Text(
                    _isEditing ? "Batal" : "Edit",
                    style: TextStyle(
                      color: _isEditing ? Colors.redAccent : Colors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isEditing ? Icons.cancel : Icons.edit,
                    color: _isEditing ? Colors.redAccent : Colors.teal,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 20, thickness: 1, color: Colors.black12),

        if (!_isEditing) ...[
          _buildReadOnly("Pekerjaan", _pekerjaanController.text),
          _buildReadOnly("Tentang Saya", _tentangController.text),
          _buildReadOnly("Tanggal Lahir", _tanggalController.text),
          _buildReadOnly("Jenis Kelamin", _genderValue),
          _buildReadOnly("Nomor Telepon", _teleponController.text),
          _buildReadOnly("Alamat Lengkap", _alamatController.text),
        ] else ...[
          _buildTextField("Nama Lengkap", _namaController, enabled: true),
          _buildTextField(
            "Tanggal Lahir",
            _tanggalController,
            enabled: true,
            onTap: _pickDate,
          ),
          _buildDropdownGender(),
          _buildTextField(
            "Nomor Telepon",
            _teleponController,
            enabled: true,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          _buildTextField("Alamat Lengkap", _alamatController, enabled: true),
          _buildTextField(
            "Pekerjaan (Opsional)",
            _pekerjaanController,
            enabled: true,
          ),
          _buildTextField(
            "Tentang Saya (Opsional)",
            _tentangController,
            enabled: true,
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 180,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _saveBiodata,
                icon: const Icon(Icons.save, size: 20),
                label: const Text(
                  "Simpan",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF093B2B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(
          height: 20,
        ), // Tambahan ruang di bagian bawah konten card
      ],
    );
  }

  // --- Widget untuk Konten Pengaturan Akun ---
  Widget _buildAccountSettingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Pengaturan Akun",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF041413),
          ),
        ),
        const Divider(height: 20, thickness: 1, color: Colors.black12),
        _buildSettingTile(
          icon: Icons.lock_outline,
          title: "Ubah Kata Sandi",
          subtitle: "Perbarui kata sandi akun Anda",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Fitur ubah kata sandi akan datang!"),
              ),
            );
          },
        ),
        _buildSettingTile(
          icon: Icons.logout,
          title: "Logout",
          subtitle: "Keluar dari akun Anda",
          onTap: _showLogoutConfirmation,
          color: Colors.redAccent,
        ),
        _buildSettingTile(
          icon: Icons.person_remove,
          title: "Hapus Akun",
          subtitle: "Hapus akun Anda secara permanen",
          onTap: _showDeleteAccountConfirmation,
          color: Colors.red,
        ),
        const SizedBox(
          height: 20,
        ), // Tambahan ruang di bagian bawah konten card
      ],
    );
  }

  // --- Widget untuk Konten Pengaturan Notifikasi ---
  Widget _buildNotificationSettingsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Pengaturan Notifikasi",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF041413),
          ),
        ),
        const Divider(height: 20, thickness: 1, color: Colors.black12),
        _buildSettingTile(
          icon: Icons.vibration,
          title: "Getar Notifikasi",
          subtitle: "Aktifkan getaran saat notifikasi diterima",
          trailing: Switch(
            value: _vibrateOnNotification,
            onChanged: (value) async {
              setState(() {
                _vibrateOnNotification = value;
              });
              _saveNotificationSetting('vibrateOnNotification', value);
              if (value) {
                print(
                  'Attempting to vibrate...',
                ); // Debug print: Cek di konsol apakah ini muncul
                // Simulasi getaran yang lebih panjang (DRTTT)
                // Penting: HapticFeedback.vibrate() mungkin tidak berfungsi jika:
                // 1. Mode hemat daya aktif.
                // 2. Mode senyap/jangan ganggu aktif.
                // 3. Pengaturan sistem menonaktifkan getaran.
                // 4. Perangkat keras ponsel tidak mendukung getaran yang kuat.
                for (int i = 0; i < 3; i++) {
                  HapticFeedback.vibrate();
                  await Future.delayed(const Duration(milliseconds: 150));
                }
                print('Vibration sequence completed.'); // Debug print
              }
            },
            activeColor: const Color(0xFF093B2B),
          ),
        ),
        _buildSettingTile(
          icon: Icons.email_outlined,
          title: "Notifikasi Email",
          subtitle: "Dapatkan notifikasi penting via email",
          trailing: Switch(
            value: _emailNotifications,
            onChanged: (value) {
              setState(() {
                _emailNotifications = value;
              });
              _saveNotificationSetting('emailNotifications', value);
            },
            activeColor: const Color(0xFF093B2B),
          ),
        ),
        _buildSettingTile(
          icon: Icons.notifications_active_outlined,
          title: "Notifikasi Umum",
          subtitle: "Dapatkan pembaruan dan pengingat umum",
          trailing: Switch(
            value: _generalNotifications,
            onChanged: (value) {
              setState(() {
                _generalNotifications = value;
              });
              _saveNotificationSetting('generalNotifications', value);
            },
            activeColor: const Color(0xFF093B2B),
          ),
        ),
        const SizedBox(
          height: 20,
        ), // Tambahan ruang di bagian bawah konten card
      ],
    );
  }
}
