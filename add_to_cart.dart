
  Future<void> _addToCart(Product product) async {
    // Cek apakah produk ini memiliki varian
    final variants = await (appDb.select(appDb.productVariants)..where((t) => t.productId.equals(product.id))).get();

    if (variants.isEmpty) {
      _addDirectlyToCart(product.id, product.name, product.sellingPrice, null);
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Pilih Varian: ${product.name}"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: variants.map((v) => ListTile(
                  title: Text(v.name),
                  trailing: Text("Rp ${NumberFormat("#,###", "id_ID").format(v.price.toInt())}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _addDirectlyToCart(product.id, product.name, v.price, v.name);
                  },
                )).toList()
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL"))
              ]
            );
          }
        );
      }
    }
  }

  void _addDirectlyToCart(String prodId, String prodName, double price, String? variantName) {
    setState(() {
      final existingIndex = _cartItems.indexWhere((item) => item["id"] == prodId && item["variantName"] == variantName);
      if (existingIndex >= 0) {
        _cartItems[existingIndex]["qty"] += 1;
      } else {
        _cartItems.add({"id": prodId, "name": prodName, "price": price, "qty": 1, "variantName": variantName});
      }
    });
  }
