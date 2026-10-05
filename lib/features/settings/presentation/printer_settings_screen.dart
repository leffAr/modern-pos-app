import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import '../../../core/database/database.dart';
import '../../pos/data/receipt_printer_service.dart';
import '../../pos/data/thermal_printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  PrinterConnectionType _connectionType = PrinterConnectionType.system;
  String _paperSize = "58"; // "58" atau "80"
  bool _isAutoPrint = true;
  bool _printLogoThermal = true;
  bool _autoCut = false;

  // Bluetooth State
  bool _isBtScanning = false;
  bool _isBtConnected = false;
  String? _connectedBtMac;
  String? _connectedBtName;
  int _btBatteryLevel = -1;
  List<BluetoothInfo> _pairedDevices = [];

  // Network State
  final _ipController = TextEditingController(text: "192.168.1.200");
  final _portController = TextEditingController(text: "9100");
  bool _isTestingNetwork = false;

  // System Printers State
  List<Printer> _systemPrinters = [];
  bool _isLoadingSystemPrinters = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final type = await ThermalPrinterService.getConnectionType();
    final size = prefs.getString(ThermalPrinterService.keyPaperSize) ?? "58";
    final auto = prefs.getBool(ThermalPrinterService.keyAutoPrint) ?? true;
    final logo = prefs.getBool(ThermalPrinterService.keyPrintLogoThermal) ?? true;
    final cut = prefs.getBool(ThermalPrinterService.keyAutoCut) ?? (size == "80");

    final savedBtMac = prefs.getString(ThermalPrinterService.keyBtMac);
    final savedBtName = prefs.getString(ThermalPrinterService.keyBtName);
    final savedIp = prefs.getString(ThermalPrinterService.keyNetIp) ?? "192.168.1.200";
    final savedPort = prefs.getInt(ThermalPrinterService.keyNetPort) ?? 9100;

    _ipController.text = savedIp;
    _portController.text = savedPort.toString();

    setState(() {
      _connectionType = type;
      _paperSize = size;
      _isAutoPrint = auto;
      _printLogoThermal = logo;
      _autoCut = cut;
      _connectedBtMac = savedBtMac;
      _connectedBtName = savedBtName;
    });

    if (ThermalPrinterService.isBluetoothSupported) {
      _checkBluetoothConnection();
      _scanBluetoothDevices();
    }
    _loadSystemPrinters();
  }

  Future<void> _checkBluetoothConnection() async {
    if (!ThermalPrinterService.isBluetoothSupported) return;
    try {
      final isConnected = await ThermalPrinterService.isBluetoothConnected();
      int battery = -1;
      if (isConnected) {
        battery = await ThermalPrinterService.getBluetoothBattery();
      }
      if (mounted) {
        setState(() {
          _isBtConnected = isConnected;
          _btBatteryLevel = battery;
        });
      }
    } catch (_) {}
  }

  Future<void> _scanBluetoothDevices() async {
    if (!ThermalPrinterService.isBluetoothSupported) return;
    setState(() => _isBtScanning = true);
    try {
      final devices = await ThermalPrinterService.getPairedDevices();
      if (mounted) {
        setState(() {
          _pairedDevices = devices;
          _isBtScanning = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isBtScanning = false);
    }
  }

  Future<void> _loadSystemPrinters() async {
    setState(() => _isLoadingSystemPrinters = true);
    try {
      final printers = await ThermalPrinterService.getSystemPrinters();
      if (mounted) {
        setState(() {
          _systemPrinters = printers;
          _isLoadingSystemPrinters = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSystemPrinters = false);
    }
  }

  Future<void> _connectToBluetooth(BluetoothInfo device) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Menghubungkan ke ${device.name}..."), duration: const Duration(seconds: 1)),
    );

    final success = await ThermalPrinterService.connectBluetooth(device.macAdress);
    if (!mounted) return;

    if (success) {
      await ThermalPrinterService.saveBluetoothPrinter(device.name, device.macAdress);
      if (!mounted) return;
      setState(() {
        _isBtConnected = true;
        _connectedBtName = device.name;
        _connectedBtMac = device.macAdress;
        _connectionType = PrinterConnectionType.bluetooth;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Berhasil terhubung ke ${device.name}!"), backgroundColor: Colors.green),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal terhubung ke ${device.name}. Pastikan printer menyala dan sudah dipairing di pengaturan Bluetooth HP."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _disconnectBluetooth() async {
    await ThermalPrinterService.disconnectBluetooth();
    if (mounted) {
      setState(() => _isBtConnected = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Koneksi Bluetooth diputuskan")),
      );
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await ThermalPrinterService.saveConnectionType(_connectionType);
    await prefs.setString(ThermalPrinterService.keyPaperSize, _paperSize);
    await prefs.setBool(ThermalPrinterService.keyAutoPrint, _isAutoPrint);
    await prefs.setBool(ThermalPrinterService.keyPrintLogoThermal, _printLogoThermal);
    await prefs.setBool(ThermalPrinterService.keyAutoCut, _autoCut);

    if (_connectionType == PrinterConnectionType.network) {
      final ip = _ipController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 9100;
      await ThermalPrinterService.saveNetworkPrinter(ip, port);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pengaturan Printer Tersimpan"), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _testPrint() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Mencoba mencetak sampel struk..."), duration: Duration(seconds: 2)),
    );

    // Ambil data bisnis
    final business = await (appDb.select(appDb.businesses)..limit(1)).getSingleOrNull() ??
        const Business(
          id: "BIZ-1",
          name: "MODERN POS",
          address: "Jl. Kasir Pintar No. 1",
          phone: "081234567890",
          logoBase64: null,
          taxPercentage: 0.0,
          enableTableNumber: false,
          enableQueueNumber: false,
        );

    final success = await ReceiptPrinterService.printTestReceipt(business: business);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Test print berhasil dikirim ke printer!"), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal mencetak. Silakan cek koneksi printer Anda."), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pengaturan Printer Termal"),
        actions: [
          IconButton(
            tooltip: "Refresh Perangkat",
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _scanBluetoothDevices();
              _checkBluetoothConnection();
              _loadSystemPrinters();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Tipe Koneksi Terpilih
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _connectionType == PrinterConnectionType.bluetooth
                            ? Icons.bluetooth
                            : (_connectionType == PrinterConnectionType.network ? Icons.wifi : Icons.print),
                        color: Colors.blue.shade800,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Metode Aktif: ${_connectionType == PrinterConnectionType.bluetooth ? 'Bluetooth Thermal' : (_connectionType == PrinterConnectionType.network ? 'Wi-Fi / LAN Network' : 'Sistem / USB / PDF')}",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _connectionType == PrinterConnectionType.bluetooth
                                  ? (_isBtConnected
                                      ? "Terhubung ke $_connectedBtName${_btBatteryLevel >= 0 ? ' (Baterai: $_btBatteryLevel%)' : ''}"
                                      : "Belum terhubung ke Bluetooth")
                                  : (_connectionType == PrinterConnectionType.network
                                      ? "IP: ${_ipController.text}:${_portController.text}"
                                      : "Dialog cetak sistem OS"),
                              style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                            ),
                          ],
                        ),
                      ),
                      if (_connectionType == PrinterConnectionType.bluetooth)
                        Chip(
                          label: Text(_isBtConnected ? "ONLINE" : "OFFLINE", style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                          backgroundColor: _isBtConnected ? Colors.green : Colors.redAccent,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Pilihan Mode Koneksi (Segmented Selector)
          const Text("Pilih Jenis Koneksi Printer Termal:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          SegmentedButton<PrinterConnectionType>(
            segments: const [
              ButtonSegment(
                value: PrinterConnectionType.bluetooth,
                icon: Icon(Icons.bluetooth),
                label: Text("Bluetooth"),
              ),
              ButtonSegment(
                value: PrinterConnectionType.network,
                icon: Icon(Icons.wifi),
                label: Text("Wi-Fi / LAN"),
              ),
              ButtonSegment(
                value: PrinterConnectionType.system,
                icon: Icon(Icons.usb),
                label: Text("USB / Sistem"),
              ),
            ],
            selected: {_connectionType},
            onSelectionChanged: (val) {
              setState(() => _connectionType = val.first);
              _saveSettings();
            },
          ),
          const SizedBox(height: 20),

          // TAMPILAN BERDASARKAN MODE KONEKSI
          if (_connectionType == PrinterConnectionType.bluetooth) ...[
            _buildBluetoothSection(),
          ] else if (_connectionType == PrinterConnectionType.network) ...[
            _buildNetworkSection(),
          ] else ...[
            _buildSystemSection(),
          ],

          const Divider(height: 36),

          // UKURAN KERTAS
          const Text("Ukuran Kertas Thermal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text("Kertas 58 mm (Standar Mini/Portabel)"),
                  subtitle: const Text("Cocok untuk printer Bluetooth mini (Panda, VSC, Eppos, RPP02N, POS-58)"),
                  value: "58",
                  groupValue: _paperSize,
                  onChanged: (val) {
                    setState(() {
                      _paperSize = val!;
                      _autoCut = false;
                    });
                    _saveSettings();
                  },
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  title: const Text("Kertas 80 mm (Standar Kasir Besar)"),
                  subtitle: const Text("Cocok untuk printer Epson TM-T82, XPrinter 80mm, Kassen"),
                  value: "80",
                  groupValue: _paperSize,
                  onChanged: (val) {
                    setState(() {
                      _paperSize = val!;
                      _autoCut = true;
                    });
                    _saveSettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // PREFERENSI STRUK
          const Text("Pengaturan Tambahan Struk", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Auto Print Transaksi"),
                  subtitle: const Text("Cetak struk secara otomatis saat pembayaran kasir selesai"),
                  value: _isAutoPrint,
                  onChanged: (val) {
                    setState(() => _isAutoPrint = val);
                    _saveSettings();
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text("Cetak Logo Toko pada Struk"),
                  subtitle: const Text("Tampilkan gambar logo toko di bagian paling atas struk"),
                  value: _printLogoThermal,
                  onChanged: (val) {
                    setState(() => _printLogoThermal = val);
                    _saveSettings();
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text("Auto-Cut Pemotong Kertas"),
                  subtitle: const Text("Perintahkan printer untuk memotong kertas otomatis setelah selesai cetak (khusus printer dengan pemotong fisik)"),
                  value: _autoCut,
                  onChanged: (val) {
                    setState(() => _autoCut = val);
                    _saveSettings();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // TOMBOL TEST PRINT
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _testPrint,
            icon: const Icon(Icons.print, size: 24),
            label: const Text("Uji Coba Cetak Struk (Test Print)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // WIDGET BAGIAN BLUETOOTH
  Widget _buildBluetoothSection() {
    if (!ThermalPrinterService.isBluetoothSupported) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: const Row(
          children: [
            Icon(Icons.info, color: Colors.amber),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Browser Web tidak mendukung koneksi Bluetooth langsung ke port serial printer. Gunakan mode 'USB / Sistem' untuk mencetak dari Web atau buka aplikasi di Android untuk Bluetooth langsung.",
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Daftar Printer Bluetooth Paired:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            TextButton.icon(
              onPressed: _isBtScanning ? null : _scanBluetoothDevices,
              icon: _isBtScanning
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 18),
              label: Text(_isBtScanning ? "Memindai..." : "Pindai Ulang"),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_pairedDevices.isEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: const [
                    Icon(Icons.bluetooth_searching, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text("Belum ada printer Bluetooth yang dipasangkan.", style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(
                      "Pastikan printer termal Anda menyala, kemudian masuk ke Pengaturan Bluetooth HP Anda dan lakukan 'Pairing' dengan printer (misal: RPP02N, Panda, POS-58). Setelah itu klik 'Pindai Ulang'.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ..._pairedDevices.map((device) {
            final isCurrent = _connectedBtMac == device.macAdress;
            final isConnectedAndCurrent = isCurrent && _isBtConnected;

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isCurrent ? Colors.blue : Colors.grey.shade200,
                  width: isCurrent ? 2 : 1,
                ),
              ),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCurrent ? Colors.blue.shade100 : Colors.grey.shade100,
                  child: Icon(Icons.print, color: isCurrent ? Colors.blue.shade800 : Colors.grey.shade600),
                ),
                title: Text(device.name, style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text("MAC: ${device.macAdress}"),
                trailing: isConnectedAndCurrent
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        icon: const Icon(Icons.power_settings_new, size: 18),
                        label: const Text("Putus"),
                        onPressed: _disconnectBluetooth,
                      )
                    : FilledButton.tonal(
                        child: const Text("Hubungkan"),
                        onPressed: () => _connectToBluetooth(device),
                      ),
              ),
            );
          }),
      ],
    );
  }

  // WIDGET BAGIAN WI-FI / LAN
  Widget _buildNetworkSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Konfigurasi IP Printer Jaringan / Dapur", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text(
              "Masukkan alamat IP Printer Thermal yang terhubung ke router Wi-Fi/LAN kasir Anda (port standar: 9100).",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "IP Address Printer",
                hintText: "Contoh: 192.168.1.200",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_ethernet),
              ),
              onChanged: (_) => _saveSettings(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Port (Default 9100)",
                hintText: "9100",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              onChanged: (_) => _saveSettings(),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _isTestingNetwork
                  ? null
                  : () async {
                      setState(() => _isTestingNetwork = true);
                      final ip = _ipController.text.trim();
                      final port = int.tryParse(_portController.text.trim()) ?? 9100;
                      final ok = await ThermalPrinterService.printBytesViaNetwork(ip, port, [10, 10]);
                      if (!mounted) return;
                      setState(() => _isTestingNetwork = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? "Koneksi ke $ip:$port BERHASIL!" : "Gagal terhubung ke $ip:$port. Pastikan printer menyala & satu jaringan Wi-Fi."),
                          backgroundColor: ok ? Colors.green : Colors.red,
                        ),
                      );
                    },
              icon: _isTestingNetwork
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.network_check),
              label: Text(_isTestingNetwork ? "Menguji..." : "Uji Koneksi Soket IP"),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET BAGIAN USB / SISTEM
  Widget _buildSystemSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Mode Sistem & USB mendukung semua printer termal yang memiliki driver di komputer/HP Anda (Epson TM-T82 USB, XPrinter USB, Print Spooler Windows, Android Default Print Service, dll.). Dialog cetak sistem akan muncul secara otomatis saat kasir mencetak.",
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Printer Sistem yang Terdeteksi:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            IconButton(
              icon: _isLoadingSystemPrinters
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 20),
              onPressed: _loadSystemPrinters,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_systemPrinters.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Tidak ada printer driver terdaftar atau sedang berjalan di browser.", style: TextStyle(fontSize: 12, color: Colors.grey)),
          )
        else
          ..._systemPrinters.map(
            (p) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                leading: const Icon(Icons.print, color: Colors.blue),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(p.url.isNotEmpty ? p.url : "Printer Sistem"),
                trailing: p.isDefault ? const Chip(label: Text("Default", style: TextStyle(fontSize: 10))) : null,
              ),
            ),
          ),
      ],
    );
  }
}
