import 'dart:math' as math;
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  File? _profileImage;
  Map<String, dynamic>? _biodata;

  late final AnimationController _colorController;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  final picker = ImagePicker();
  late Database _database;

  @override
  void initState() {
    super.initState();

    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.95,
      upperBound: 1.0,
    )..value = 1.0;

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    );

    _initDatabase().then((_) => _loadBiodata());
  }

  @override
  void dispose() {
    _colorController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Color get _animatedColor {
    final t = _colorController.value;
    final hue = (t * 360) % 360;
    return HSVColor.fromAHSV(1, hue, 1, 1).toColor();
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
    final List<Map<String, dynamic>> result = await _database.query(
      'biodata',
      orderBy: 'id DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      setState(() {
        _biodata = result.first;
        namaController.text = _biodata!['nama'] ?? '';
        tanggalLahirController.text = _biodata!['tanggalLahir'] ?? '';
        teleponController.text = _biodata!['telepon'] ?? '';
        alamatController.text = _biodata!['alamat'] ?? '';
        pekerjaanController.text = _biodata!['pekerjaan'] ?? '';
        tentangController.text = _biodata!['tentang'] ?? '';
        gender = _biodata!['gender'];
        if (_biodata!['foto'] != null && _biodata!['foto'].isNotEmpty) {
          _profileImage = File(_biodata!['foto']);
        }
      });
    }
  }

  Future<void> _saveBiodata() async {
    await _database.insert(
      'biodata',
      {
        'nama': namaController.text,
        'tanggalLahir': tanggalLahirController.text,
        'gender': gender,
        'telepon': teleponController.text,
        'alamat': alamatController.text,
        'pekerjaan': pekerjaanController.text,
        'tentang': tentangController.text,
        'foto': _profileImage?.path ?? '',
      },
      conflictAlgorithm: ConflictAlgorithm.replace, // penting agar update
    );
  }

  Future<void> _pickImage(BuildContext context) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.tealAccent),
                title: const Text(
                  "Kamera",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo, color: Colors.tealAccent),
                title: const Text(
                  "Galeri",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              ListTile(
                leading: const Icon(Icons.folder, color: Colors.tealAccent),
                title: const Text(
                  "File Manager",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context, 'file'),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      if (source == 'camera') {
        final pickedFile = await picker.pickImage(source: ImageSource.camera);
        if (pickedFile != null)
          setState(() => _profileImage = File(pickedFile.path));
      } else if (source == 'gallery') {
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null)
          setState(() => _profileImage = File(pickedFile.path));
      } else if (source == 'file') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
        );
        if (result != null && result.files.single.path != null) {
          setState(() => _profileImage = File(result.files.single.path!));
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Gagal mengambil gambar")));
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: super.context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: now,
      builder:
          (context, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.dark(
                primary: Colors.tealAccent.shade400,
                onPrimary: Colors.black,
                surface: const Color(0xFF041413),
                onSurface: Colors.white,
              ),
              dialogBackgroundColor: const Color(0xFF041413),
            ),
            child: child!,
          ),
    );

    if (picked != null) {
      setState(() {
        tanggalLahirController.text =
            "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041413),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF041413), Color(0xFF062422)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _GlowingHoneycombPainter()),
          ),
          Column(
            children: [
              AnimatedBuilder(
                animation: _colorController,
                builder:
                    (context, _) => Container(
                      margin: const EdgeInsets.only(top: 40, bottom: 20),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        boxShadow: [
                          BoxShadow(
                            color: _animatedColor.withOpacity(0.5),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          "BIODATA",
                          style: TextStyle(
                            color: _animatedColor,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                    ),
              ),
              const SizedBox(height: 20),
              ScaleTransition(
                scale: _scaleAnimation,
                child: GestureDetector(
                  onTapDown: (_) => _scaleController.reverse(),
                  onTapUp: (_) {
                    _scaleController.forward();
                    _pickImage(context);
                  },
                  onTapCancel: () => _scaleController.forward(),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        backgroundImage:
                            _profileImage != null
                                ? FileImage(_profileImage!)
                                : null,
                        child:
                            _profileImage == null
                                ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.white70,
                                )
                                : null,
                      ),
                      Positioned(
                        bottom: 4,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.tealAccent,
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 18,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 20,
                  ),
                  child: _buildForm(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.tealAccent.withOpacity(0.08)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildTextField(
                  namaController,
                  "Nama Lengkap",
                  Icons.person_outline,
                ),
                GestureDetector(
                  onTap: _selectDate,
                  child: AbsorbPointer(
                    child: _buildTextField(
                      tanggalLahirController,
                      "Tanggal Lahir",
                      Icons.calendar_today_outlined,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: gender,
                    dropdownColor: const Color(0xFF041413),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.wc, color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    hint: const Text(
                      "Pilih Jenis Kelamin",
                      style: TextStyle(color: Colors.white54),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "Laki-laki",
                        child: Text("Laki-laki"),
                      ),
                      DropdownMenuItem(
                        value: "Perempuan",
                        child: Text("Perempuan"),
                      ),
                    ],
                    onChanged: (value) => setState(() => gender = value),
                    validator:
                        (value) => value == null ? "Pilih jenis kelamin" : null,
                  ),
                ),
                _buildTextField(
                  teleponController,
                  "Nomor Telepon",
                  Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                _buildTextField(
                  alamatController,
                  "Alamat Lengkap",
                  Icons.home_outlined,
                ),
                _buildTextField(
                  pekerjaanController,
                  "Pekerjaan (Opsional)",
                  Icons.work_outline,
                  isOptional: true,
                ),
                _buildTextField(
                  tentangController,
                  "Tentang Saya (Opsional)",
                  Icons.info_outline,
                  isOptional: true,
                  maxLines: 3,
                ),
                const SizedBox(height: 30),
                AnimatedBuilder(
                  animation: _colorController,
                  builder:
                      (context, _) => SizedBox(
                        width: 280,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _animatedColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 8,
                          ),
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              await _saveBiodata(); // simpan ke database

                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Biodata berhasil disimpan ✅"),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              await Future.delayed(
                                const Duration(milliseconds: 500),
                              );

                              // Navigasi ke HomePage, mengganti BiodataPage di stack
                              Navigator.pushReplacementNamed(context, '/home');
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isOptional = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        validator: (value) {
          if (!isOptional && (value == null || value.isEmpty)) {
            return "Harap isi $hint";
          }
          return null;
        },
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white70),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.white.withOpacity(0.07),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.tealAccent.shade400,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowingHoneycombPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.tealAccent.withOpacity(0.03)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7;

    const double hexRadius = 26;
    final hexHeight = hexRadius * 2;
    final hexWidth = 1.732 * hexRadius;
    final cols = (size.width / hexWidth).ceil();
    final rows = (size.height / (hexHeight * 0.75)).ceil();

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final dx = col * hexWidth + (row.isOdd ? hexWidth / 2 : 0);
        final dy = row * hexHeight * 0.75;
        final path = _hexagonPath(Offset(dx, dy), hexRadius);
        canvas.drawPath(path, paint);
      }
    }
  }

  Path _hexagonPath(Offset center, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * (math.pi / 180);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
