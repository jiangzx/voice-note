/// Preset account definitions for database seeding.
/// P1: hardcoded Chinese labels; replace with i18n keys in future.
class PresetAccount {
  final String name;
  final String type;
  final String icon;
  final String color;
  final int sortOrder;

  const PresetAccount({
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.sortOrder = 0,
  });
}

const defaultWalletAccount = PresetAccount(
  name: '钱包',
  type: 'cash',
  icon: 'material:account_balance_wallet',
  color: 'FF009688',
  sortOrder: 0,
);
