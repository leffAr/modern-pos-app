import 'dart:io';

void main() {
  final file = File('lib/features/dashboard/presentation/dashboard_screen.dart');
  String content = file.readAsStringSync();

  final oldGrid = """    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isMobile ? 1.3 : 2.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),""";

  final newGrid = """    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200), // Batasi lebar maksimal agar tidak terlalu raksasa di PC
        child: GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isMobile ? 1.3 : 2.8, // 2.8 agar kartu lebih pendek/kecil secara vertikal di PC/Tablet
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),""";
          
  if (content.contains(oldGrid)) {
    content = content.replaceFirst(oldGrid, newGrid);
    
    // Remember to add closing tags for Center and ConstrainedBox!
    // The GridView.count has `children: [ ... ]` then `);`
    final gridEnd = """        _SummaryCard(
            title: 'Laba Bersih',
            value: 'Rp \${formatter.format(netProfit.toInt())}',
            icon: Icons.account_balance_wallet,
            color: Colors.blue),
      ],
    );""";
    
    final newGridEnd = """        _SummaryCard(
            title: 'Laba Bersih',
            value: 'Rp \${formatter.format(netProfit.toInt())}',
            icon: Icons.account_balance_wallet,
            color: Colors.blue),
      ],
    ),
      ),
    );""";
    
    content = content.replaceFirst(gridEnd, newGridEnd);
    file.writeAsStringSync(content);
    print("SUCCESS: Added ConstrainedBox");
  } else {
    print("ERROR: Grid not found");
  }
}
