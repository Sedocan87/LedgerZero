// Web implementation - Mocks dart:io classes used in the app

class File {
  final String path;
  File(this.path);

  Future<bool> exists() async => false;
  Future<void> delete() async {}
  Future<void> rename(String newPath) async {}
  Future<File> copy(String newPath) async => File(newPath);
  Future<List<int>> readAsBytes() async => [];
  Future<void> writeAsBytes(List<int> bytes) async {}

  // Add other methods as needed
}

class Directory {
  final String path;
  Directory(this.path);

  Future<bool> exists() async => false;
  Future<void> create({bool recursive = false}) async {}
}

Future<Directory> getApplicationDocumentsDirectory() async {
  return Directory('');
}

Future<Directory> getTemporaryDirectory() async {
  return Directory('');
}

void exit(int code) {
  // no-op on web
}

class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isLinux => false;
  static bool get isFuchsia => false;
}
