import 'dart:io';

void main() {
  final file = File('lib/features/dashboard/presentation/dashboard_screen.dart');
  String content = file.readAsStringSync();
  
  // Use RegExp to find the block
  final regex = RegExp(r"                                      _buildQuickActionIcon\(\s*context: context,\s*icon: Icons\.warning_amber_rounded,\s*color: Colors\.red,\s*title: 'Stok Tipis',[\s\S]*?_buildLowStockAlert\(\)\),\s*\);\s*},\s*\),");
  
  if (regex.hasMatch(content)) {
    final newBlock = """                                      StreamBuilder<List<drift.TypedResult>>(
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
    
    content = content.replaceFirst(regex, newBlock);
    file.writeAsStringSync(content);
    print("SUCCESS");
  } else {
    print("FAILED");
  }
}
