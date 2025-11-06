import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _biodata;
  late Database _database;
  bool _isEditing = false;
  File? _imageFile;

  final _namaController = TextEditingController();
  final _tanggalController = TextEditingController();
  String _genderValue = 'Laki-laki';
  final _teleponController = TextEditingController();
  final _alamatController = TextEditingController();
  final _pekerjaanController = TextEditingController();
  final _tentangController = TextEditingController();

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  @override
  void initState() {
    super.initState();
    _initDatabase().then((_) => _loadBiodata());
  }

  Future<void> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? "guest";
    final safeEmail = userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final path = join(dbPath, 'biodata_$safeEmail.db');

    _database = await openDatabase(
      path,
      version: 1,
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
            foto TEXT
          )
        ''');
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
      if (fotoPath != null && fotoPath.toString().isNotEmpty) {
        final f = File(fotoPath);
        if (f.existsSync()) {
          _imageFile = f;
        } else {
          // file not exist: clear stored path in memory (but keep _biodata until saved)
          _imageFile = null;
          _biodata!['foto'] = '';
        }
      }
    } else {
      _biodata = null;
    }
    setState(() {});
  }

  Future<void> _saveBiodata() async {
    final data = {
      'nama': _namaController.text,
      'tanggalLahir': _tanggalController.text,
      'gender': _genderValue,
      'telepon': _teleponController.text,
      'alamat': _alamatController.text,
      'pekerjaan': _pekerjaanController.text,
      'tentang': _tentangController.text,
      'foto': _imageFile?.path ?? (_biodata?['foto'] ?? ''),
    };

    if (_biodata == null || _biodata!['id'] == null) {
      final id = await _database.insert('biodata', data);
      data['id'] = id;
    } else {
      // update row with same id
      final id = _biodata!['id'] as int;
      await _database.update('biodata', data, where: 'id = ?', whereArgs: [id]);
      data['id'] = id;
    }

    setState(() {
      _biodata = data;
      _isEditing = false;
    });

    ScaffoldMessenger.of(super.context).showSnackBar(
      const SnackBar(content: Text("✅ Biodata berhasil disimpan")),
    );
  }

  Future<void> _showLogoutConfirmation() async {
    showDialog(
      context: super.context,
      barrierDismissible: false, // supaya tidak bisa ditutup dengan tap di luar
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
                    // Tombol Tidak
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
                    // Tombol Iya
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context); // tutup dialog
                          await _logout(); // panggil fungsi logout
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
      ScaffoldMessenger.of(
        super.context,
      ).showSnackBar(SnackBar(content: Text("Gagal logout: $e")));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = basename(picked.path);
      final savedImage = await File(
        picked.path,
      ).copy('${appDir.path}/$fileName');

      setState(() => _imageFile = savedImage);
    }
  }

  Future<void> _pickFromFileManager() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (res != null && res.files.isNotEmpty) {
        final path = res.files.single.path;
        if (path != null) {
          setState(() => _imageFile = File(path));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        super.context,
      ).showSnackBar(SnackBar(content: Text("Gagal membuka file manager: $e")));
    }
  }

  Future<void> _deleteImage() async {
    try {
      // delete local file if exists
      if (_imageFile != null && await _imageFile!.exists()) {
        try {
          await _imageFile!.delete();
        } catch (_) {
          // ignore file delete error but still clear references
        }
      }

      // clear in-memory and DB
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
        _imageFile = null;
        if (_biodata != null) _biodata!['foto'] = '';
      });

      ScaffoldMessenger.of(
        super.context,
      ).showSnackBar(const SnackBar(content: Text("✅ Foto dihapus")));
    } catch (e) {
      ScaffoldMessenger.of(
        super.context,
      ).showSnackBar(SnackBar(content: Text("Gagal menghapus foto: $e")));
    }
  }

  Future<void> _pickDate() async {
    DateTime initialDate = DateTime.now();
    if (_tanggalController.text.isNotEmpty) {
      initialDate =
          DateTime.tryParse(_tanggalController.text) ?? DateTime.now();
    }
    final date = await showDatePicker(
      context: super.context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      _tanggalController.text = date.toIso8601String().split('T')[0];
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
        readOnly: onTap != null,
        onTap: onTap,
        maxLines: maxLines,
        keyboardType: keyboardType, // 🟢 ditambahkan
        inputFormatters: inputFormatters, // 🟢 ditambahkan
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black87),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey[200],
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
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(color: Colors.black87, fontSize: 14),
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
        onChanged: (val) => setState(() => _genderValue = val!),
        items: const [
          DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
          DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
        ],
        decoration: InputDecoration(
          labelText: "Jenis Kelamin",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _tanggalController.dispose();
    _teleponController.dispose();
    _alamatController.dispose();
    _pekerjaanController.dispose();
    _tentangController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6E6E6),
      body: Column(
        children: [
          // HEADER
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/logoenkripsiapps.svg',
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
          ),

          // BODY SCROLLABLE
          Expanded(
            child: SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(), // 🔹 biar smooth (efek iPhone)
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                80,
              ), // 🔹 padding bawah biar gak ketabrak navbar
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Title + edit toggler (tidak diubah)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Biodata Anda",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF041413),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _isEditing = !_isEditing),
                          child: Row(
                            children: const [
                              Text(
                                "Edit",
                                style: TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.edit, color: Colors.teal, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // FOTO PROFIL + ikon aksi (ikon diberi padding supaya tidak nabrak)
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[200],
                          backgroundImage:
                              _imageFile != null
                                  ? FileImage(_imageFile!)
                                  : (_biodata?['foto'] != null &&
                                      _biodata!['foto'].toString().isNotEmpty)
                                  ? FileImage(File(_biodata!['foto']))
                                  : null,
                          child:
                              (_imageFile == null &&
                                      (_biodata?['foto'] == null ||
                                          _biodata!['foto'].toString().isEmpty))
                                  ? const Icon(
                                    Icons.account_circle,
                                    size: 60,
                                    color: Colors.grey,
                                  )
                                  : null,
                        ),

                        // Jarak ekstra agar ikon tidak nabrak lingkaran
                        if (_isEditing)
                          Padding(
                            padding: const EdgeInsets.only(top: 14, bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Kamera
                                InkWell(
                                  onTap: () => _pickImage(ImageSource.camera),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.green,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Galeri
                                InkWell(
                                  onTap: () => _pickImage(ImageSource.gallery),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: const Icon(
                                      Icons.photo_library,
                                      color: Colors.blueAccent,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // File manager (ambil file dari storage)
                                InkWell(
                                  onTap: _pickFromFileManager,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: const Icon(
                                      Icons.folder_open,
                                      color: Colors.teal,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Hapus (hapus file + update DB)
                                InkWell(
                                  onTap: _deleteImage,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.redAccent,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // MODE VIEW (NORMAL) — sesuai urutan yg kamu minta
                    if (!_isEditing) ...[
                      // Pekerjaan (bold)
                      Text(
                        _pekerjaanController.text.isNotEmpty
                            ? _pekerjaanController.text
                            : '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF041413),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Tentang Saya (multiline plain)
                      Text(
                        _tentangController.text.isNotEmpty
                            ? _tentangController.text
                            : '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Divider(color: Colors.black26, thickness: 0.5),
                      const SizedBox(height: 10),

                      // Nama, TTL, Jenis Kelamin (urut)
                      _buildReadOnly("Nama", _namaController.text),
                      _buildReadOnly("Tanggal Lahir", _tanggalController.text),
                      _buildReadOnly("Jenis Kelamin", _genderValue),

                      // Telepon & Alamat (tampil juga di view)
                      _buildReadOnly("Telepon", _teleponController.text),
                      _buildReadOnly("Alamat", _alamatController.text),
                    ],

                    // MODE EDIT: tampilkan form lengkap (pekerjaan & tentang disembunyikan di atas foto)
                    if (_isEditing) ...[
                      _buildTextField("Nama", _namaController, enabled: true),
                      _buildTextField(
                        "Tanggal Lahir",
                        _tanggalController,
                        enabled: true,
                        onTap: _pickDate,
                      ),
                      _buildDropdownGender(),
                      _buildTextField(
                        "Telepon",
                        _teleponController,
                        enabled: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),

                      _buildTextField(
                        "Alamat",
                        _alamatController,
                        enabled: true,
                      ),
                      _buildTextField(
                        "Pekerjaan",
                        _pekerjaanController,
                        enabled: true,
                      ),
                      _buildTextField(
                        "Tentang Saya",
                        _tentangController,
                        enabled: true,
                        maxLines: 3,
                      ),
                      SizedBox(
                        width: 180, // 🔹 ubah manual lebar di sini
                        height: 46, // 🔹 ubah manual tinggi di sini
                        child: ElevatedButton.icon(
                          onPressed: _saveBiodata,
                          icon: const Icon(Icons.save, size: 20),
                          label: const Text(
                            "Simpan",
                            style: TextStyle(
                              fontSize: 14, // 🔹 ubah font juga kalau mau
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF093B2B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: const Size(
                              180,
                              46,
                            ), // ✅ ukuran minimum tetap stabil
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    // Logout tombol (ukuran bisa diatur manual via SizedBox)
                    SizedBox(
                      width: 180, // ubah lebar manual di sini
                      height: 46, // ubah tinggi manual di sini
                      child: OutlinedButton.icon(
                        onPressed: _showLogoutConfirmation,
                        icon: const Icon(
                          Icons.logout,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        label: const Text(
                          "Logout",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.redAccent,
                            width: 1.3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: const Size(180, 46),
                          maximumSize: const Size(220, 50),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
