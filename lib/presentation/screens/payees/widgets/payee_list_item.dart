import 'package:flutter/material.dart';
import 'package:ledger_zero/core/constants/category_constants.dart';
import 'package:ledger_zero/domain/entities/payee.dart';

class PayeeListItem extends StatelessWidget {
  final Payee payee;
  final VoidCallback onTap;

  const PayeeListItem({super.key, required this.payee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: payee.color != null ? Color(payee.color!) : null,
        child: payee.icon != null
            ? Icon(
                categoryIcons[payee.icon] ?? Icons.category,
                color: Colors.white,
              )
            : Text(
                payee.name.isNotEmpty
                    ? payee.name.characters.first.toUpperCase()
                    : '?',
              ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(payee.name)),
          if (payee.isFavorite)
            const Icon(Icons.star, size: 16, color: Colors.amber),
        ],
      ),
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
