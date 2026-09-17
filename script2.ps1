
$code = @"
  Future<void> _showAddExpenseDialog([Expense? expense]) async {
    final amountCtrl = TextEditingController(text: expense != null ? expense.amount.toInt().toString() : '');
    final notesCtrl = TextEditingController(text: expense?.notes ?? '');
    
    String rawCategory = expense?.category ?? 'Operasional';
    String selectedCategory = rawCategory;
    String? selectedEmployee;

    if (rawCategory.startsWith('Gaji - ')) {
       selectedCategory = 'Gaji';
       selectedEmployee = rawCategory.substring(7);
    }

    // Ambil data kasir/karyawan dari database untuk kategori Gaji
    final users = await appDb.select(appDb.users).get();
    final employeeNames = users.map((u) => u.name).toList();
    
    if (employeeNames.isNotEmpty && selectedEmployee == null) {
       selectedEmployee = employeeNames.first;
    }

    final categories = ['Listrik', 'Air', 'Gaji', 'Bahan Baku', 'Operasional', 'Lainnya'];
    if (!categories.contains(selectedCategory)) {
        categories.add(selectedCategory);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(expense == null ? 'Tambah Pengeluaran' : 'Edit Pengeluaran'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                      items: categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                           selectedCategory = val!;
                        });
                      },
                    ),
                    if (selectedCategory == 'Gaji' && employeeNames.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: employeeNames.contains(selectedEmployee) ? selectedEmployee : employeeNames.first,
                        decoration: const InputDecoration(labelText: 'Pilih Karyawan', border: OutlineInputBorder()),
                        items: employeeNames.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) {
                          setDialogState(() => selectedEmployee = val!);
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Nominal (Rp)', prefixText: 'Rp ', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Catatan', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
                FilledButton(
                  onPressed: () async {
                    if (amountCtrl.text.isEmpty) return;
                    
                    final amount = double.tryParse(amountCtrl.text.replaceAll('.', '')) ?? 0.0;
                    if (amount <= 0) return;

                    String finalCategory = selectedCategory;
                    if (selectedCategory == 'Gaji' && selectedEmployee != null) {
                       finalCategory = 'Gaji - $selectedEmployee';
                    }

                    final business = await (appDb.select(appDb.businesses)..limit(1)).getSingleOrNull();
                    final branchId = 'BRANCH-1'; // Default
                    final userId = 'USR-DEFAULT-ADMIN'; // Fallback if real user id is needed, though we just store user name for display

                    if (expense == null) {
                      await appDb.into(appDb.expenses).insert(
                        ExpensesCompanion.insert(
                          id: 'EXP-' + DateTime.now().millisecondsSinceEpoch.toString(),
                          branchId: branchId,
                          userId: userId,
                          category: finalCategory,
                          amount: drift.Value(amount),
                          notes: drift.Value(notesCtrl.text),
                          date: drift.Value(DateTime.now()),
                        )
                      );
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengeluaran dicatat!')));
                    } else {
                      await (appDb.update(appDb.expenses)..where((tbl) => tbl.id.equals(expense.id))).write(
                        ExpensesCompanion(
                          category: drift.Value(finalCategory),
                          amount: drift.Value(amount),
                          notes: drift.Value(notesCtrl.text),
                        )
                      );
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengeluaran diperbarui!')));
                    }
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('SIMPAN'),
                ),
              ],
            );
          }
        );
      },
    );
  }
"@
Set-Content -Path script2.ps1 -Value $code
