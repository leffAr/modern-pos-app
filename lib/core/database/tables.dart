import 'package:drift/drift.dart';

@DataClassName('Business')
class Businesses extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get logoBase64 => text().nullable()(); // Logo dalam bentuk base64
  RealColumn get taxPercentage => real().withDefault(const Constant(0.0))(); // Pajak PPN misal 11%
  BoolColumn get enableTableNumber => boolean().withDefault(const Constant(false))();
  BoolColumn get enableQueueNumber => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Branch')
class Branches extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get businessId => text().references(Businesses, #id)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get address => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Role')
class Roles extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text().withLength(min: 1, max: 50)(); // Admin, Manager, Cashier

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('User')
class Users extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get branchId => text().nullable().references(Branches, #id)();
  TextColumn get roleId => text().nullable().references(Roles, #id)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get password => text().nullable()(); // Password biasa (teks)
  TextColumn get pin => text().nullable()(); // hashed PIN for quick login

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyncItem')
class SyncQueue extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get entity => text()(); // table name e.g., 'transactions'
  TextColumn get action => text()(); // 'CREATE', 'UPDATE', 'DELETE'
  TextColumn get payload => text()(); // JSON string
  TextColumn get status => text().withDefault(const Constant('PENDING'))(); // 'PENDING', 'SYNCING', 'FAILED'
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// --- DATA MASTER TABLES ---

@DataClassName('Category')
class Categories extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Product')
class Products extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get businessId => text().references(Businesses, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get description => text().nullable()();
  TextColumn get imageBase64 => text().nullable()(); // Foto produk (base64)
  RealColumn get purchasePrice => real().withDefault(const Constant(0.0))();
  RealColumn get sellingPrice => real().withDefault(const Constant(0.0))();
  RealColumn get wholesalePrice => real().nullable()();
  IntColumn get wholesaleMinQty => integer().nullable()();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get deletedAt => dateTime().nullable()(); // Soft delete

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('InventoryItem')
class Inventory extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get branchId => text().references(Branches, #id)();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  IntColumn get minimumStock => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Customer')
class Customers extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get businessId => text().references(Businesses, #id)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  RealColumn get point => real().withDefault(const Constant(0.0))();
  RealColumn get debt => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DebtPayment')
class DebtPayments extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get customerId => text().references(Customers, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Supplier')
class Suppliers extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get businessId => text().references(Businesses, #id)();
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Promo')
class Promos extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text().withLength(min: 1, max: 255)();
  TextColumn get type => text()(); // 'percentage', 'fixed'
  RealColumn get value => real()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

// --- TRANSACTION TABLES ---

@DataClassName('Transaction')
class Transactions extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get branchId => text().references(Branches, #id)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get customerId => text().nullable().references(Customers, #id)();
  TextColumn get receiptNumber => text()();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get tax => real().withDefault(const Constant(0.0))();
  RealColumn get grandTotal => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('COMPLETED'))(); // COMPLETED, VOID, REFUNDED
  IntColumn get queueNumber => integer().nullable()(); // Nomor Antrian (Reset tiap hari)
  TextColumn get tableNumber => text().nullable()(); // Nomor Meja
  RealColumn get pointsEarned => real().withDefault(const Constant(0.0))();
  RealColumn get pointsUsed => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get dueDate => dateTime().nullable()(); // NEW: Tanggal Jatuh Tempo Kasbon
  TextColumn get discountNotes => text().nullable()(); // NEW: Keterangan diskon manual

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TransactionItem')
class TransactionItems extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get variantName => text().nullable()(); // NEW: Varian yang dipilih
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  RealColumn get price => real().withDefault(const Constant(0.0))();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ProductVariant')
class ProductVariants extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get name => text()(); // e.g. "Size M", "Panas"
  RealColumn get purchasePrice => real().withDefault(const Constant(0.0))();
  RealColumn get price => real()();
  
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Payment')
class Payments extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get method => text().withDefault(const Constant('CASH'))(); // CASH, QRIS, DEBIT
  RealColumn get amount => real().withDefault(const Constant(0.0))();
  RealColumn get changeAmount => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

// --- SHIFT & OPERATIONAL TABLES ---

@DataClassName('Shift')
class Shifts extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get branchId => text().references(Branches, #id)();
  TextColumn get userId => text().references(Users, #id)();
  RealColumn get openingCash => real().withDefault(const Constant(0.0))();
  RealColumn get closingCash => real().nullable()();
  RealColumn get expectedCash => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('OPEN'))(); // OPEN, CLOSED
  TextColumn get shiftName => text().withDefault(const Constant('Shift 1'))(); // e.g. Shift 1, Shift 2
  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get closedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Expense')
class Expenses extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get branchId => text().references(Branches, #id)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get category => text()(); // e.g. Listrik, Operasional
  RealColumn get amount => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Purchase')
class Purchases extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get branchId => text().references(Branches, #id)();
  TextColumn get supplierId => text().references(Suppliers, #id)();
  TextColumn get referenceNumber => text()();
  RealColumn get total => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('COMPLETED'))(); // PENDING, COMPLETED
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PurchaseItem')
class PurchaseItems extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get purchaseId => text().references(Purchases, #id)();
  TextColumn get productId => text().references(Products, #id)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  RealColumn get cost => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Return')
class Returns extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get reason => text()();
  RealColumn get amountRefunded => real().withDefault(const Constant(0.0))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName("StockOpname")
class StockOpnames extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get branchId => text().references(Branches, #id)();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get status => text().withDefault(const Constant("COMPLETED"))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName("StockOpnameItem")
class StockOpnameItems extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get opnameId => text().references(StockOpnames, #id)();
  TextColumn get productId => text().references(Products, #id)();
  IntColumn get systemStock => integer()();
  IntColumn get actualStock => integer()();
  IntColumn get variance => integer()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
