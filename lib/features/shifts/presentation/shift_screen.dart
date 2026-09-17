import 'package:flutter/material.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  bool _isShiftOpen = false;
  final _cashController = TextEditingController();

  void _toggleShift() {
    if (!_isShiftOpen) {
      if (_cashController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan modal awal!')));
        return;
      }
      setState(() => _isShiftOpen = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shift Berhasil Dibuka!')));
    } else {
      // Logic for Close Shift
      showDialog(
        context: context,
        builder: (context) => _CloseShiftDialog(
          expectedCash: 1500000.0, // Dummy expected cash
          onConfirm: () {
            setState(() => _isShiftOpen = false);
            _cashController.clear();
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shift Ditutup. Laporan tercetak.')));
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Shift')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isShiftOpen ? Icons.storefront : Icons.storefront_outlined,
                    size: 80,
                    color: _isShiftOpen ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isShiftOpen ? 'Shift Sedang Aktif' : 'Shift Ditutup',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isShiftOpen
                        ? 'Kasir saat ini dapat melakukan transaksi.'
                        : 'Buka shift untuk mulai melakukan transaksi.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (!_isShiftOpen)
                    TextField(
                      controller: _cashController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Modal Awal (Cash in Drawer)',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (!_isShiftOpen) const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _isShiftOpen ? Colors.redAccent : Colors.blueAccent,
                      ),
                      onPressed: _toggleShift,
                      child: Text(_isShiftOpen ? 'TUTUP SHIFT' : 'BUKA SHIFT'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseShiftDialog extends StatefulWidget {
  final double expectedCash;
  final VoidCallback onConfirm;

  const _CloseShiftDialog({required this.expectedCash, required this.onConfirm});

  @override
  State<_CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends State<_CloseShiftDialog> {
  final _actualCashController = TextEditingController();
  double _difference = 0;

  void _calculateDifference(String val) {
    final actual = double.tryParse(val) ?? 0;
    setState(() {
      _difference = actual - widget.expectedCash;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tutup Shift'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Expected Cash'),
            trailing: Text('Rp ${widget.expectedCash}'),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          TextField(
            controller: _actualCashController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Actual Cash (Hitung Manual)', prefixText: 'Rp '),
            onChanged: _calculateDifference,
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Selisih'),
            trailing: Text(
              'Rp $_difference',
              style: TextStyle(
                color: _difference == 0
                    ? Colors.green
                    : (_difference > 0 ? Colors.blue : Colors.red),
                fontWeight: FontWeight.bold,
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('BATAL')),
        FilledButton(onPressed: widget.onConfirm, child: const Text('KONFIRMASI & TUTUP')),
      ],
    );
  }
}
