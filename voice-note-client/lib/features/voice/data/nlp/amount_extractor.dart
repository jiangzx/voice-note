/// Extracts monetary amounts from Chinese natural language text.
///
/// Supports both Arabic numerals (35, 28.5) and Chinese numerals
/// (三十五, 一百二十, 两千五).
class AmountExtractor {
  // Matches: 35, 28.5, ¥188, 35块, 28块5, 35元, 35.5块钱
  static final _arabicPatterns = [
    // ¥ or ￥ prefix: ¥188, ￥35.5
    RegExp(r'[¥￥]\s*(\d+(?:\.\d+)?)'),
    // X块Y (28块5 → 28.5)
    RegExp(r'(\d+)\s*块\s*(\d)'),
    // Number + unit: 35元, 35块, 35块钱
    RegExp(r'(\d+(?:\.\d+)?)\s*(?:元|块钱?|圆)'),
    // Plain number near cost verbs: 花了35, 付了100
    RegExp(r'(?:花了?|付了?|消费了?|收到?|进账?|转了?)\s*(\d+(?:\.\d+)?)'),
    // Standalone number as last resort (at least 1 digit)
    RegExp(r'(?<!\d)(\d+(?:\.\d+)?)(?!\d)'),
  ];

  // Chinese numeral character set
  static final _chinesePattern = RegExp(
    r'([零一二三四五六七八九十百千万亿两]+)\s*(?:块钱?|元|圆)',
  );
  static final _chineseWithVerbPattern = RegExp(
    r'(?:花了?|付了?|消费了?|收到?|进账?|转了?)\s*([零一二三四五六七八九十百千万亿两]+)',
  );

  /// Extract the first amount found in [text], or null if none.
  static double? extract(String text) {
    // Try Arabic numerals first (higher priority)
    final arabicResult = _extractArabic(text);
    if (arabicResult != null) return arabicResult;

    // Try Chinese numerals
    return _extractChinese(text);
  }

  static double? _extractArabic(String text) {
    for (final pattern in _arabicPatterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;

      // Handle "X块Y" pattern (group 1 = integer, group 2 = decimal digit)
      if (match.groupCount >= 2 && match.group(2) != null) {
        final integer = match.group(1)!;
        final decimal = match.group(2)!;
        return double.tryParse('$integer.$decimal');
      }

      final raw = match.group(1);
      if (raw != null) {
        final value = double.tryParse(raw);
        if (value != null && value > 0) return value;
      }
    }
    return null;
  }

  static double? _extractChinese(String text) {
    // Chinese numeral with unit (三十五块)
    final unitMatch = _chinesePattern.firstMatch(text);
    if (unitMatch != null) {
      final value = chineseToNumber(unitMatch.group(1)!);
      if (value != null && value > 0) return value.toDouble();
    }

    // Chinese numeral after cost verb (花了三十五)
    final verbMatch = _chineseWithVerbPattern.firstMatch(text);
    if (verbMatch != null) {
      final value = chineseToNumber(verbMatch.group(1)!);
      if (value != null && value > 0) return value.toDouble();
    }

    return null;
  }

  /// Convert Chinese numeral string to numeric value.
  ///
  /// Supports: 零一二三四五六七八九十百千万亿两
  /// Examples: 三十五→35, 一百二十→120, 两千五→2500, 一万五千→15000
  static num? chineseToNumber(String chinese) {
    if (chinese.isEmpty) return null;

    const digits = {
      '零': 0, '一': 1, '二': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
      '两': 2,
    };
    const units = {'十': 10, '百': 100, '千': 1000};
    const bigUnits = {'万': 10000, '亿': 100000000};

    // Single digit: 五 → 5 (零 returns null since amount cannot be 0)
    if (chinese.length == 1 && digits.containsKey(chinese)) {
      final v = digits[chinese]!;
      return v > 0 ? v : null;
    }

    int result = 0;
    int currentSection = 0; // Accumulates within a 万/亿 section
    int lastUnit = 1;

    for (int i = 0; i < chinese.length; i++) {
      final char = chinese[i];

      if (digits.containsKey(char)) {
        final digit = digits[char]!;
        // Look ahead for unit
        if (i + 1 < chinese.length) {
          final next = chinese[i + 1];
          if (units.containsKey(next)) {
            currentSection += digit * units[next]!;
            lastUnit = units[next]!;
            i++; // Skip the unit char
            continue;
          }
          if (bigUnits.containsKey(next)) {
            currentSection += digit;
            // Will be multiplied by big unit in next iteration
            continue;
          }
        }
        // Trailing digit implies implied lower unit (e.g., 两千五 → 2500)
        currentSection += digit * (lastUnit ~/ 10).clamp(1, lastUnit);
      } else if (units.containsKey(char)) {
        // Unit without preceding digit → implied 1 (e.g., 十五 → 15)
        if (i == 0 || bigUnits.containsKey(chinese[i - 1])) {
          currentSection += units[char]!;
          lastUnit = units[char]!;
        }
      } else if (bigUnits.containsKey(char)) {
        final multiplier = bigUnits[char]!;
        if (currentSection == 0) currentSection = 1;
        result += currentSection * multiplier;
        currentSection = 0;
        lastUnit = 1;
      }
    }

    result += currentSection;
    return result > 0 ? result : null;
  }
}
