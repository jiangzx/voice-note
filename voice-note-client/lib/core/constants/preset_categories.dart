/// Preset category definitions for database seeding.
/// P1: hardcoded Chinese labels; replace with i18n keys in future.
class PresetCategory {
  final String name;
  final String type; // expense | income
  final String icon;
  final String color; // ARGB hex without #
  final bool isHidden;
  final int sortOrder;

  const PresetCategory({
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.isHidden = false,
    required this.sortOrder,
  });
}

const presetExpenseCategories = <PresetCategory>[
  PresetCategory(
    name: '餐饮',
    type: 'expense',
    icon: 'material:restaurant',
    color: 'FFEF5350',
    sortOrder: 0,
  ),
  PresetCategory(
    name: '交通',
    type: 'expense',
    icon: 'material:directions_bus',
    color: 'FF42A5F5',
    sortOrder: 1,
  ),
  PresetCategory(
    name: '购物',
    type: 'expense',
    icon: 'material:shopping_bag',
    color: 'FFAB47BC',
    sortOrder: 2,
  ),
  PresetCategory(
    name: '账单',
    type: 'expense',
    icon: 'material:receipt_long',
    color: 'FF78909C',
    sortOrder: 3,
  ),
  PresetCategory(
    name: '娱乐',
    type: 'expense',
    icon: 'material:sports_esports',
    color: 'FFFFB74D',
    sortOrder: 4,
  ),
  PresetCategory(
    name: '医疗',
    type: 'expense',
    icon: 'material:local_hospital',
    color: 'FFEC407A',
    sortOrder: 5,
  ),
  PresetCategory(
    name: '教育',
    type: 'expense',
    icon: 'material:school',
    color: 'FF5C6BC0',
    sortOrder: 6,
  ),
  PresetCategory(
    name: '住房',
    type: 'expense',
    icon: 'material:home',
    color: 'FF8D6E63',
    sortOrder: 7,
  ),
  PresetCategory(
    name: '人情往来',
    type: 'expense',
    icon: 'material:card_giftcard',
    color: 'FFFF7043',
    sortOrder: 8,
  ),
  PresetCategory(
    name: '其他',
    type: 'expense',
    icon: 'material:more_horiz',
    color: 'FF90A4AE',
    sortOrder: 9,
  ),
  // Initially hidden
  PresetCategory(
    name: '宠物',
    type: 'expense',
    icon: 'material:pets',
    color: 'FFA1887F',
    sortOrder: 10,
    isHidden: true,
  ),
  PresetCategory(
    name: '旅行',
    type: 'expense',
    icon: 'material:flight',
    color: 'FF4DB6AC',
    sortOrder: 11,
    isHidden: true,
  ),
  PresetCategory(
    name: '转出',
    type: 'expense',
    icon: 'material:arrow_upward',
    color: 'FF78909C',
    sortOrder: 12,
  ),
];

const presetIncomeCategories = <PresetCategory>[
  PresetCategory(
    name: '工资',
    type: 'income',
    icon: 'material:account_balance',
    color: 'FF66BB6A',
    sortOrder: 0,
  ),
  PresetCategory(
    name: '奖金',
    type: 'income',
    icon: 'material:emoji_events',
    color: 'FFFFD54F',
    sortOrder: 1,
  ),
  PresetCategory(
    name: '兼职',
    type: 'income',
    icon: 'material:work_outline',
    color: 'FF4FC3F7',
    sortOrder: 2,
  ),
  PresetCategory(
    name: '红包',
    type: 'income',
    icon: 'material:redeem',
    color: 'FFFF8A65',
    sortOrder: 3,
  ),
  PresetCategory(
    name: '其他',
    type: 'income',
    icon: 'material:more_horiz',
    color: 'FF90A4AE',
    sortOrder: 4,
  ),
  PresetCategory(
    name: '转入',
    type: 'income',
    icon: 'material:arrow_downward',
    color: 'FF66BB6A',
    sortOrder: 5,
  ),
];

const allPresetCategories = [
  ...presetExpenseCategories,
  ...presetIncomeCategories,
];
