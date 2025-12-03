import 'package:flutter/material.dart';
import 'package:ledger_zero/domain/entities/payee.dart';

class PayeeListItem extends StatelessWidget {
  final Payee payee;
  final VoidCallback onTap;

  const PayeeListItem({
    super.key,
    required this.payee,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(payee.name.isNotEmpty ? payee.name.characters.first.toUpperCase() : '?'),
      ),
      title: Text(payee.name),
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
