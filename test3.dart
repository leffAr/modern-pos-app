import 'package:drift/drift.dart';

void main() {
  final exp = CustomExpression<bool>('inventory.stock <= inventory.minimum_stock');
  print(exp);
}
