import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services.dart';
import '../holidays.dart';
import '../widgets/animated_pet.dart';
import 'learn_flow.dart';
import 'mistakes_page.dart';
import 'passages_page.dart';

/// 桌宠对话库（40 条）
const companionLines = [
  '背单词的每一分钟都不会白费！',
  '今天也要元气满满地背词哦~',
  '累了就休息一下，但别忘了回来继续~',
  '每记住一个单词，都离梦想更近一步！',
  '坚持就是胜利，你已经很棒了！',
  '嘿嘿，我在盯着你学习哦！',
  '要不要来 20 个新单词热热身？',
  '复习时间到！旧单词在等你呢~',
  '错词本里的老朋友，该去看看它们了。',
  '日积月累，量变一定会引起质变！',
  '今天的你，比昨天又强了一点！',
  '别怕记不住，重复是最好的老师。',
  '我帮你盯着日历，可别断签呀~',
  '小小单词，轻松拿下！',
  '想象一下考场上挥笔如飞的样子~',
  '你的努力，时间都会记得。',
  '单词是砖，句子是墙，加油盖楼吧！',
  '先完成，再完美，慢慢来~',
  '试试默写模式，检验一下自己？',
  '静下心来，每个词都值得认真对待。',
  '坚持背词的人，运气都不会太差！',
  '今天也要对自己好一点，也要学一点。',
  '每学 5 个单词，就奖励自己休息一下~',
  '把手机放远一点，把单词拉近一点！',
  '我相信你，明天也会来的对吧？',
  '真题里常出现的词，可别错过哦~',
  '看一眼音标，读准一个词！',
  '例句是单词的家，记得常回去看看。',
  '背词如逆水行舟，不进则退！',
  '哇，今天的打卡进度不错嘛！',
  '单词不会背，考试两行泪，快学起来！',
  '深呼吸，这个词你可以的！',
  '用碎片时间背 5 个，积少成多~',
  '你的复习计划正在等你完成哦！',
  '红宝书 6548 词，一个一个拿下！',
  '错误不可怕，重复练习就好啦~',
  '让我看看谁还在偷懒不学习？',
  '背完这一批，奖励自己一杯奶茶吧！',
  '学习贵在坚持，你已经走在路上了！',
  '最后一个词背完，今天就圆满啦！',
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Map<String, int> _dash;
  int _reviewCount = 0;
  int _newCount = 0;
  Timer? _companionTimer;
  String _bubble = '';
  bool _bubbleVisible = false;

  // 日历状态
  int _calYear = 0;
  int _calMonth = 0;
  Set<String> _monthStudy = {};
  Map<String, int> _dailyLogs = {};

  // 日历计划状态
  DateTime _selectedDate = DateTime.now();
  Set<String> _planDates = {};
  List<Map<String, dynamic>> _plans = [];
  final _planCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calYear = now.year;
    _calMonth = now.month;
    _selectedDate = DateTime(now.year, now.month, now.day);
    _reload();
    _scheduleCompanion();
    // 切换词书后即时刷新首页统计与日历（IndexedStack 会保持本页 State）
    appState.addListener(_onAppChange);
  }

  @override
  void dispose() {
    appState.removeListener(_onAppChange);
    _companionTimer?.cancel();
    _planCtrl.dispose();
    super.dispose();
  }

  void _onAppChange() {
    if (mounted) _reload();
  }

  void _reload() {
    final book = appState.currentBook;
    setState(() {
      _dash = Services.dashboard(book);
      _newCount = Services.newWordCount(book);
      _reviewCount = Services.reviewCount(book);
      _monthStudy = Services.monthStudyDates(_calYear, _calMonth, book);
      _dailyLogs = Services.dailyLogs(book);
      _planDates = Services.planDates(_calYear, _calMonth);
      _plans = Services.plansFor(_dateStr(_selectedDate));
    });
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _selectDate(DateTime d) {
    setState(() {
      _selectedDate = d;
      _plans = Services.plansFor(_dateStr(d));
    });
  }

  void _addPlan() {
    final text = _planCtrl.text;
    final id = Services.addPlan(_dateStr(_selectedDate), text);
    if (id == 0) return;
    _planCtrl.clear();
    setState(() {
      _plans = Services.plansFor(_dateStr(_selectedDate));
      _planDates = Services.planDates(_calYear, _calMonth);
    });
  }

  void _togglePlan(Map<String, dynamic> p) {
    Services.togglePlan(p['id'] as int, !(p['done'] as bool));
    setState(() => _plans = Services.plansFor(_dateStr(_selectedDate)));
  }

  void _deletePlan(int id) {
    Services.deletePlan(id);
    setState(() {
      _plans = Services.plansFor(_dateStr(_selectedDate));
      _planDates = Services.planDates(_calYear, _calMonth);
    });
  }

  void _scheduleCompanion() {
    _companionTimer?.cancel();
    _companionTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) _showBubble(companionLines[_random()]);
    });
  }

  int _random() => DateTime.now().millisecondsSinceEpoch % companionLines.length;

  void _showBubble(String text) {
    setState(() {
      _bubble = text;
      _bubbleVisible = true;
    });
    Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _bubbleVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text('进度、正确率与连续天数',
              style: TextStyle(fontSize: 13, color: t.subText)),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: _leftColumn(t))),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _rightColumn(t)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _leftColumn(AppColors t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statRow(t),
        const SizedBox(height: 14),
        _quickActions(t),
        const SizedBox(height: 14),
        _planCard(t),
      ],
    );
  }

  // ---------- 统计卡：等分网格，永远对齐 ----------

  Widget _statRow(AppColors t) {
    final items = [
      ('今日新词', '$_newCount'),
      ('今日复习', '$_reviewCount'),
      ('单词总数', '${_dash['total']}'),
      ('已学习', '${_dash['learned']}'),
      ('已掌握', '${_dash['mastered']}'),
      ('总体正确率', '${Services.overallAccuracy(appState.currentBook).toStringAsFixed(1)}%'),
    ];
    return Column(
      children: [
        for (var r = 0; r < 2; r++)
          Padding(
            padding: EdgeInsets.only(bottom: r == 0 ? 10 : 0),
            child: Row(
              children: [
                for (var c = 0; c < 3; c++) ...[
                  if (c > 0) const SizedBox(width: 10),
                  Expanded(child: _statCard(t, items[r * 3 + c])),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _statCard(AppColors t, (String, String) e) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: t.subText)),
            const SizedBox(height: 6),
            Text(e.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: t.primary)),
          ],
        ),
      ),
    );
  }

  // ---------- 快捷入口：等分网格 ----------

  Widget _quickActions(AppColors t) {
    final actions = [
      ('开始学习新单词', '抽一批从未学过的单词', Icons.school_outlined, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const StandalonePage(
              title: '学习新单词', child: LearnPage())));
      }),
      ('开始今日复习', '按 1/3/7/15/30 天记忆曲线复习', Icons.refresh_outlined, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const StandalonePage(
              title: '今日复习', child: ReviewPage())));
      }),
      ('每日篇章收录', '回看每天学过的篇章', Icons.article_outlined, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const StandalonePage(
              title: '每日篇章收录', child: PassagesPage())));
      }),
      ('错词本', '攻克曾经答错的单词', Icons.error_outline, () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const StandalonePage(
              title: '错词本', child: MistakesPage())));
      }),
    ];
    return Column(
      children: [
        for (var r = 0; r < 2; r++)
          Padding(
            padding: EdgeInsets.only(bottom: r == 0 ? 10 : 0),
            child: Row(
              children: [
                for (var c = 0; c < 2; c++) ...[
                  if (c > 0) const SizedBox(width: 10),
                  Expanded(child: _actionCard(t, actions[r * 2 + c])),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _actionCard(AppColors t, (String, String, IconData, VoidCallback) a) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: a.$4,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              Icon(a.$3, color: t.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(a.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: t.text)),
                    const SizedBox(height: 3),
                    Text(a.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: t.subText)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: t.subText, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rightColumn(AppColors t) {
    return Column(
      children: [
        _calendarCard(t),
        const SizedBox(height: 8),
        Expanded(child: _companionCard(t)),
      ],
    );
  }

  // ---------- 日历 ----------

  Widget _calendarCard(AppColors t) {
    final firstWeekday = DateTime(_calYear, _calMonth, 1).weekday; // 1-7
    final daysInMonth = DateTime(_calYear, _calMonth + 1, 0).day;
    final today = Services.todayStr();
    final monthTotal = _dailyLogs.entries
        .where((e) => e.key.startsWith('$_calYear-${_calMonth.toString().padLeft(2, '0')}'))
        .fold<int>(0, (s, e) => s + e.value);
    final weekdayCn = ['一', '二', '三', '四', '五', '六', '日'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Expanded(
                  child: Text(
                    '$_calYear年$_calMonth月',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: t.text),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
            Text('本月学习 $monthTotal 词',
                style: TextStyle(fontSize: 11, color: t.subText)),
            const SizedBox(height: 10),
            Row(
              children: weekdayCn
                  .map((w) => Expanded(
                        child: Text(w,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, color: t.subText)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              // 格子略扁，避免右列过高导致桌宠卡被挤出一屏
              childAspectRatio: 1.18,
              children: _calendarCells(daysInMonth, firstWeekday, today, t),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legend(t, '今日', t.primary),
                const SizedBox(width: 12),
                _legend(t, '学习过', Colors.green),
                const SizedBox(width: 12),
                _legend(t, '当日设有学习计划', Colors.red.shade500),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('数字=当日学习词汇数',
                    style: TextStyle(fontSize: 10, color: t.subText)),
                const SizedBox(width: 12),
                Text('红字=休息日/节日',
                    style: TextStyle(fontSize: 10, color: Colors.red.shade500)),
                const SizedBox(width: 12),
                Text('班=调休上班',
                    style: TextStyle(fontSize: 10, color: Colors.orange.shade800)),
              ],
            ),
            const SizedBox(height: 8),
            Text('您一共已学习了 ${Services.totalStudyDays(appState.currentBook)} 天',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.primary)),
          ],
        ),
      ),
    );
  }

  Widget _legend(AppColors t, String label, Color color) {
    return Row(
      children: [
        Container(
            width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: t.subText)),
      ],
    );
  }

  void _changeMonth(int delta) {
    var y = _calYear;
    var m = _calMonth + delta;
    if (m < 1) {
      m = 12;
      y--;
    } else if (m > 12) {
      m = 1;
      y++;
    }
    setState(() {
      _calYear = y;
      _calMonth = m;
      _monthStudy = Services.monthStudyDates(y, m, appState.currentBook);
      _planDates = Services.planDates(y, m);
    });
  }

  List<Widget> _calendarCells(int daysInMonth, int firstWeekday, String today,
      AppColors t) {
    final cells = <Widget>[];
    for (var i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(_dayCell(d, today, t));
    }
    return cells;
  }

  Widget _dayCell(int d, String today, AppColors t) {
    final ds = '$_calYear-${_calMonth.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    final isToday = ds == today;
    final isSelected = ds == _dateStr(_selectedDate);
    final studied = _monthStudy.contains(ds);
    final hasPlan = _planDates.contains(ds);
    final count = _dailyLogs[ds];
    final info = Holidays.of(DateTime(_calYear, _calMonth, d));
    final tag = info.label;
    Color bg;
    Border? border;
    if (isToday) {
      bg = t.primary;
    } else if (isSelected) {
      bg = t.primary.withValues(alpha: .10);
      border = Border.all(color: t.primary, width: 1.4);
    } else if (studied) {
      bg = Colors.green.withValues(alpha: .16);
      border = Border.all(color: Colors.green.withValues(alpha: .45));
    } else {
      bg = Colors.transparent;
    }

    // 日期数字颜色：今天白字；休息日（法定假日/周末且非补班）红字；其余正常
    Color numColor;
    if (isToday) {
      numColor = Colors.white;
    } else if (info.isRest) {
      numColor = Colors.red.shade500;
    } else {
      numColor = t.text;
    }

    // 底部标签颜色：法定节日红、传统节日橙、一般节日蓝灰、休红、班橙
    Color? tagColor;
    if (isToday) {
      tagColor = Colors.white;
    } else if (info.hasFestival) {
      tagColor = info.festivalLevel == 3
          ? Colors.red.shade600
          : info.festivalLevel == 2
              ? Colors.deepOrange.shade700
              : Colors.blueGrey.shade500;
    } else if (tag == '休') {
      tagColor = Colors.red.shade400;
    } else if (tag == '班') {
      tagColor = Colors.orange.shade800;
    }

    // 节日/休/班优先显示；都没有时才显示当日学习数量
    final showCount = tag == null && count != null && count > 0 && !isToday;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: () => _selectDate(DateTime(_calYear, _calMonth, d)),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: border,
          ),
          // 固定结构：日期数字居中，底部固定一行显示“节日/休/班”或学习数量，
          // 顶部红点表示有计划；用 Stack 让红点浮动、不挤压数字，保证所有格子对齐
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$d',
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.0,
                          fontWeight: (isToday || isSelected)
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: numColor)),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 11,
                    child: Center(
                      child: Text(
                        tag ?? (showCount ? '$count' : ''),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        textAlign: TextAlign.center,
                        style: tag != null
                            ? TextStyle(
                                fontSize: 8.5,
                                height: 1.0,
                                color: tagColor,
                                fontWeight: info.hasFestival
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              )
                            : TextStyle(
                                fontSize: 8,
                                height: 1.0,
                                color: Colors.green.shade700),
                      ),
                    ),
                  ),
                ],
              ),
              if (hasPlan)
                Positioned(
                  top: 3,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isToday ? Colors.white : Colors.red.shade500,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 学习计划 ----------

  Widget _planCard(AppColors t) {
    final doneCount = _plans.where((p) => p['done'] == true).length;
    final dayInfo = Holidays.of(_selectedDate);
    final hasDayTag = dayInfo.fullName != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_note_outlined, size: 17, color: t.primary),
                const SizedBox(width: 6),
                Text(
                  '${_selectedDate.month}月${_selectedDate.day}日 · 学习计划',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.text),
                ),
                const Spacer(),
                if (_plans.isNotEmpty)
                  Text('$doneCount/${_plans.length}',
                      style: TextStyle(fontSize: 12, color: t.subText)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (hasDayTag) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (dayInfo.isMakeup ? Colors.orange : Colors.red)
                          .withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      dayInfo.fullName ?? '',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: dayInfo.isMakeup
                            ? Colors.orange.shade800
                            : Colors.red.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text('点击日历选择日期，为当天添加计划',
                      style: TextStyle(fontSize: 10, color: t.subText)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_plans.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text('这一天还没有计划，添加一条吧~',
                      style: TextStyle(fontSize: 12, color: t.subText)),
                ),
              )
            else
              ..._plans.map((p) => _planTile(p, t)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _planCtrl,
                    style: TextStyle(fontSize: 13, color: t.text),
                    onSubmitted: (_) => _addPlan(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '添加计划，如：背 20 个新词',
                      hintStyle: TextStyle(fontSize: 12, color: t.subText),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: t.primary,
                    minimumSize: const Size(40, 40),
                  ),
                  onPressed: _addPlan,
                  icon: const Icon(Icons.add, color: Colors.white),
                  tooltip: '添加计划',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _planTile(Map<String, dynamic> p, AppColors t) {
    final done = p['done'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          // 圆形勾选框
          GestureDetector(
            onTap: () => _togglePlan(p),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? Colors.green.shade600 : Colors.transparent,
                border: Border.all(
                    color: done ? Colors.green.shade600 : t.subText,
                    width: 1.4),
              ),
              child: done
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              p['content'] as String,
              style: TextStyle(
                fontSize: 13,
                color: done ? t.subText : t.text,
                decoration:
                    done ? TextDecoration.lineThrough : TextDecoration.none,
                decorationColor: t.subText,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            icon: Icon(Icons.close, size: 16, color: t.subText),
            tooltip: '删除计划',
            onPressed: () => _deletePlan(p['id'] as int),
          ),
        ],
      ),
    );
  }

  // ---------- 桌宠 ----------

  Widget _companionCard(AppColors t) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Column(
              children: [
                const SizedBox(height: 12), // 为气泡预留少量空间
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedPet(
                      size: 240,
                      onTap: () =>
                          _showBubble(companionLines[_random()]),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text('点击 Efish，它会为你打气哦~',
                    style: TextStyle(fontSize: 11, color: t.subText)),
              ],
            ),
            if (_bubbleVisible)
              Positioned(
                top: -6,
                left: 0,
                right: 0,
                child: Center(child: _bubbleWidget(t)),
              ),
          ],
        ),
      ),
    );
  }

  /// 自适应气泡：宽度跟随文字（有上限），下方带指向桌宠的小三角
  Widget _bubbleWidget(AppColors t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 230),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.primary.withValues(alpha: .35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(_bubble,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.35, color: t.text)),
          ),
        ),
        CustomPaint(
          size: const Size(14, 7),
          painter: _BubbleTriangle(t.card),
        ),
      ],
    );
  }
}

/// 气泡底部小三角
class _BubbleTriangle extends CustomPainter {
  final Color color;
  _BubbleTriangle(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTriangle oldDelegate) =>
      oldDelegate.color != color;
}
