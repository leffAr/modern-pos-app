import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Stream<List<Category>> _categoriesStream;

  // Daftar warna dan ikon untuk dipilih
  final List<Color> _colorOptions = [
    Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple,
    Colors.teal, Colors.pink, Colors.indigo, Colors.amber, Colors.cyan,
    Colors.brown, Colors.deepOrange,
  ];

  final List<IconData> _iconOptions = [
    // Makanan & Minuman
    Icons.fastfood, Icons.local_drink, Icons.local_cafe, Icons.restaurant,
    Icons.cake, Icons.icecream, Icons.liquor, Icons.egg, Icons.rice_bowl, Icons.bento,
    // Toko Kelontong / Retail Umum
    Icons.storefront, Icons.local_grocery_store, Icons.shopping_bag, Icons.shopping_cart, 
    Icons.inventory, Icons.qr_code,
    // Pakaian & Fashion
    Icons.checkroom, Icons.dry_cleaning, Icons.diamond, Icons.watch,
    // Elektronik & Gadget
    Icons.phone_android, Icons.laptop, Icons.headphones, Icons.camera_alt, Icons.tv,
    // Jasa & Tukang / Bangunan
    Icons.build, Icons.hardware, Icons.format_paint, Icons.electrical_services,
    // Kendaraan & Bengkel
    Icons.two_wheeler, Icons.directions_car, Icons.local_gas_station,
    // Kesehatan & Apotek
    Icons.local_pharmacy, Icons.medication, Icons.spa,
    // Hobi, Olahraga, Hiburan
    Icons.sports_esports, Icons.fitness_center, Icons.sports_soccer, Icons.music_note, Icons.toys,
    // Alat Tulis & Percetakan
    Icons.book, Icons.print, Icons.school,
    // Rumah Tangga, Mebel, Laundry
    Icons.home, Icons.chair, Icons.weekend, Icons.local_laundry_service, Icons.cleaning_services,
    // Lain-lain
    Icons.pets, Icons.agriculture, Icons.brush, Icons.card_giftcard,
  ];

  @override
  void initState() {
    super.initState();
    _categoriesStream = appDb.select(appDb.categories).watch();
  }

  void _showAddEditDialog([Category? category]) {
    final nameCtrl = TextEditingController(text: category?.name);
    int selectedColorIndex = category?.color != null
        ? int.tryParse(category!.color!) ?? 0
        : 0;
    int selectedIconIndex = category?.icon != null
        ? int.tryParse(category!.icon!) ?? 0
        : 0;
    bool isActive = category?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? 'Tambah Kategori' : 'Edit Kategori'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama Kategori
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kategori *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Pilih Warna
                  const Text('Pilih Warna:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_colorOptions.length, (i) {
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColorIndex = i),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _colorOptions[i],
                            shape: BoxShape.circle,
                            border: selectedColorIndex == i
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                          child: selectedColorIndex == i
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Pilih Ikon
                  const Text('Pilih Ikon:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_iconOptions.length, (i) {
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIconIndex = i),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: selectedIconIndex == i
                                ? _colorOptions[selectedColorIndex].withOpacity(0.2)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: selectedIconIndex == i
                                ? Border.all(color: _colorOptions[selectedColorIndex], width: 2)
                                : null,
                          ),
                          child: Icon(
                            _iconOptions[i],
                            color: selectedIconIndex == i
                                ? _colorOptions[selectedColorIndex]
                                : Colors.grey,
                            size: 22,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Preview
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _colorOptions[selectedColorIndex],
                          child: Icon(_iconOptions[selectedIconIndex], color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          nameCtrl.text.isNotEmpty ? nameCtrl.text : 'Preview Kategori',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Status
                  SwitchListTile(
                    title: const Text('Kategori Aktif'),
                    value: isActive,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDialogState(() => isActive = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
            FilledButton.icon(
              icon: Icon(category == null ? Icons.add : Icons.save),
              onPressed: () async {
                if (nameCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama kategori wajib diisi!')),
                  );
                  return;
                }

                if (category == null) {
                  await appDb.into(appDb.categories).insert(
                    CategoriesCompanion.insert(
                      id: 'CAT-${DateTime.now().millisecondsSinceEpoch}',
                      name: nameCtrl.text,
                      icon: drift.Value(selectedIconIndex.toString()),
                      color: drift.Value(selectedColorIndex.toString()),
                      isActive: drift.Value(isActive),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori berhasil ditambahkan!')));
                } else {
                  await (appDb.update(appDb.categories)..where((t) => t.id.equals(category.id))).write(
                    CategoriesCompanion(
                      name: drift.Value(nameCtrl.text),
                      icon: drift.Value(selectedIconIndex.toString()),
                      color: drift.Value(selectedColorIndex.toString()),
                      isActive: drift.Value(isActive),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori berhasil diperbarui!')));
                }

                Navigator.pop(context);
              },
              label: Text(category == null ? 'SIMPAN' : 'PERBARUI'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteCategory(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: Text('Anda yakin ingin menghapus kategori "${category.name}"?\nProduk dalam kategori ini tidak akan terhapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('BATAL')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await (appDb.delete(appDb.categories)..where((t) => t.id.equals(category.id))).go();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori dihapus')));
    }
  }

  // Helper untuk mengambil warna & ikon dari index string
  Color _getColor(String? colorIndex) {
    final idx = int.tryParse(colorIndex ?? '0') ?? 0;
    return idx < _colorOptions.length ? _colorOptions[idx] : Colors.blue;
  }

  IconData _getIcon(String? iconIndex) {
    final idx = int.tryParse(iconIndex ?? '0') ?? 0;
    return idx < _iconOptions.length ? _iconOptions[idx] : Icons.category;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori Produk'),
      ),
      body: StreamBuilder<List<Category>>(
        stream: _categoriesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data ?? [];

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Belum Ada Kategori', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text('Tambahkan kategori untuk mengelompokkan produk Anda.', style: TextStyle(color: Colors.grey.shade400)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showAddEditDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Kategori Pertama'),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 250,
              childAspectRatio: 1.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final color = _getColor(cat.color);
              final icon = _getIcon(cat.icon);

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showAddEditDialog(cat),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CircleAvatar(
                              backgroundColor: color,
                              child: Icon(icon, color: Colors.white, size: 22),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: Colors.grey.shade400, size: 20),
                              onSelected: (val) {
                                if (val == 'edit') _showAddEditDialog(cat);
                                if (val == 'delete') _deleteCategory(cat);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Edit')])),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))])),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: cat.isActive ? Colors.green.shade100 : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                cat.isActive ? 'Aktif' : 'Nonaktif',
                                style: TextStyle(fontSize: 11, color: cat.isActive ? Colors.green.shade700 : Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kategori'),
      ),
    );
  }
}
