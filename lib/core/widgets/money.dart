import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _group = NumberFormat('#,##0', 'en_US');

/// 11500 → «11 500 so‘m».
String formatMoney(num amount) =>
    '${_group.format(amount.round()).replaceAll(',', ' ')} so‘m';

class Money extends StatelessWidget {
  const Money(this.amount, {super.key, this.style});

  final num amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(formatMoney(amount), style: style);
}
