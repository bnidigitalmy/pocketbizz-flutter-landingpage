import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/stock_item.dart';

// Conditional imports
import 'dart:io' if (dart.library.html) '../services/io_stub.dart';
import 'package:path_provider/path_provider.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html if (dart.library.html) 'dart:html';

/// Stock Export/Import Utilities
/// Handles Excel & CSV export/import for Stock Management
class StockExportImport {
  /// Export stock items to Excel
  static Future<String> exportToExcel(List<StockItem> items) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Stock Items'];

    // Header row
    sheet.appendRow([
      TextCellValue('Item Name'),
      TextCellValue('Unit'),
      TextCellValue('Package Size'),
      TextCellValue('Purchase Price (RM)'),
      TextCellValue('Current Quantity'),
      TextCellValue('Low Stock Threshold'),
      TextCellValue('Notes'),
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

    final fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('Failed to save Excel file');
    }

    final filename = 'stock-items-${DateTime.now().toIso8601String().split('T')[0]}.xlsx';

    if (kIsWeb) {
      // Web: trigger browser download
      final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
      return 'Downloaded: $filename';
    } else {
      // Mobile/Desktop: save to file system
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      return filePath;
    }
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
    final filename = 'stock-items-${DateTime.now().toIso8601String().split('T')[0]}.csv';

    if (kIsWeb) {
      // Web: trigger browser download
      final csvBytes = Uint8List.fromList(csv.codeUnits);
      final blob = html.Blob([csvBytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
      return 'Downloaded: $filename';
    } else {
      // Mobile/Desktop: save to file system
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';
      final file = File(filePath);
      await file.writeAsString(csv);
      return filePath;
    }
  }

  /// Download sample template
  static Future<String> downloadSampleTemplate() async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Stock Items'];

    // Header row
    sheet.appendRow([
      TextCellValue('Item Name'),
      TextCellValue('Unit'),
      TextCellValue('Package Size'),
      TextCellValue('Purchase Price (RM)'),
      TextCellValue('Current Quantity'),
      TextCellValue('Low Stock Threshold'),
      TextCellValue('Notes'),
    ]);

    // Sample data rows
    sheet.appendRow([
      TextCellValue('Tepung Gandum'),
      TextCellValue('kg'),
      DoubleCellValue(1.0),
      DoubleCellValue(5.50),
      DoubleCellValue(10.0),
      DoubleCellValue(5.0),
      TextCellValue('Sample item'),
    ]);

    sheet.appendRow([
      TextCellValue('Gula Pasir'),
      TextCellValue('kg'),
      DoubleCellValue(1.0),
      DoubleCellValue(3.20),
      DoubleCellValue(8.0),
      DoubleCellValue(3.0),
      TextCellValue(''),
    ]);

    final fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('Failed to save template file');
    }

    const filename = 'stock-template.xlsx';

    if (kIsWeb) {
      // Web: trigger browser download
      final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
      return 'Downloaded: $filename';
    } else {
      // Mobile/Desktop: save to file system
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
      return filePath;
    }
  }

  /// Parse Excel file for import
  /// Accepts either file path (mobile) or bytes (web)
  static Future<List<Map<String, dynamic>>> parseExcelFile(dynamic fileInput) async {
    Uint8List bytes;
    
    if (fileInput is String) {
      // Mobile: read from file path
      final file = File(fileInput);
      bytes = await file.readAsBytes();
    } else if (fileInput is Uint8List) {
      // Web: use bytes directly
      bytes = fileInput;
    } else {
      throw Exception('Invalid file input type');
    }

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
  /// Accepts either file path (mobile) or bytes (web)
  static Future<List<Map<String, dynamic>>> parseCSVFile(dynamic fileInput) async {
    String csvString;
    
    if (fileInput is String) {
      // Mobile: read from file path
      final file = File(fileInput);
      csvString = await file.readAsString();
    } else if (fileInput is Uint8List) {
      // Web: convert bytes to string
      csvString = String.fromCharCodes(fileInput);
    } else {
      throw Exception('Invalid file input type');
    }
    
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
  /// Returns file path for mobile, or bytes for web
  static Future<Map<String, dynamic>?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: kIsWeb, // Get bytes for web
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    
    if (kIsWeb) {
      // Web: return bytes and filename
      if (file.bytes == null) {
        throw Exception('File bytes tidak tersedia');
      }
      return {
        'bytes': file.bytes!,
        'name': file.name,
        'extension': file.extension ?? '',
      };
    } else {
      // Mobile/Desktop: return file path
      if (file.path == null) {
        return null;
      }
      return {
        'path': file.path!,
        'name': file.name,
        'extension': file.extension ?? '',
      };
    }
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

