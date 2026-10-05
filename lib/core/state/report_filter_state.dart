import 'package:flutter/material.dart';

class ReportFilterState extends ChangeNotifier {
  static final ReportFilterState instance = ReportFilterState._internal();
  ReportFilterState._internal();

  String _filter = 'Hari Ini';
  DateTimeRange? _customRange;

  String get currentFilter => _filter;
  DateTimeRange? get customRange => _customRange;

  static const List<String> availableFilters = [
    'Hari Ini',
    'Kemarin',
    '7 Hari Terakhir',
    '30 Hari Terakhir',
    'Semua Waktu',
  ];

  void setFilter(String filter) {
    _filter = filter;
    _customRange = null;
    notifyListeners();
  }

  void setCustomRange(DateTimeRange range) {
    _filter = 'Kustom';
    _customRange = range;
    notifyListeners();
  }

  /// Menghasilkan DateTimeRange untuk query filter database.
  /// Jika 'Semua Waktu', mengembalikan null.
  DateTimeRange? get dateRange {
    final now = DateTime.now();
    if (_filter == 'Hari Ini') {
      final today = DateTime(now.year, now.month, now.day);
      return DateTimeRange(start: today, end: today);
    } else if (_filter == 'Kemarin') {
      final y = now.subtract(const Duration(days: 1));
      final yesterday = DateTime(y.year, y.month, y.day);
      return DateTimeRange(start: yesterday, end: yesterday);
    } else if (_filter == '7 Hari Terakhir') {
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      final end = DateTime(now.year, now.month, now.day);
      return DateTimeRange(start: start, end: end);
    } else if (_filter == '30 Hari Terakhir') {
      final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
      final end = DateTime(now.year, now.month, now.day);
      return DateTimeRange(start: start, end: end);
    } else if (_filter == 'Kustom' && _customRange != null) {
      return DateTimeRange(
        start: DateTime(_customRange!.start.year, _customRange!.start.month, _customRange!.start.day),
        end: DateTime(_customRange!.end.year, _customRange!.end.month, _customRange!.end.day),
      );
    } else {
      // 'Semua Waktu'
      return null;
    }
  }

  /// Label ringkas untuk ditampilkan pada tombol atau dropdown.
  String get displayLabel {
    if (_filter == 'Kustom' && _customRange != null) {
      return '${_customRange!.start.day}/${_customRange!.start.month} - ${_customRange!.end.day}/${_customRange!.end.month}';
    }
    return _filter;
  }
}
