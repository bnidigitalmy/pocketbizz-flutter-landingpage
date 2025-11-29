import 'dart:io';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/stock_item.dart';

/// Stock Export/Import Utilities
/// Handles Excel & CSV export/import for Stock Management
class StockExportImport {
  /// Export stock items to Excel
  static Future<String> exportToExcel(List<StockItem> items) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Stock Items'];

    // Header row
    sheet.appendRow([
      const TextCellValue('Item Name'),
      const TextCellValue('Unit'),
      const TextCellValue('Package Size'),
      const TextCellValue('Purchase Price (RM)'),
      const TextCellValue('Current Quantity'),
      const TextCellValue('Low Stock Threshold'),
      const TextCellValue('Notes'),
    ]);

    // Data rows
    for (final item in items) {
      sheet.appendRow([
        TextCellValue(item.name),
        TextCellValue(item.unit),
        DoubleCellValue(item.packageSize),
        DoubleCellValue(item.purchasePrice),
        DoubleCellValue(item.currentQuantity),
        DoubleCellValue(item.lowStockThreshold),
        TextCellValue(item.notes ?? ''),
      ]);
    }

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final filename = 'stock-items-${DateTime.now().toIso8601String().split('T')[0]}.xlsx';
    final filePath = '${directory.path}/$filename';
    
    final fileBytes = excel.save();
    if (fileBytes != null) {
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      return filePath;
    }

    throw Exception('Failed to save Excel file');
  }

  /// Export stock items to CSV
  static Future<String> exportToCSV(List<StockItem> items) async {
    final List<List<dynamic>> rows = [];

    // Header row
    rows.add([
      'Item Name',
      'Unit',
      'Package Size',
      'Purchase Price (RM)',
      'Current Quantity',
      'Low Stock Threshold',
      'Notes',
    ]);

    // Data rows
    for (final item in items) {
      rows.add([
        item.name,
        item.unit,
        item.packageSize.toString(),
        item.purchasePrice.toString(),
        item.currentQuantity.toString(),
        item.lowStockThreshold.toString(),
        item.notes ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final filename = 'stock-items-${DateTime.now().toIso8601String().split('T')[0]}.csv';
    final filePath = '${directory.path}/$filename';
    
    final file = File(filePath);
    await file.writeAsString(csv);
    
    return filePath;
  }

  /// Download sample template
  static Future<String> downloadSampleTemplate() async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Stock Items'];

    // Header row
    sheet.appendRow([
      const TextCellValue('Item Name'),
      const TextCellValue('Unit'),
      const TextCellValue('Package Size'),
      const TextCellValue('Purchase Price (RM)'),
      const TextCellValue('Current Quantity'),
      const TextCellValue('Low Stock Threshold'),
      const TextCellValue('Notes'),
    ]);

    // Sample data rows
    sheet.appendRow([
      const TextCellValue('Tepung Gandum'),
      const TextCellValue('kg'),
      const DoubleCellValue(1.0),
      const DoubleCellValue(5.50),
      const DoubleCellValue(10.0),
      const DoubleCellValue(5.0),
      const TextCellValue('Sample item'),
    ]);

    sheet.appendRow([
      const TextCellValue('Gula Pasir'),
      const TextCellValue('kg'),
      const DoubleCellValue(1.0),
      const DoubleCellValue(3.20),
      const DoubleCellValue(8.0),
      const DoubleCellValue(3.0),
      const TextCellValue(''),
    ]);

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    const filename = 'stock-template.xlsx';
    final filePath = '${directory.path}/$filename';
    
    final fileBytes = excel.save();
    if (fileBytes != null) {
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      return filePath;
    }

    throw Exception('Failed to save template file');
  }

  /// Parse Excel file for import
  static Future<List<Map<String, dynamic>>> parseExcelFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final List<Map<String, dynamic>> items = [];
    
    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table]!;
      
      // Skip header row (index 0)
      for (int row = 1; row < sheet.maxRows; row++) {
        final rowData = sheet.row(row);
        
        // Skip empty rows
        if (rowData.isEmpty || rowData[0]?.value == null) continue;

        items.add({
          'name': rowData[0]?.value?.toString() ?? '',
          'unit': rowData[1]?.value?.toString() ?? '',
          'packageSize': _parseDouble(rowData[2]?.value),
          'purchasePrice': _parseDouble(rowData[3]?.value),
          'currentQuantity': _parseDouble(rowData[4]?.value),
          'lowStockThreshold': _parseDouble(rowData[5]?.value),
          'notes': rowData.length > 6 ? (rowData[6]?.value?.toString() ?? '') : '',
        });
      }
    }

    return items;
  }

  /// Parse CSV file for import
  static Future<List<Map<String, dynamic>>> parseCSVFile(String filePath) async {
    final file = File(filePath);
    final csvString = await file.readAsString();
    
    final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
    final List<Map<String, dynamic>> items = [];

    // Skip header row (index 0)
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      
      // Skip empty rows
      if (row.isEmpty || row[0].toString().trim().isEmpty) continue;

      items.add({
        'name': row[0].toString(),
        'unit': row[1].toString(),
        'packageSize': _parseDouble(row[2]),
        'purchasePrice': _parseDouble(row[3]),
        'currentQuantity': _parseDouble(row[4]),
        'lowStockThreshold': _parseDouble(row[5]),
        'notes': row.length > 6 ? row[6].toString() : '',
      });
    }

    return items;
  }

  /// Pick file using file picker
  static Future<String?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result != null && result.files.single.path != null) {
      return result.files.single.path!;
    }

    return null;
  }

  /// Validate import data
  static Map<String, dynamic> validateImportData(List<Map<String, dynamic>> data) {
    final List<String> errors = [];
    int validCount = 0;

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final rowNum = i + 2; // +2 because: +1 for index, +1 for header row

      // Validate name
      if (item['name'] == null || item['name'].toString().trim().isEmpty) {
        errors.add('Row $rowNum: Item Name diperlukan');
        continue;
      }

      // Validate unit
      if (item['unit'] == null || item['unit'].toString().trim().isEmpty) {
        errors.add('Row $rowNum: Unit diperlukan');
        continue;
      }

      // Validate numbers
      if (item['packageSize'] == null || item['packageSize'] <= 0) {
        errors.add('Row $rowNum: Package Size mesti nombor positif');
        continue;
      }

      if (item['purchasePrice'] == null || item['purchasePrice'] < 0) {
        errors.add('Row $rowNum: Purchase Price mesti nombor positif atau sifar');
        continue;
      }

      if (item['currentQuantity'] == null || item['currentQuantity'] < 0) {
        errors.add('Row $rowNum: Current Quantity mesti nombor positif atau sifar');
        continue;
      }

      if (item['lowStockThreshold'] == null || item['lowStockThreshold'] < 0) {
        errors.add('Row $rowNum: Low Stock Threshold mesti nombor positif atau sifar');
        continue;
      }

      validCount++;
    }

    return {
      'valid': errors.isEmpty,
      'errors': errors,
      'validCount': validCount,
      'totalCount': data.length,
    };
  }

  /// Parse double value from dynamic
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 0.0;
  }
}

