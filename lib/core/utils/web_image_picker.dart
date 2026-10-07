import 'dart:async';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Cross-platform image picker replacing the old HTML-only version.
class WebImagePicker {
  static Future<String?> pickImageAsBase64({bool convertToWebP = true}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        
        if (convertToWebP) {
          try {
            final webpBytes = await FlutterImageCompress.compressWithList(
              bytes,
              minWidth: 600,
              minHeight: 600,
              quality: 85,
              format: CompressFormat.webp,
            );
            return base64Encode(webpBytes);
          } catch (e) {
            print('WebP compression failed, falling back to original: $e');
            return base64Encode(bytes);
          }
        }
        
        return base64Encode(bytes);
      }
    } catch (e) {
      print('Error picking image: $e');
    }
    return null;
  }
}
