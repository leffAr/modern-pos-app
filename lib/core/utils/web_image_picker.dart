import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;

/// Web-compatible image picker using dart:html directly.
/// This bypasses all Flutter plugin channels and works reliably on all browsers.
class WebImagePicker {
  static Future<String?> pickImageAsBase64() async {
    final completer = Completer<String?>();
    
    final input = html.FileUploadInputElement()
      ..accept = 'image/*';
    
    // Listen for file selection
    input.onChange.listen((event) {
      final file = input.files?.first;
      if (file != null) {
        final reader = html.FileReader();
        reader.readAsDataUrl(file);
        reader.onLoadEnd.listen((event) {
          final result = reader.result as String;
          
          // Gunakan HTML5 Canvas untuk resize super cepat (Native Browser)
          final img = html.ImageElement(src: result);
          img.onLoad.listen((e) {
             int width = img.width ?? 300;
             int height = img.height ?? 300;
             const maxDim = 300;
             
             if (width > maxDim || height > maxDim) {
                if (width > height) {
                   height = (height * (maxDim / width)).round();
                   width = maxDim;
                } else {
                   width = (width * (maxDim / height)).round();
                   height = maxDim;
                }
             }
             
             final canvas = html.CanvasElement(width: width, height: height);
             final ctx = canvas.context2D;
             // Gambar image ke canvas dengan ukuran yang sudah disesuaikan
             ctx.drawImageScaled(img, 0, 0, width, height);
             
             // Convert kembali ke base64 (sangat cepat)
             final resizedDataUrl = canvas.toDataUrl('image/png');
             final base64String = resizedDataUrl.split(',').last;
             completer.complete(base64String);
          });
          img.onError.listen((e) {
             // Fallback jika gagal load image
             completer.complete(result.split(',').last);
          });
        });
        reader.onError.listen((event) {
          completer.complete(null);
        });
      } else {
        completer.complete(null);
      }
    });
    
    // If user cancels the dialog
    // Use a delayed check since there's no reliable cancel event
    input.click();
    
    return completer.future;
  }
}
