import 'package:flutter_test/flutter_test.dart';
import 'package:efish_app/holidays.dart';
import 'package:efish_app/lunar.dart';

void main() {
  group('农历转换（用国务院通知中的农历日期校准）', () {
    test('2026 春节=2/17 正月初一；2/16 腊月二十九(除夕)', () {
      expect(LunarCalendar.solarToLunar(DateTime(2026, 2, 17)),
          const LunarDate(2026, 1, 1));
      final d = LunarCalendar.solarToLunar(DateTime(2026, 2, 16))!;
      expect(d.month, 12);
      expect(d.day, 29); // 2026 腊月是小月，除夕为腊月二十九
    });
    test('2026 端午=6/19 五月初五', () {
      expect(LunarCalendar.solarToLunar(DateTime(2026, 6, 19)),
          const LunarDate(2026, 5, 5));
    });
    test('2026 中秋=9/25 八月十五', () {
      expect(LunarCalendar.solarToLunar(DateTime(2026, 9, 25)),
          const LunarDate(2026, 8, 15));
    });
    test('2025 春节=1/29 正月初一；1/28 除夕', () {
      expect(LunarCalendar.solarToLunar(DateTime(2025, 1, 29)),
          const LunarDate(2025, 1, 1));
      final d = LunarCalendar.solarToLunar(DateTime(2025, 1, 28))!;
      expect(d.month, 12);
    });
    test('2025 端午=5/31 五月初五', () {
      expect(LunarCalendar.solarToLunar(DateTime(2025, 5, 31)),
          const LunarDate(2025, 5, 5));
    });
    test('2025 中秋=10/6 八月十五', () {
      expect(LunarCalendar.solarToLunar(DateTime(2025, 10, 6)),
          const LunarDate(2025, 8, 15));
    });
  });

  group('法定节假日与调休', () {
    test('2026 国庆 10/1 放假、标签为国庆', () {
      final i = Holidays.of(DateTime(2026, 10, 1));
      expect(i.isHoliday, true);
      expect(i.label, '国庆');
    });
    test('2026 春节假期 2/15 放假、显示休', () {
      // 2/15 是腊月二十八，假期内但不是具体节日 -> 休
      final i = Holidays.of(DateTime(2026, 2, 15));
      expect(i.isHoliday, true);
      expect(i.label, '休');
    });
    test('2026 除夕 2/16 显示除夕', () {
      final i = Holidays.of(DateTime(2026, 2, 16));
      expect(i.label, '除夕');
    });
    test('2026 中秋 9/25 显示中秋', () {
      expect(Holidays.of(DateTime(2026, 9, 25)).label, '中秋');
    });
    test('2026 调休补班 9/20(周日) 上班、显示班', () {
      final i = Holidays.of(DateTime(2026, 9, 20));
      expect(i.isMakeup, true);
      expect(i.isRest, false);
      expect(i.label, '班');
    });
    test('2026 调休补班 10/10(周六) 上班', () {
      expect(Holidays.of(DateTime(2026, 10, 10)).isMakeup, true);
    });
    test('普通周末 2026-09-19(周六) 休息', () {
      final i = Holidays.of(DateTime(2026, 9, 19));
      expect(i.isWeekend, true);
      expect(i.isRest, true);
    });
    test('普通工作日 2026-09-22(周二) 无标签', () {
      final i = Holidays.of(DateTime(2026, 9, 22));
      expect(i.isHoliday, false);
      expect(i.isMakeup, false);
      expect(i.isRest, false);
    });
    test('2025 国庆中秋 10/1 国庆、10/6 中秋', () {
      expect(Holidays.of(DateTime(2025, 10, 1)).label, '国庆');
      expect(Holidays.of(DateTime(2025, 10, 6)).label, '中秋');
    });
  });

  group('公历节日', () {
    test('劳动节、元旦、教师节', () {
      expect(Holidays.of(DateTime(2026, 5, 1)).label, '劳动节');
      expect(Holidays.of(DateTime(2026, 1, 1)).label, '元旦');
      expect(Holidays.of(DateTime(2026, 9, 10)).label, '教师节');
    });
    test('补班日优先显示“班”（2026-02-14 情人节撞补班）', () {
      final i = Holidays.of(DateTime(2026, 2, 14));
      expect(i.isMakeup, true);
      expect(i.label, '班');
    });
    test('普通工作日的情人节仍显示情人节', () {
      // 2025-02-14 为周五，非补班
      expect(Holidays.of(DateTime(2025, 2, 14)).label, '情人节');
    });
    test('2026 春节 2/17 为春节、2/16 为除夕', () {
      expect(Holidays.of(DateTime(2026, 2, 17)).label, '春节');
      expect(Holidays.of(DateTime(2026, 2, 16)).label, '除夕');
    });
    test('2026 另一个补班日 2/28 显示班', () {
      expect(Holidays.of(DateTime(2026, 2, 28)).label, '班');
    });
  });
}
