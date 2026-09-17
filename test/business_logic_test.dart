import 'package:flutter_test/flutter_test.dart';

void main() {
  group('POS Business Logic Calculations', () {
    test('Calculate Subtotal correctly', () {
      final cartItems = [
        {'name': 'Produk A', 'price': 10000.0, 'qty': 2},
        {'name': 'Produk B', 'price': 15000.0, 'qty': 1},
      ];

      final subtotal = cartItems.fold(0.0, (sum, item) {
        final price = item['price'] as double;
        final qty = item['qty'] as int;
        return sum + (price * qty);
      });

      expect(subtotal, 35000.0);
    });

    test('Calculate Tax (PPN 11%) correctly', () {
      const subtotal = 35000.0;
      final tax = subtotal * 0.11;

      expect(tax, 3850.0);
    });

    test('Calculate Grand Total correctly', () {
      const subtotal = 35000.0;
      const tax = 3850.0;
      final grandTotal = subtotal + tax;

      expect(grandTotal, 38850.0);
    });

    test('Calculate Change (Kembalian) correctly', () {
      const grandTotal = 38850.0;
      const paidAmount = 50000.0;
      final change = paidAmount - grandTotal;

      expect(change, 11150.0);
    });

    test('Calculate Change with exact amount should be 0', () {
      const grandTotal = 38850.0;
      const paidAmount = 38850.0;
      final change = paidAmount - grandTotal;

      expect(change, 0.0);
    });

    test('Change should be negative if paid amount is insufficient', () {
      const grandTotal = 38850.0;
      const paidAmount = 30000.0;
      final change = paidAmount - grandTotal;

      expect(change, lessThan(0.0));
      expect(change, -8850.0);
    });
  });
}
