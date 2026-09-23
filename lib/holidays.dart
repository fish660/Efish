import 'lunar.dart';

/// 一天的节假日信息
class DayInfo {
  /// 格子内显示的节日简称（如“春节”“国庆”“休”“班”），无则 null
  final String? label;

  /// 完整节日名（鼠标/点击提示用）
  final String? fullName;

  /// 具体节日级别：0=无节日，1=一般公历节日，2=传统节日，3=法定节日
  final int festivalLevel;

  /// 是否法定节假日（放假）
  final bool isHoliday;

  /// 是否调休补班（周末上班）
  final bool isMakeup;

  /// 是否普通周末
  final bool isWeekend;

  /// 是否休息日（法定假日，或周末且非补班）
  bool get isRest => isHoliday || (isWeekend && !isMakeup);

  /// 是否有具体节日名（区别于“休/班”）
  bool get hasFestival => festivalLevel > 0;

  const DayInfo({
    this.label,
    this.fullName,
    this.festivalLevel = 0,
    this.isHoliday = false,
    this.isMakeup = false,
    this.isWeekend = false,
  });

  static const empty = DayInfo();
}

/// 节日 / 法定节假日 / 休息日数据服务（纯离线内置）。
/// 法定放假与调休依据国务院办公厅通知：
///   2025 年：国办发明电〔2024〕12 号
///   2026 年：国办发明电〔2025〕7 号
class Holidays {
  Holidays._();

  /// 法定放假范围：[年, 起月, 起日, 止月, 止日, 名称]
  static const List<List<Object>> _ranges = [
    // 2025
    [2025, 1, 1, 1, 1, '元旦'],
    [2025, 1, 28, 2, 4, '春节'],
    [2025, 4, 4, 4, 6, '清明'],
    [2025, 5, 1, 5, 5, '劳动节'],
    [2025, 5, 31, 6, 2, '端午'],
    [2025, 10, 1, 10, 8, '国庆·中秋'],
    // 2026
    [2026, 1, 1, 1, 3, '元旦'],
    [2026, 2, 15, 2, 23, '春节'],
    [2026, 4, 4, 4, 6, '清明'],
    [2026, 5, 1, 5, 5, '劳动节'],
    [2026, 6, 19, 6, 21, '端午'],
    [2026, 9, 25, 9, 27, '中秋'],
    [2026, 10, 1, 10, 7, '国庆'],
  ];

  /// 调休补班日期（周末上班）
  static const Set<String> _makeup = {
    '2025-01-26', '2025-02-08', '2025-04-27', '2025-09-28', '2025-10-11',
    '2026-01-04', '2026-02-14', '2026-02-28', '2026-05-09',
    '2026-09-20', '2026-10-10',
  };

  /// 公历固定节日：'MM-DD' -> [简称, 全名, 重要度]
  /// 重要度：3=法定节日，2=传统节日，1=一般公历节日
  static const Map<String, List<Object>> _solar = {
    '01-01': ['元旦', '元旦', 3],
    '02-14': ['情人节', '西方情人节', 1],
    '03-08': ['妇女节', '国际妇女节', 1],
    '03-12': ['植树节', '植树节', 1],
    '04-01': ['愚人节', '愚人节', 1],
    '05-01': ['劳动节', '国际劳动节', 3],
    '05-04': ['青年节', '五四青年节', 1],
    '06-01': ['儿童节', '国际儿童节', 1],
    '07-01': ['建党节', '中国共产党成立纪念日', 1],
    '08-01': ['建军节', '建军节', 1],
    '09-10': ['教师节', '教师节', 1],
    '10-01': ['国庆', '国庆节', 3],
    '12-24': ['平安夜', '平安夜', 1],
    '12-25': ['圣诞', '圣诞节', 1],
  };

  /// 清明节气日期（4/4 或 4/5，2025-2030）
  static const Map<int, String> _qingming = {
    2025: '04-04',
    2026: '04-05',
    2027: '04-05',
    2028: '04-04',
    2029: '04-04',
    2030: '04-05',
  };

  /// 农历节日：key = 月*100 + 日 -> [简称, 全名, 重要度]
  /// 重要度：3=法定节日，2=传统节日，1=一般公历节日
  static const Map<int, List<Object>> _lunarFest = {
    101: ['春节', '春节（正月初一）', 3],
    115: ['元宵', '元宵节', 2],
    202: ['龙抬头', '龙抬头', 2],
    505: ['端午', '端午节', 3],
    707: ['七夕', '七夕节', 2],
    715: ['中元', '中元节', 2],
    815: ['中秋', '中秋节', 3],
    909: ['重阳', '重阳节', 2],
    1208: ['腊八', '腊八节', 2],
    1223: ['小年', '小年（北方）', 2],
  };

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _md(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 某日期所在的法定假期名称（无则 null）
  static String? _holidayName(DateTime d) {
    for (final r in _ranges) {
      if (r[0] != d.year) continue;
      final start = DateTime(d.year, r[1] as int, r[2] as int);
      final end = DateTime(d.year, r[3] as int, r[4] as int);
      final cur = DateTime(d.year, d.month, d.day);
      if (!cur.isBefore(start) && !cur.isAfter(end)) {
        return r[5] as String;
      }
    }
    return null;
  }

  /// 计算第 n 个星期几（用于母亲节、父亲节）
  static DateTime? _nthWeekday(int year, int month, int weekday, int n) {
    // weekday: DateTime.sunday=7 ...
    final first = DateTime(year, month, 1);
    var offset = (weekday - first.weekday) % 7;
    final day = 1 + offset + (n - 1) * 7;
    final result = DateTime(year, month, day);
    return result.month == month ? result : null;
  }

  /// 获取某天的节日/休息日信息
  static DayInfo of(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final isWeekend = d.weekday == DateTime.saturday ||
        d.weekday == DateTime.sunday;
    final isMakeup = _makeup.contains(_key(d));
    final holidayName = _holidayName(d);
    final isHoliday = holidayName != null;

    // 收集当天的具体节日，取重要度最高者
    String? bestName;
    String? bestFull;
    var bestLevel = 0;

    void consider(String? name, String? full, int level) {
      if (name != null && level > bestLevel) {
        bestName = name;
        bestFull = full;
        bestLevel = level;
      }
    }

    // 公历节日
    final solar = _solar[_md(d)];
    if (solar != null) {
      consider(solar[0] as String, solar[1] as String, solar[2] as int);
    }
    // 清明节气
    if (_qingming[d.year] == _md(d)) {
      consider('清明', '清明节', 3);
    }
    // 母亲节（5月第二个周日）、父亲节（6月第三个周日）
    final mother = _nthWeekday(d.year, 5, DateTime.sunday, 2);
    if (mother != null && _key(mother) == _key(d)) {
      consider('母亲节', '母亲节', 1);
    }
    final father = _nthWeekday(d.year, 6, DateTime.sunday, 3);
    if (father != null && _key(father) == _key(d)) {
      consider('父亲节', '父亲节', 1);
    }
    // 农历节日
    final lunar = LunarCalendar.solarToLunar(d);
    if (lunar != null && !lunar.isLeap) {
      final lf = _lunarFest[lunar.month * 100 + lunar.day];
      if (lf != null) {
        consider(lf[0] as String, lf[1] as String, lf[2] as int);
      }
      // 除夕：农历腊月最后一天
      if (lunar.month == 12) {
        final daysInMonth = LunarCalendar.monthDays(lunar.year, 12);
        if (lunar.day == daysInMonth) {
          consider('除夕', '除夕', 3);
        }
      }
    }

    String? label;
    String? full = bestFull;
    if (bestName != null && bestLevel >= 2) {
      // 法定节日 / 传统节日优先于补班标记
      label = bestName;
    } else if (isMakeup) {
      // 调休补班优先于一般公历节日（如情人节撞补班，显示“班”）
      label = '班';
      full = '调休上班日';
    } else if (bestName != null) {
      label = bestName;
    } else if (isHoliday) {
      label = '休';
      full = '$holidayName假期';
    }

    return DayInfo(
      label: label,
      fullName: full,
      festivalLevel: bestLevel,
      isHoliday: isHoliday,
      isMakeup: isMakeup,
      isWeekend: isWeekend,
    );
  }
}
