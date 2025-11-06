// lib/utils/crypto_utils.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

List<int> _randomBytes(int length) {
  final rnd = Random.secure();
  return List<int>.generate(length, (_) => rnd.nextInt(256));
}

Future<SecretKey> _deriveKeyFromPassword(
  String password,
  List<int> salt,
  int iterations,
) async {
  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );

  final secretKey = await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt,
  );
  return secretKey;
}

Future<Map<String, String>> encryptWithPassword({
  required String plainText,
  required String password,
  int iterations = 100000,
}) async {
  final salt = Uint8List.fromList(_randomBytes(16));
  final iv = Uint8List.fromList(_randomBytes(12));

  final secretKey = await _deriveKeyFromPassword(password, salt, iterations);

  final algorithm = AesGcm.with256bits();
  final secretBox = await algorithm.encrypt(
    utf8.encode(plainText),
    secretKey: secretKey,
    nonce: iv,
  );

  return {
    'version': '1',
    'iterations': iterations.toString(),
    'salt': base64Encode(salt),
    'iv': base64Encode(iv),
    'ciphertext': base64Encode(secretBox.cipherText),
    'mac': base64Encode(secretBox.mac.bytes),
  };
}

String buildHackerStylePayload(Map<String, String> enc) {
  final b = StringBuffer();

  b.writeln('⫸⫷  ██████  H A C K - M E S S E N G E R  ██████  ⫸⫷');
  b.writeln('');
  b.writeln('<< ENCRYPTED PAYLOAD >>');
  b.writeln('────────────────────────────────────────────');
  b.writeln('```');
  b.writeln('VERSION: ${enc['version']}');
  b.writeln('ITER: ${enc['iterations']}');
  b.writeln('SALT: ${enc['salt']}');
  b.writeln('IV:   ${enc['iv']}');
  b.writeln('CIPH: ${enc['ciphertext']}');
  b.writeln('MAC:  ${enc['mac']}');
  b.writeln('```');
  b.writeln('────────────────────────────────────────────');
  b.writeln('→ Cara buka: MINTA password pengirim via SMS/WA terpisah.');
  b.writeln(
    '→ Buka aplikasi Decryptor, masukkan password & paste payload di atas.',
  );
  b.writeln('');
  b.writeln('⚠️ Password TIDAK dikirim lewat email ini.');
  b.writeln('');
  b.writeln('— Sent from Enkripsi App by Defri');

  return b.toString();
}
