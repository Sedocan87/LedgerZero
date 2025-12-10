import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

void main() async {
  await SharePlus.instance.share(
    ShareParams(
      text: 'hello',
      files: [XFile('path')],
    ),
  );
}
