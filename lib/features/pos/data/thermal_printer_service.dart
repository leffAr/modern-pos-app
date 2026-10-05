import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'network_printer_helper.dart';

enum PrinterConnectionType {
  bluetooth,
  network,
  system,
}

class ThermalPrinterService {
  static const String keyPrinterType = "printerType";
  static const String keyBtMac = "btPrinterMac";
  static const String keyBtName = "btPrinterName";
  static const String keyNetIp = "netPrinterIp";
  static const String keyNetPort = "netPrinterPort";
  static const String keyPaperSize = "paperSize";
  static const String keyAutoPrint = "isAutoPrint";
  static const String keyAutoCut = "autoCut";
  static const String keyPrintLogoThermal = "printLogoThermal";

  // ==========================================
  // BLUETOOTH THERMAL PRINTER METHODS
  // ==========================================

  /// Memeriksa apakah perangkat saat ini mendukung Bluetooth langsung
  static bool get isBluetoothSupported => !kIsWeb;

  /// Memeriksa apakah modul Bluetooth pada perangkat aktif
  static Future<bool> isBluetoothEnabled() async {
    if (kIsWeb) return false;
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  /// Memeriksa atau meminta izin Bluetooth
  static Future<bool> checkBluetoothPermission() async {
    if (kIsWeb) return false;
    try {
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (_) {
      return false;
    }
  }

  /// Mendapatkan daftar semua printer Bluetooth yang sudah dipasangkan (paired)
  static Future<List<BluetoothInfo>> getPairedDevices() async {
    if (kIsWeb) return [];
    try {
      final isPermitted = await checkBluetoothPermission();
      if (!isPermitted) return [];
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      debugPrint("Error fetching paired Bluetooth printers: $e");
      return [];
    }
  }

  /// Memeriksa status koneksi ke printer Bluetooth
  static Future<bool> isBluetoothConnected() async {
    if (kIsWeb) return false;
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  /// Menghubungkan ke printer Bluetooth berdasarkan MAC address
  static Future<bool> connectBluetooth(String macAddress) async {
    if (kIsWeb) return false;
    try {
      // Putuskan koneksi sebelumnya terlebih dahulu jika ada
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}

      final bool connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: macAddress,
      );
      return connected;
    } catch (e) {
      debugPrint("Gagal menghubungkan Bluetooth ($macAddress): $e");
      return false;
    }
  }

  /// Memutuskan koneksi printer Bluetooth
  static Future<bool> disconnectBluetooth() async {
    if (kIsWeb) return true;
    try {
      return await PrintBluetoothThermal.disconnect;
    } catch (_) {
      return false;
    }
  }

  /// Mendapatkan estimasi level baterai printer bluetooth jika didukung
  static Future<int> getBluetoothBattery() async {
    if (kIsWeb) return -1;
    try {
      return await PrintBluetoothThermal.batteryLevel;
    } catch (_) {
      return -1;
    }
  }

  /// Mengirim raw ESC/POS bytes ke printer Bluetooth aktif
  static Future<bool> printBytesViaBluetooth(List<int> bytes) async {
    if (kIsWeb) return false;
    try {
      bool isConnected = await isBluetoothConnected();
      if (!isConnected) {
        // Coba auto-connect ke printer Bluetooth yang tersimpan
        final prefs = await SharedPreferences.getInstance();
        final savedMac = prefs.getString(keyBtMac);
        if (savedMac != null && savedMac.isNotEmpty) {
          isConnected = await connectBluetooth(savedMac);
        }
      }

      if (!isConnected) {
        return false;
      }

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      debugPrint("Error writeBytes Bluetooth: $e");
      return false;
    }
  }

  // ==========================================
  // NETWORK / LAN / WI-FI THERMAL METHODS
  // ==========================================

  /// Mengirim raw ESC/POS bytes ke printer jaringan (IP:Port, default Port 9100)
  static Future<bool> printBytesViaNetwork(String ip, int port, List<int> bytes) async {
    try {
      return await sendBytesToNetworkPrinter(ip, port, bytes);
    } catch (e) {
      debugPrint("Error printBytesViaNetwork: $e");
      return false;
    }
  }

  // ==========================================
  // SYSTEM / USB / SPOOLER PRINTER METHODS
  // ==========================================

  /// Mendapatkan daftar semua printer yang terpasang di sistem operasi (Windows, Mac, Linux, Android)
  static Future<List<Printer>> getSystemPrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (e) {
      debugPrint("Error listing system printers: $e");
      return [];
    }
  }

  // ==========================================
  // PREFERENCE GETTERS & SETTERS
  // ==========================================

  static Future<PrinterConnectionType> getConnectionType() async {
    final prefs = await SharedPreferences.getInstance();
    final typeStr = prefs.getString(keyPrinterType) ?? "system";
    switch (typeStr) {
      case "bluetooth":
        return PrinterConnectionType.bluetooth;
      case "network":
        return PrinterConnectionType.network;
      case "system":
      default:
        return PrinterConnectionType.system;
    }
  }

  static Future<void> saveConnectionType(PrinterConnectionType type) async {
    final prefs = await SharedPreferences.getInstance();
    String typeStr = "system";
    if (type == PrinterConnectionType.bluetooth) typeStr = "bluetooth";
    if (type == PrinterConnectionType.network) typeStr = "network";
    await prefs.setString(keyPrinterType, typeStr);
  }

  static Future<void> saveBluetoothPrinter(String name, String mac) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyBtName, name);
    await prefs.setString(keyBtMac, mac);
    await saveConnectionType(PrinterConnectionType.bluetooth);
  }

  static Future<void> saveNetworkPrinter(String ip, int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyNetIp, ip);
    await prefs.setInt(keyNetPort, port);
    await saveConnectionType(PrinterConnectionType.network);
  }
}
