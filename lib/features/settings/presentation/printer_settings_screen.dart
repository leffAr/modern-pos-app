import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";
import "../../../core/database/database.dart";
import "../../pos/data/receipt_printer_service.dart";

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  bool _isAutoPrint = true;
  String _paperSize = "80"; // "80" atau "58"

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoPrint = prefs.getBool("isAutoPrint") ?? true;
      _paperSize = prefs.getString("paperSize") ?? "80";
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isAutoPrint", _isAutoPrint);
    await prefs.setString("paperSize", _paperSize);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pengaturan Printer Tersimpan")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pengaturan Printer")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200)
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("Pencetakan Versi Web", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      SizedBox(height: 4),
                      Text("Aplikasi versi Web ini akan memunculkan dialog Print sistem secara otomatis. Anda dapat menggunakan Printer Thermal USB apapun yang sudah di-install drivernya di komputer Anda (Epson, XPrinter, dll).", style: TextStyle(fontSize: 13, color: Colors.black87)),
                    ]
                  )
                )
              ]
            )
          ),
          const SizedBox(height: 24),
          
          const Text("Ukuran Kertas Thermal", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          RadioListTile<String>(
            title: const Text("Kertas 80mm (Lebar)"),
            subtitle: const Text("Cocok untuk printer Epson TM-T82, XPrinter 80mm"),
            value: "80",
            groupValue: _paperSize,
            onChanged: (val) {
              setState(() => _paperSize = val!);
              _saveSettings();
            },
          ),
          RadioListTile<String>(
            title: const Text("Kertas 58mm (Kecil)"),
            subtitle: const Text("Cocok untuk printer mini bluetooth via USB"),
            value: "58",
            groupValue: _paperSize,
            onChanged: (val) {
              setState(() => _paperSize = val!);
              _saveSettings();
            },
          ),
          
          const Divider(height: 32),
          const Text("Preferensi Struk", style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text("Auto Print setelah pembayaran"),
            subtitle: const Text("Munculkan dialog print otomatis saat transaksi selesai"),
            value: _isAutoPrint,
            onChanged: (val) {
              setState(() => _isAutoPrint = val);
              _saveSettings();
            },
          ),
          
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Membuat struk test...")));
              
              final business = await (appDb.select(appDb.businesses)..limit(1)).getSingleOrNull() ?? 
                const Business(id: "BIZ-1", name: "MODERN POS", address: "Jl. Contoh Raya No. 123", phone: "08123456789", logoBase64: null, taxPercentage: 0.0, enableTableNumber: false, enableQueueNumber: false);

              // Memanggil fungsi PDF print (bisa 58 atau 80)
              await ReceiptPrinterService.printReceipt(
                business: business,
                items: [{"name": "Produk Test A", "qty": 1, "price": 15000.0, "variantName": null}, {"name": "Produk Test B", "qty": 2, "price": 5000.0, "variantName": "Ukuran L"}],
                subtotal: 25000.0,
                tax: 0.0,
                discount: 0.0,
                total: 25000.0,
                paid: 50000.0,
                change: 25000.0,
                paymentMethod: "CASH",
                cashierName: "Admin (Test)",
              );
            },
            icon: const Icon(Icons.print),
            label: const Text("Test Print Struk PDF"),
          ),
        ],
      ),
    );
  }
}
