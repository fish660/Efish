import 'package:flutter_test/flutter_test.dart';
import 'package:efish_app/db.dart';
import 'package:efish_app/services.dart';

/// 日历学习计划：增删改查 + 小红点日期集合
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 用一个未来的固定日期，避免与真实数据冲突
  const date = '2099-01-15';
  const otherDate = '2099-01-20';

  test('plans 增删改查与小红点集合', () async {
    await AppDb.init();
    final db = AppDb.instance;

    // 先清理可能的残留
    db.execute('DELETE FROM plans WHERE plan_date IN (?,?)', [date, otherDate]);

    // 空内容不应插入
    final emptyId = Services.addPlan(date, '   ');
    expect(emptyId, 0);

    // 新增两条
    final id1 = Services.addPlan(date, '背 20 个新词');
    final id2 = Services.addPlan(date, '复习到期单词');
    expect(id1 > 0, true);
    expect(id2 > 0, true);

    // 查询当天计划
    var plans = Services.plansFor(date);
    expect(plans.length, 2);
    expect(plans[0]['content'], '背 20 个新词');
    expect(plans[0]['done'], false);

    // 勾选完成第一条
    Services.togglePlan(id1, true);
    plans = Services.plansFor(date);
    // 未完成在前：第一条应变为未完成的“复习到期单词”
    expect(plans.first['done'], false);
    expect(plans.first['content'], '复习到期单词');
    final done = plans.firstWhere((p) => p['id'] == id1);
    expect(done['done'], true);

    // 小红点：当月有计划的日期集合
    final dates = Services.planDates(2099, 1);
    expect(dates.contains(date), true);
    expect(dates.contains(otherDate), false);

    // 另一天加一条
    final id3 = Services.addPlan(otherDate, '总测试一次');
    expect(Services.planDates(2099, 1).contains(otherDate), true);

    // 删除一条
    Services.deletePlan(id2);
    plans = Services.plansFor(date);
    expect(plans.length, 1);
    expect(plans.first['id'], id1);

    // 清理
    db.execute('DELETE FROM plans WHERE plan_date IN (?,?)', [date, otherDate]);
    expect(Services.plansFor(date).isEmpty, true);
    expect(Services.plansFor(otherDate).isEmpty, true);
  });
}
