import 'dart:io';

void main() {
  final file = File('lib/features/settings/presentation/store_settings_screen.dart');
  String content = file.readAsStringSync();
  
  if (content.contains('String? _qrisBase64;')) {
    print("Already added");
    return;
  }

  // 1. Add _qrisBase64 state
  content = content.replaceFirst(
    'String? _logoBase64;',
    'String? _logoBase64;\n  String? _qrisBase64;'
  );

  // 2. Load from db
  content = content.replaceFirst(
    '_logoBase64 = business.logoBase64;',
    '_logoBase64 = business.logoBase64;\n          _qrisBase64 = business.qrisBase64;'
  );

  // 3. Save to db (insert)
  content = content.replaceFirst(
    'logoBase64: drift.Value(_logoBase64),',
    'logoBase64: drift.Value(_logoBase64),\n                  qrisBase64: drift.Value(_qrisBase64),'
  );

  // 4. Save to db (update)
  content = content.replaceFirst(
    'logoBase64: drift.Value(_logoBase64),',
    'logoBase64: drift.Value(_logoBase64),\n              qrisBase64: drift.Value(_qrisBase64),'
  );

  // 5. Add _pickQris
  content = content.replaceFirst(
    'Future<void> _pickLogo() async {',
    '''
  bool _isProcessingQris = false;
  Future<void> _pickQris() async {
    try {
      final base64 = await WebImagePicker.pickImageAsBase64();
      if (base64 != null) {
        setState(() {
          _qrisBase64 = base64;
          _isProcessingQris = false;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessingQris = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memproses QRIS: \$e')));
    }
  }

  Future<void> _pickLogo() async {'''
  );

  // 6. Add _buildQrisPicker method
  content = content.replaceFirst(
    'Widget _buildFormFields() {',
    '''
  Widget _buildQrisPicker() {
    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: _pickQris,
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
                      child: _isProcessingQris 
                          ? const Center(child: CircularProgressIndicator())
                          : _qrisBase64 != null
                          ? Image.memory(base64Decode(_qrisBase64!), fit: BoxFit.contain, filterQuality: FilterQuality.high)
                          : const Icon(Icons.qr_code_2, size: 60, color: Colors.blue),
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
                        'Upload QRIS',
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
        if (_qrisBase64 != null) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _qrisBase64 = null),
              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
              label: const Text('Hapus QRIS', style: TextStyle(color: Colors.red)),
            ),
          )
        ],
      ],
    );
  }

  Widget _buildFormFields() {'''
  );

  // 7. Inject into UI
  content = content.replaceFirst(
    '_buildLogoPicker(),',
    '_buildLogoPicker(),\n                                const SizedBox(height: 24),\n                                _buildQrisPicker(),'
  );
  content = content.replaceFirst(
    '_buildLogoPicker(),', // wait there are two calls of _buildLogoPicker() (one for isWide, one for mobile)
    '_buildLogoPicker(),\n                          const SizedBox(height: 24),\n                          _buildQrisPicker(),'
  );

  file.writeAsStringSync(content);
}
