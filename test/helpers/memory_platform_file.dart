import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';

/// An in-memory [PlatformFile], standing in for a file the user picked.
final class MemoryPlatformFile extends PlatformFile {
  MemoryPlatformFile({required this.name, required List<int> bytes})
    : _bytes = Uint8List.fromList(bytes);

  @override
  final String name;

  final Uint8List _bytes;

  @override
  Uri get uri => Uri.parse('memory:///$name');

  @override
  XFile get xFile => XFile.fromData(_bytes, name: name);

  @override
  int? lengthSync() => _bytes.length;

  @override
  Future<int?> length() async => _bytes.length;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(_bytes);
}
