import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:ledger_zero/core/utils/text_decoding.dart';

/// Reading files returned by [FilePicker], independent of whether the
/// platform handed back a local path or only a content URI.
extension PickedFileReading on PlatformFile {
  /// The file decoded as UTF-8 (a byte order mark is dropped). With
  /// [windows1252Fallback], bytes that are not valid UTF-8 are decoded as
  /// Windows-1252 instead of throwing (see [decodeText]).
  Future<String> readAsText({bool windows1252Fallback = false}) async =>
      decodeText(await readAsBytes(), windows1252Fallback: windows1252Fallback);

  /// A file on local disk with this file's content: the picked file itself
  /// when the picker returned a path, otherwise a copy in the temporary
  /// directory.
  Future<File> toLocalFile() async {
    final localPath = path;
    if (localPath != null) {
      return File(localPath);
    }
    final dir = await getTemporaryDirectory();
    final copy = File(p.join(dir.path, 'picked_${p.basename(name)}'));
    return copy.writeAsBytes(await readAsBytes(), flush: true);
  }
}
