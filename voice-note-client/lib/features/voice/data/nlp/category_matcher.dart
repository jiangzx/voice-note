/// Matches keywords in text to predefined or custom category names.
class CategoryMatcher {
  /// Default keyword-to-category mapping (from PRD).
  static const _defaultMappings = <String, String>{
    // 餐饮
    '吃饭': '餐饮', '午餐': '餐饮', '午饭': '餐饮', '晚餐': '餐饮', '晚饭': '餐饮',
    '早餐': '餐饮', '早饭': '餐饮', '外卖': '餐饮', '奶茶': '餐饮', '咖啡': '餐饮',
    '饮料': '餐饮', '夜宵': '餐饮', '小吃': '餐饮', '火锅': '餐饮', '烧烤': '餐饮',
    '日料': '餐饮', '西餐': '餐饮', '快餐': '餐饮', '食堂': '餐饮', '点餐': '餐饮',
    // 交通
    '打车': '交通', '出租车': '交通', '地铁': '交通', '公交': '交通', '加油': '交通',
    '停车': '交通', '高铁': '交通', '火车': '交通', '机票': '交通', '滴滴': '交通',
    '骑车': '交通', '共享单车': '交通',
    // 购物
    '淘宝': '购物', '京东': '购物', '拼多多': '购物', '买了': '购物', '网购': '购物',
    '超市': '购物', '衣服': '购物', '鞋': '购物',
    // 账单
    '电费': '账单', '水费': '账单', '燃气': '账单', '物业': '账单',
    '话费': '账单', '流量': '账单', '宽带': '账单', '保险': '账单', '通讯': '账单',
    // 娱乐
    '电影': '娱乐', '游戏': '娱乐', 'KTV': '娱乐', '演出': '娱乐',
    '健身': '娱乐', '运动': '娱乐', '唱歌': '娱乐',
    // 医疗
    '看病': '医疗', '药': '医疗', '体检': '医疗', '挂号': '医疗', '医院': '医疗',
    // 教育
    '学费': '教育', '课程': '教育', '培训': '教育', '书': '教育', '考试': '教育',
    // 住房
    '房租': '住房', '月供': '住房', '房贷': '住房', '租金': '住房',
    // 人情往来
    '红包': '人情往来', '份子钱': '人情往来', '礼物': '人情往来', '请客': '人情往来',
    // 收入分类
    '工资': '工资', '薪水': '工资', '发工资': '工资',
    '奖金': '奖金', '年终奖': '奖金',
    '兼职': '兼职', '副业': '兼职',
    '收红包': '红包',
  };

  final Map<String, String> _mappings;

  /// Create a matcher with default + optional custom mappings.
  CategoryMatcher({List<String>? customCategories})
      : _mappings = {
          ..._defaultMappings,
          // Add custom categories as self-referencing entries
          if (customCategories != null)
            for (final cat in customCategories) cat: cat,
        };

  /// Find the best matching category for [text], or null.
  String? match(String text) {
    // Prefer longer keyword matches (more specific)
    final sorted = _mappings.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final keyword in sorted) {
      if (text.contains(keyword)) {
        return _mappings[keyword];
      }
    }
    return null;
  }
}
