// Stub file for web platform
// This provides a minimal File interface that is never actually used
// since we check kIsWeb before using File

import 'dart:typed_data';

class File {
  final String path;
  File(this.path);
  
  // Stub methods - never called on web (kIsWeb check prevents this)
  Future<void> writeAsBytes(List<int> bytes) async {
    throw UnimplementedError('File.writeAsBytes not available on web');
  }
  
  Future<void> writeAsString(String contents) async {
    throw UnimplementedError('File.writeAsString not available on web');
  }
  
  Future<Uint8List> readAsBytes() async {
    throw UnimplementedError('File.readAsBytes not available on web');
  }
  
  Future<String> readAsString() async {
    throw UnimplementedError('File.readAsString not available on web');
  }
}

