import 'dart:async';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

/// Cross-platform image picker replacing the old HTML-only version.
class WebImagePicker {
  static Future<String?> pickImageAsBase64() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 300,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        return base64Encode(bytes);
      }
    } catch (e) {
      print('Error picking image: $e');
    }
    return null;
  }
}
