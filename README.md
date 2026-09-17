# Modern POS (Point of Sale)

Aplikasi Kasir POS Multi-Bisnis Offline-First yang dikembangkan menggunakan Flutter & Dart.

## Fitur Utama
1. **Offline-First**: Aplikasi bisa terus digunakan walau internet mati.
2. **Sinkronisasi (Sync Engine)**: Menggunakan queue untuk push & pull data ke backend Laravel.
3. **Multi Bisnis & Cabang**: Mendukung sistem cabang secara dinamis (Data terisolasi via Branch ID).
4. **Pembayaran & Cetak Struk**: Mendukung kalkulasi pajak (PPN), diskon, quick cash, & PDF receipt.
5. **Manajemen Shift**: Kasir dapat membuka dan menutup shift (CashDrawer calculation).

## Persiapan Development
Pastikan Anda memiliki:
- Flutter SDK `^3.2.0`
- Android Studio / Xcode

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Generate Drift Database (Wajib)
Jalankan perintah ini untuk melakukan code-generation bagi database SQLite lokal (Drift):
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Run Aplikasi
```bash
flutter run
```

## Menjalankan Unit Test
Proyek ini mengutamakan stabilitas perhitungan matematis uang. Uji test case kalkulasi dengan:
```bash
flutter test
```

## Deployment & Production Build

### Build untuk Android (APK & App Bundle)
Gunakan *App Bundle* untuk rilis ke Play Store, atau APK untuk distribusi manual ke device POS.
```bash
# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

### Build untuk iOS
Pastikan Anda menjalankan perintah ini dari macOS yang memiliki instalasi Xcode.
```bash
# Update pods
cd ios && pod install && cd ..

# Build iOS Release
flutter build ios --release
```
Lalu buka `ios/Runner.xcworkspace` di Xcode untuk melakukan proses *Archive* dan *Upload* ke App Store Connect.

---
*Dibangun dengan prinsip Clean Architecture dan Repository Pattern untuk stabilitas tingkat enterprise.*
