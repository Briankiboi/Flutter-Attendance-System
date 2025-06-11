import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class KeyGenerator {
  static final _random = Random.secure();
  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789@#\$%&*';
  static const _specialChars = '@#\$%&*';
  
  static String generateBackupKey() {
    // Generate a random 11-character key with at least one special character
    String key = '';
    bool hasSpecial = false;
    
    // Ensure at least one special character
    key += _specialChars[_random.nextInt(_specialChars.length)];
    hasSpecial = true;
    
    // Fill the rest with random characters
    while (key.length < 11) {
      final char = _chars[_random.nextInt(_chars.length)];
      if (!hasSpecial && _specialChars.contains(char)) {
        hasSpecial = true;
      }
      key += char;
    }
    
    // Add timestamp hash to ensure uniqueness
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final hash = sha256.convert(utf8.encode(key + timestamp)).toString().substring(0, 8);
    
    // Mix the hash into the key to ensure uniqueness
    final List<String> keyChars = key.split('');
    for (int i = 0; i < 4; i++) {
      keyChars[_random.nextInt(keyChars.length)] = hash[i];
    }
    
    return keyChars.join('');
  }
} 