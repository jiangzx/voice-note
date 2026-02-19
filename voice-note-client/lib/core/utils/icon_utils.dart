import 'package:flutter/material.dart';

/// Parses an icon string of format `material:<name>` or `emoji:<char>`
/// into a [Widget].
Widget iconFromString(String iconStr, {double size = 24}) {
  if (iconStr.startsWith('material:')) {
    final name = iconStr.substring('material:'.length);
    final iconData = _materialIconMap[name];
    if (iconData != null) {
      return Icon(iconData, size: size);
    }
    return Icon(Icons.category, size: size);
  }
  if (iconStr.startsWith('emoji:')) {
    final emoji = iconStr.substring('emoji:'.length);
    return Text(emoji, style: TextStyle(fontSize: size));
  }
  return Icon(Icons.help_outline, size: size);
}

/// Subset of Material Icons used in preset categories and accounts.
const _materialIconMap = <String, IconData>{
  'restaurant': Icons.restaurant,
  'directions_bus': Icons.directions_bus,
  'shopping_bag': Icons.shopping_bag,
  'receipt_long': Icons.receipt_long,
  'sports_esports': Icons.sports_esports,
  'local_hospital': Icons.local_hospital,
  'school': Icons.school,
  'home': Icons.home,
  'card_giftcard': Icons.card_giftcard,
  'more_horiz': Icons.more_horiz,
  'pets': Icons.pets,
  'flight': Icons.flight,
  'account_balance': Icons.account_balance,
  'emoji_events': Icons.emoji_events,
  'work_outline': Icons.work_outline,
  'redeem': Icons.redeem,
  'account_balance_wallet': Icons.account_balance_wallet,
  'category': Icons.category,
  'devices': Icons.devices,
  'delivery_dining': Icons.delivery_dining,
};
