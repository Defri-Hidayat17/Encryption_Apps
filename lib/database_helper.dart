import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'biodata.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE biodata (
            nama TEXT PRIMARY KEY,
            ttl TEXT,
            jenisKelamin TEXT,
            pekerjaan TEXT,
            tentang TEXT,
            foto BLOB
          )
        ''');
      },
    );
  }

  // Insert biodata
  Future<int> insertBiodata(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      'biodata',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace, // ganti jika nama sama
    );
  }

  // Ambil biodata (hanya 1 record, bisa diubah sesuai kebutuhan)
  Future<Map<String, dynamic>?> getBiodata() async {
    final db = await database;
    final result = await db.query('biodata', limit: 1); // ambil record pertama
    return result.isNotEmpty ? result.first : null;
  }

  // Update biodata berdasarkan nama
  Future<int> updateBiodata(Map<String, dynamic> data) async {
    final db = await database;
    final nama = data['nama'];
    if (nama == null) return 0; // pastikan ada nama
    return await db.update(
      'biodata',
      data,
      where: 'nama = ?',
      whereArgs: [nama],
    );
  }

  // Hapus semua biodata
  Future<void> clearBiodata() async {
    final db = await database;
    await db.delete('biodata');
  }
}
