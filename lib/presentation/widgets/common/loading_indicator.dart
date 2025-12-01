import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ledger_zero/presentation/widgets/common/platform_widget.dart';

class LoadingIndicator extends PlatformWidget {
  const LoadingIndicator({super.key});

  @override
  Widget buildCupertinoWidget(BuildContext context) {
    return const Center(child: CupertinoActivityIndicator());
  }

  @override
  Widget buildMaterialWidget(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
