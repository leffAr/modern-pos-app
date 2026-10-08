import 'dart:io';

void main() {
  final file = File('lib/features/dashboard/presentation/dashboard_screen.dart');
  String content = file.readAsStringSync();

  final oldStokTipis = """
                                      _buildQuickActionIcon(
                                        context: context,
                                        icon: Icons.warning_amber_rounded,
                                        color: Colors.red,
                                        title: 'Stok Tipis',
                                        onTap: () {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (context) =>
                                                _buildBottomSheetLayout(
                                                    context,
                                                    'Peringatan Stok Tipis',
                                                    _buildLowStockAlert()),
                                          );
                                        },
                                      ),""";
                                      
  final newStokTipis = """
                                      StreamBuilder<List<drift.TypedResult>>(
                                        stream: _lowStockStream,
                                        builder: (context, snapshot) {
                                          final lowStockCount = snapshot.hasData ? snapshot.data!.length : 0;
                                          if (snapshot.hasData) {
                                            _checkLowStockNotification(lowStockCount);
                                          }
                                          
                                          return _buildQuickActionIcon(
                                            context: context,
                                            icon: Icons.warning_amber_rounded,
                                            color: Colors.red,
                                            title: 'Stok Tipis',
                                            badge: lowStockCount > 0 
                                              ? Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Text(
                                                    '\$lowStockCount',
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                )
                                              : null,
                                            onTap: () {
                                              showModalBottomSheet(
                                                context: context,
                                                isScrollControlled: true,
                                                backgroundColor: Colors.transparent,
                                                builder: (context) =>
                                                    _buildBottomSheetLayout(
                                                        context,
                                                        'Peringatan Stok Tipis',
                                                        _buildLowStockAlert()),
                                              );
                                            },
                                          );
                                        }
                                      ),""";

  if (content.contains("title: 'Stok Tipis',")) {
    content = content.replaceFirst(oldStokTipis, newStokTipis);
    file.writeAsStringSync(content);
    print("Success");
  } else {
    print("Failed");
  }
}
