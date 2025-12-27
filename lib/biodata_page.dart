// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:ui'; // Untuk ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Untuk SvgPicture
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class BiodataPage extends StatefulWidget {
  const BiodataPage({super.key});

  @override
  State<BiodataPage> createState() => _BiodataPageState();
}

class _BiodataPageState extends State<BiodataPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController namaController = TextEditingController();
  final TextEditingController tanggalLahirController = TextEditingController();
  final TextEditingController teleponController = TextEditingController();
  final TextEditingController alamatController = TextEditingController();
  final TextEditingController pekerjaanController = TextEditingController();
  final TextEditingController tentangController = TextEditingController();

  String? gender;
  File? _profileImageFile; // Menggunakan nama yang sama dengan ProfilePage
  File? _coverImageFile; // Menambahkan cover image
  Map<String, dynamic>? _biodata;

  // Animation controllers removed as they are not needed for this static page
  // late final AnimationController _colorController;
  // late final AnimationController _scaleController;
  // late final Animation<double> _scaleAnimation;

  final picker = ImagePicker();
  late Database _database;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white, // Sesuaikan dengan warna header baru
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // _colorController = AnimationController( // Removed
    //   vsync: this,
    //   duration: const Duration(seconds: 8),
    // )..repeat();

    // _scaleController = AnimationController( // Removed
    //   vsync: this,
    //   duration: const Duration(milliseconds: 200),
    //   lowerBound: 0.95,
    //   upperBound: 1.0,
    // )..value = 1.0;

    // _scaleAnimation = CurvedAnimation( // Removed
    //   parent: _scaleController,
    //   curve: Curves.easeInOut,
    // );

    _initDatabase().then((_) => _loadBiodata());
  }

  @override
  void dispose() {
    // _colorController.dispose(); // Removed
    // _scaleController.dispose(); // Removed
    namaController.dispose();
    tanggalLahirController.dispose();
    teleponController.dispose();
    alamatController.dispose();
    pekerjaanController.dispose();
    tentangController.dispose();
    if (_database.isOpen) {
      _database.close();
    }
    super.dispose();
  }

  // Color get _animatedColor { // Removed
  //   final t = _colorController.value;
  //   final hue = (t * 360) % 360;
  //   return HSVColor.fromAHSV(1, hue, 1, 1).toColor();
  // }

  Future<void> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? "guest";
    final safeEmail = userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final path = p.join(dbPath, 'biodata_$safeEmail.db');

    _database = await openDatabase(
      path,
      version: 2, // Update version if adding new columns like coverFoto
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
    final List<Map<String, dynamic>> result = await _database.query(
      'biodata',
      orderBy: 'id DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      _biodata = result.first;
      File? tempProfileImage;
      File? tempCoverImage;
      String? tempGender = _biodata!['gender'];

      final fotoPath = _biodata!['foto'] ?? '';
      if (fotoPath.isNotEmpty) {
        final f = File(fotoPath);
        if (await f.exists()) {
          tempProfileImage = f;
        }
      }

      final coverFotoPath = _biodata!['coverFoto'] ?? '';
      if (coverFotoPath.isNotEmpty) {
        final c = File(coverFotoPath);
        if (await c.exists()) {
          tempCoverImage = c;
        }
      }

      setState(() {
        namaController.text = _biodata!['nama'] ?? '';
        tanggalLahirController.text = _biodata!['tanggalLahir'] ?? '';
        teleponController.text = _biodata!['telepon'] ?? '';
        alamatController.text = _biodata!['alamat'] ?? '';
        pekerjaanController.text = _biodata!['pekerjaan'] ?? '';
        tentangController.text = _biodata!['tentang'] ?? '';
        gender = tempGender;
        _profileImageFile = tempProfileImage;
        _coverImageFile = tempCoverImage;
      });
    }
  }

  Future<void> _saveBiodata() async {
    final data = {
      'nama': namaController.text,
      'tanggalLahir': tanggalLahirController.text,
      'gender': gender,
      'telepon': teleponController.text,
      'alamat': alamatController.text,
      'pekerjaan': pekerjaanController.text,
      'tentang': tentangController.text,
      'foto': _profileImageFile?.path ?? '',
      'coverFoto': _coverImageFile?.path ?? '',
    };

    final existingBiodata = await _database.query(
      'biodata',
      orderBy: 'id DESC',
      limit: 1,
    );

    if (existingBiodata.isEmpty) {
      await _database.insert('biodata', data);
    } else {
      final idToUpdate = existingBiodata.first['id'] as int;
      await _database.update(
        'biodata',
        data,
        where: 'id = ?',
        whereArgs: [idToUpdate],
      );
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Biodata berhasil disimpan ✅"),
        backgroundColor: Colors.green,
      ),
    );

    await Future.delayed(const Duration(milliseconds: 500));
    Navigator.pushReplacementNamed(context, '/home');
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

  Future<void> _selectDate() async {
    DateTime initialDate = DateTime.now();
    if (tanggalLahirController.text.isNotEmpty) {
      try {
        final parts = tanggalLahirController.text.split('/');
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

    final picked = await showDatePicker(
      context: super.context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF093B2B), // Warna primer tema profil
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

    if (picked != null) {
      setState(() {
        tanggalLahirController.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  // Menggunakan _buildTextField dari ProfilePage untuk konsistensi
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
      child: TextFormField(
        // Menggunakan TextFormField untuk validasi
        controller: controller,
        enabled: enabled,
        readOnly: onTap != null || !enabled,
        onTap: onTap,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: TextStyle(color: enabled ? Colors.black87 : Colors.grey[700]),
        validator: (value) {
          if (label != "Pekerjaan (Opsional)" &&
              label != "Tentang Saya (Opsional)" &&
              (value == null || value.isEmpty)) {
            return "Harap isi $label";
          }
          return null;
        },
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

  // Menggunakan _buildDropdownGender dari ProfilePage untuk konsistensi
  Widget _buildDropdownGender() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: gender,
        onChanged: (val) => setState(() => gender = val!),
        items: const [
          DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
          DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
        ],
        decoration: InputDecoration(
          labelText: "Jenis Kelamin",
          labelStyle: const TextStyle(color: Colors.black87),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 12,
          ),
        ),
        validator: (value) => value == null ? "Pilih jenis kelamin" : null,
      ),
    );
  }

  // Helper function for consistent white card styling (dari ProfilePage)
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

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // --- Konstanta Ukuran dan Jarak --- (dari ProfilePage)
    const double coverPhotoHeight = 180;
    const double profilePicRadius = 60;
    const double nameEmailCardHeight = 90;
    const double horizontalMargin = 20;
    const double verticalSpacingBetweenElements = 12;

    final double profilePicTop = coverPhotoHeight - profilePicRadius;
    final double nameEmailCardTop =
        profilePicTop + (2 * profilePicRadius) + verticalSpacingBetweenElements;

    final double calculatedStackHeight = nameEmailCardTop + nameEmailCardHeight;

    return Scaffold(
      backgroundColor: const Color(
        0xFFE6E6E6,
      ), // Warna latar belakang dari ProfilePage
      body: SafeArea(
        child: Column(
          children: [
            // ✅ HEADER
            Container(
              width: double.infinity,
              height: 58,
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/logoenkripsiapps.svg', // Pastikan path ini benar
                    height: 42,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'BIODATA', // Mengubah teks menjadi BIODATA
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

            // Bagian Utama: Cover, Foto Profil, Card Nama/Email
            SizedBox(
              height: calculatedStackHeight,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. FOTO SAMPUL
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: coverPhotoHeight,
                    child: GestureDetector(
                      onTap: () => _showCoverImagePickerOptions(context),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          image:
                              _coverImageFile != null
                                  ? DecorationImage(
                                    image: FileImage(_coverImageFile!),
                                    fit: BoxFit.cover,
                                  )
                                  : null,
                        ),
                        child: Center(
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
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2. FOTO PROFIL
                  Positioned(
                    top: profilePicTop,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _showProfileImagePickerOptions(context),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: profilePicRadius,
                              backgroundColor: Colors.white,
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

                  // 3. Card untuk Nama Lengkap dan Email (disini untuk Judul Biodata)
                  Positioned(
                    top: nameEmailCardTop,
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
                            namaController.text.isNotEmpty
                                ? namaController.text
                                : 'Lengkapi Biodata Anda',
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
                ],
              ),
            ),

            // Konten Form Biodata
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: _buildWhiteCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextField("Nama Lengkap", namaController),
                        _buildTextField(
                          "Tanggal Lahir",
                          tanggalLahirController,
                          onTap: _selectDate,
                        ),
                        _buildDropdownGender(),
                        _buildTextField(
                          "Nomor Telepon",
                          teleponController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                        _buildTextField("Alamat Lengkap", alamatController),
                        _buildTextField(
                          "Pekerjaan (Opsional)",
                          pekerjaanController,
                        ),
                        _buildTextField(
                          "Tentang Saya (Opsional)",
                          tentangController,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: 280,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFF093B2B,
                              ), // Warna dari ProfilePage
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 8,
                            ),
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                await _saveBiodata();
                              }
                            },
                            child: const Text(
                              "Simpan Biodata",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/home');
                          },
                          child: const Text(
                            "Lewati",
                            style: TextStyle(
                              color: Color(
                                0xFF093B2B,
                              ), // Warna dari ProfilePage
                              fontSize: 16,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
