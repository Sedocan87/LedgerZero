import 'package:share_plus/share_plus.dart';

void main() async {
  await SharePlus.instance.share(
    ShareParams(text: 'hello', files: [XFile('path')]),
  );
}
