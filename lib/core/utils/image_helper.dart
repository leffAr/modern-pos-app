import 'dart:convert';
import 'dart:typed_data';

class ImageHelper {
  static final Map<String, Uint8List> _cache = {};
  
  // Membatasi jumlah cache agar tidak memori penuh (misalnya max 500 gambar)
  static final List<String> _cacheKeys = [];

  static Uint8List? decodeBase64(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;
    
    if (_cache.containsKey(base64String)) {
      return _cache[base64String];
    }

    try {
      final bytes = base64Decode(base64String);
      
      // Simpan ke cache
      if (_cacheKeys.length >= 500) {
        final oldestKey = _cacheKeys.removeAt(0);
        _cache.remove(oldestKey);
      }
      _cacheKeys.add(base64String);
      _cache[base64String] = bytes;
      
      return bytes;
    } catch (e) {
      return null;
    }
  }
}
