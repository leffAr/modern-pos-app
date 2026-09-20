import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/database/database.dart';
import '../../../core/database/backup_service.dart';
import '../../../core/utils/web_image_picker.dart';
import '../../../core/utils/image_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  bool _isLoading = true;
  Business? _currentBusiness;

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String? _logoBase64;
  double _taxPercentage = 0.0;
  bool _enableTableNumber = false;
  bool _enableQueueNumber = false;

  @override
  void initState() {
    super.initState();
    _loadStoreInfo();
  }

  Future<void> _loadStoreInfo() async {
    try {
      final business =
          await (appDb.select(appDb.businesses)..limit(1)).getSingleOrNull();
      if (business != null) {
        _currentBusiness = business;
        _nameCtrl.text = business.name;
        _addressCtrl.text = business.address ?? '';
        _phoneCtrl.text = business.phone ?? '';
        _logoBase64 = business.logoBase64;
        _taxPercentage = business.taxPercentage;
        _enableTableNumber = business.enableTableNumber;
        _enableQueueNumber = business.enableQueueNumber;
      }
    } catch (e) {
      debugPrint('Error loading store info: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isProcessingLogo = false;

  Future<void> _pickLogo() async {
    try {
      // Pemilihan dan kompresi (resize) gambar sudah dilakukan secara instan 
      // oleh HTML5 Canvas di dalam WebImagePicker.pickImageAsBase64()
      final base64 = await WebImagePicker.pickImageAsBase64();
      if (base64 != null) {
        setState(() {
          _logoBase64 = base64;
          _isProcessingLogo = false;
        });
      }
    } catch (e) {
      setState(() {
          _isProcessingLogo = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal memproses gambar: $e')));
    }
  }

  Future<void> _saveSettings() async {
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama toko tidak boleh kosong')));
      return;
    }

    try {
      if (_currentBusiness == null) {
        // Insert
        await appDb.into(appDb.businesses).insert(
              BusinessesCompanion.insert(
                id: 'BIZ-1',
                name: _nameCtrl.text,
                address: drift.Value(_addressCtrl.text),
                phone: drift.Value(_phoneCtrl.text),
                logoBase64: drift.Value(_logoBase64),
                taxPercentage: drift.Value(_taxPercentage),
                enableTableNumber: drift.Value(_enableTableNumber),
                enableQueueNumber: drift.Value(_enableQueueNumber),
              ),
            );
      } else {
        // Update
        await (appDb.update(appDb.businesses)
              ..where((t) => t.id.equals(_currentBusiness!.id)))
            .write(
          BusinessesCompanion(
            name: drift.Value(_nameCtrl.text),
            address: drift.Value(_addressCtrl.text),
            phone: drift.Value(_phoneCtrl.text),
            logoBase64: drift.Value(_logoBase64),
            taxPercentage: drift.Value(_taxPercentage),
            enableTableNumber: drift.Value(_enableTableNumber),
            enableQueueNumber: drift.Value(_enableQueueNumber),
          ),
        );
      }
      
      // Simpan logo ke SharedPreferences agar bisa dibaca oleh index.html (saat loading)
      final prefs = await SharedPreferences.getInstance();
      if (_logoBase64 != null) {
        await prefs.setString('store_logo_base64', _logoBase64!);
      } else {
        await prefs.remove('store_logo_base64');
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Profil toko berhasil disimpan. Struk akan otomatis menggunakan data ini.')));
      _loadStoreInfo(); // reload state
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  Future<void> _resetTransactionData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Riwayat Transaksi?'),
        content: const Text(
            'Tindakan ini akan menghapus PERMANEN seluruh riwayat Penjualan, Pembayaran, dan Shift Kasir hari ini dan sebelumnya.\n\nData Produk dan Pengaturan Toko TIDAK akan dihapus. Anda yakin?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever),
            label: const Text('Ya, Hapus Semua'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sedang menghapus riwayat...')));
      try {
        await appDb.delete(appDb.payments).go();
        await appDb.delete(appDb.transactionItems).go();
        await appDb.delete(appDb.transactions).go();
        await appDb.delete(appDb.shifts).go();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Riwayat transaksi dan shift berhasil dikosongkan!'),
              backgroundColor: Colors.green));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Gagal menghapus riwayat: $e'),
              backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Toko & Struk'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;

          Widget content = Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Logo & Header
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              const Text(
                                'Pengaturan Struk Kasir',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Data ini akan muncul di bagian atas struk cetak Anda.',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              _buildLogoPicker(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                        // Right Column: Form Fields
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildFormFields(),
                              const SizedBox(height: 32),
                              _buildSaveButton(),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Pengaturan Struk Kasir',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Data ini akan muncul di bagian atas struk cetak Anda.',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        _buildLogoPicker(),
                        const SizedBox(height: 32),
                        _buildFormFields(),
                        const SizedBox(height: 32),
                        _buildSaveButton(),
                      ],
                    ),
            ),
          );

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: isWide ? 900 : 500),
                child: Column(
                  children: [
                    content,
                    const SizedBox(height: 48),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildBackupRestore(),
                    const SizedBox(height: 48),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildDangerZone(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSaveButton() {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: _saveSettings,
      icon: const Icon(Icons.save),
      label: const Text('SIMPAN PROFIL TOKO', style: TextStyle(fontSize: 16)),
    );
  }

  Widget _buildBackupRestore() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Backup & Restore Database',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
            'Amankan data toko Anda (Produk, Transaksi, Kasir) dengan mencadangkannya ke file JSON. Anda dapat memulihkannya kembali kapan saja.',
            style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Menyiapkan Backup...')));
                    await BackupService.exportBackup();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('Backup Berhasil! File telah disimpan.')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Gagal Backup: $e'),
                        backgroundColor: Colors.red));
                  }
                },
                icon: const Icon(Icons.cloud_download),
                label: const Text('Backup (Export)'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Memilih file backup...')));
                    await BackupService.importBackup();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Restore Berhasil! Silakan muat ulang aplikasi.')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Gagal Restore: $e'),
                        backgroundColor: Colors.red));
                  }
                },
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Restore (Import)'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Bahaya (Zona Merah)',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.red)),
        const SizedBox(height: 8),
        const Text(
            'Hapus seluruh riwayat transaksi, pembayaran, dan shift jika Anda ingin memulai ulang (reset pabrik data transaksi).',
            style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: _resetTransactionData,
          icon: const Icon(Icons.delete_sweep),
          label: const Text('Hapus Riwayat Transaksi'),
        ),
      ],
    );
  }

  Widget _buildLogoPicker() {
    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: _pickLogo,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _isProcessingLogo 
                          ? const Center(child: CircularProgressIndicator())
                          : _logoBase64 != null
                          ? Image.memory(base64Decode(_logoBase64!), fit: BoxFit.contain, filterQuality: FilterQuality.high)
                          : Image.asset('assets/images/logo_v3.png', fit: BoxFit.contain, filterQuality: FilterQuality.high),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: const Text(
                        'Ganti Logo',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_logoBase64 != null) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _logoBase64 = null),
              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
              label: const Text('Hapus Logo', style: TextStyle(color: Colors.red)),
            ),
          )
        ],
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nama Toko *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.store),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _addressCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Alamat Toko',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Nomor Telepon / WhatsApp',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Aktifkan Pajak PPN (11%)'),
                subtitle: const Text('Pajak akan otomatis dihitung di layar Kasir dan Struk.'),
                secondary: const Icon(Icons.account_balance_wallet),
                value: _taxPercentage > 0,
                onChanged: (val) {
                  setState(() {
                    _taxPercentage = val ? 11.0 : 0.0;
                  });
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Aktifkan Nomor Meja / Nama Pemesan'),
                subtitle: const Text('Kasir akan diminta mengisi Nomor Meja/Nama saat checkout.'),
                secondary: const Icon(Icons.table_restaurant),
                value: _enableTableNumber,
                onChanged: (val) => setState(() => _enableTableNumber = val),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Aktifkan Nomor Antrian Otomatis'),
                subtitle: const Text('Nomor antrian tercetak di struk dan ter-reset setiap hari (00:00).'),
                secondary: const Icon(Icons.numbers),
                value: _enableQueueNumber,
                onChanged: (val) => setState(() => _enableQueueNumber = val),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
