/// 农历日期
class LunarDate {
  final int year;
  final int month;
  final int day;
  final bool isLeap;
  const LunarDate(this.year, this.month, this.day, [this.isLeap = false]);

  /// 农历日的中文表示（初一、初二…三十）
  static const dayNames = [
    '初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
    '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
    '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十'
  ];

  String get dayName => dayNames[day - 1];

  @override
  bool operator ==(Object other) =>
      other is LunarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day &&
      other.isLeap == isLeap;

  @override
  int get hashCode => Object.hash(year, month, day, isLeap);

  @override
  String toString() =>
      'LunarDate($year, $month, $day${isLeap ? ' 闰' : ''})';
}

/// 公历 ↔ 农历转换（支持 1900-2099）。
/// 使用经典的农历年历数据表，纯离线、无依赖。
class LunarCalendar {
  LunarCalendar._();

  /// 1900-2099 各农历年的大小月、闰月信息
  static const List<int> _info = [
    0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2,
    0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977,
    0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970,
    0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
    0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x152b9, 0x0a950, 0x0b557,
    0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573, 0x052b0, 0x0a9a8, 0x0e950, 0x06aa0,
    0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0,
    0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b6a0, 0x195a6,
    0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570,
    0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x055c0, 0x0ab60, 0x096d5, 0x092e0,
    0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5,
    0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
    0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530,
    0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45,
    0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0,
    0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0,
    0x0a2e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x0d650, 0x055a4, 0x056a0, 0x0a6d0,
    0x0cc5d, 0x092e0, 0x1d2a3, 0x0c960, 0x0d950, 0x0e950, 0x10aa9, 0x0a550, 0x0b250, 0x1d2a5,
    0x06aa0, 0x0b650, 0x06d20, 0x0ada0, 0x1ab55, 0x09370, 0x04970, 0x051b9, 0x06b20, 0x0a930,
    0x074a3, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570, 0x04af5, 0x04970, 0x064b0, 0x074a3,
  ];

  /// 闰月月份（0 表示无闰月）
  static int leapMonth(int y) => _info[y - 1900] & 0xf;

  /// 闰月天数
  static int leapDays(int y) {
    if (leapMonth(y) != 0) {
      return ((_info[y - 1900] & 0x10000) != 0) ? 30 : 29;
    }
    return 0;
  }

  /// 农历某月天数（m 从 1 开始）
  static int monthDays(int y, int m) =>
      ((_info[y - 1900] & (0x10000 >> m)) != 0) ? 30 : 29;

  /// 农历年总天数
  static int yearDays(int y) {
    int sum = 348;
    for (int i = 0x8000; i > 0x8; i >>= 1) {
      sum += ((_info[y - 1900] & i) != 0) ? 1 : 0;
    }
    return sum + leapDays(y);
  }

  /// 公历转农历；超出 1900-2099 返回 null
  static LunarDate? solarToLunar(DateTime solar) {
    final y = solar.year;
    if (y < 1900 || y > 2099) return null;
    // 农历 1900 年正月初一 = 公历 1900-01-31
    final base = DateTime(1900, 1, 31);
    int offset = DateTime(solar.year, solar.month, solar.day)
        .difference(base)
        .inDays;
    if (offset < 0) return null;

    int lunarYear = 1900;
    int temp = 0;
    for (lunarYear = 1900; lunarYear < 2100 && offset > 0; lunarYear++) {
      temp = yearDays(lunarYear);
      offset -= temp;
    }
    if (offset < 0) {
      offset += temp;
      lunarYear--;
    }

    final leap = leapMonth(lunarYear);
    bool isLeap = false;
    int lunarMonth = 1;
    for (lunarMonth = 1; lunarMonth < 13 && offset > 0; lunarMonth++) {
      if (leap > 0 && lunarMonth == (leap + 1) && !isLeap) {
        --lunarMonth;
        isLeap = true;
        temp = leapDays(lunarYear);
      } else {
        temp = monthDays(lunarYear, lunarMonth);
      }
      if (isLeap && lunarMonth == (leap + 1)) isLeap = false;
      offset -= temp;
    }

    if (offset == 0 && leap > 0 && lunarMonth == leap + 1) {
      if (isLeap) {
        isLeap = false;
      } else {
        isLeap = true;
        --lunarMonth;
      }
    }
    if (offset < 0) {
      offset += temp;
      --lunarMonth;
    }
    final lunarDay = offset + 1;
    return LunarDate(lunarYear, lunarMonth, lunarDay, isLeap);
  }
}
