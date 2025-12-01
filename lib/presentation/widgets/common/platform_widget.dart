import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

abstract class PlatformWidget extends StatelessWidget {
  const PlatformWidget({super.key});

  Widget buildCupertinoWidget(BuildContext context);
  Widget buildMaterialWidget(BuildContext context);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return buildMaterialWidget(context);
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return buildCupertinoWidget(context);
    }
    return buildMaterialWidget(context);
  }
}
