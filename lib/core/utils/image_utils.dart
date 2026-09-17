import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

class ImageUtils {
  /// Menghapus latar belakang putih dari gambar (mengubahnya menjadi transparan).
  /// Menggunakan algoritma deteksi warna (piksel yang mendekati putih).
  static Uint8List removeWhiteBackground(Uint8List imageBytes, {int tolerance = 30}) {
    // Decode image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return imageBytes;

    // 1. Resize DULU agar proses loop piksel jauh lebih cepat dan tidak bikin HP/PC nge-hang!
    if (image.width > 250 || image.height > 250) {
      image = img.copyResize(image, width: 250, height: 250, maintainAspect: true);
    }

    // 2. Pastikan gambar memiliki channel alpha (RGBA)
    var rgbaImage = image.hasAlpha ? image : image.convert(numChannels: 4);

    // 3. Hapus background putih
    int t = 60;
    for (var p in rgbaImage) {
      if (p.r > (255 - t) && p.g > (255 - t) && p.b > (255 - t)) {
        p.a = 0; // Set transparan
      }
    }

    // Kembalikan sebagai format PNG (level kompresi tinggi)
    // Kembalikan sebagai format PNG (level kompresi tinggi)
    return img.encodePng(rgbaImage, level: 9);
  }

  /// Versi asinkron yang menggunakan Web Workers / Isolate agar tidak freeze
  static Future<Uint8List> removeWhiteBackgroundAsync(Uint8List imageBytes) async {
    return await compute(removeWhiteBackground, imageBytes);
  }
}
