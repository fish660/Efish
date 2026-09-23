import 'package:flutter/material.dart';

import '../main.dart';
import '../services.dart';

/// 学习统计页
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  @override
  Widget build(BuildContext context) {
    final t = context.c;
    final book = appState.currentBook;
    final dash = Services.dashboard(book);
    final acc = Services.overallAccuracy(book);
    final todayLearned = Services.todayLearned(book);
    final weekLearned = Services.weekLearned(book);
    final answered = Services.totalAnswered(book);
    final streak = Services.streakDays(book);
    final last7 = Services.last7Days(book);
    final bookLabel = (book == null || book.isEmpty) ? '全部词书' : book;

    final stats = [
      ('单词总数', '${dash['total']}'),
      ('已学习', '${dash['learned']}'),
      ('学习中', '${dash['learning']}'),
      ('已掌握', '${dash['mastered']}'),
      ('错词数', '${dash['wrong']}'),
      ('今日学习', '$todayLearned'),
      ('本周学习', '$weekLearned'),
      ('累计答题', '$answered'),
      ('总体正确率', '${acc.toStringAsFixed(1)}%'),
      ('连续学习', '$streak 天'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('学习统计',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: t.text)),
          const SizedBox(height: 4),
          Text('数据范围：$bookLabel（不同词书数据互不相通，可在顶部切换）',
              style: TextStyle(fontSize: 12, color: t.subText)),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            // 按可用宽度自适应每行列数，卡片等宽对齐
            final perRow = (constraints.maxWidth / 175).floor().clamp(2, 5);
            final rows = <Widget>[];
            for (var i = 0; i < stats.length; i += perRow) {
              final cells = <Widget>[];
              for (var j = 0; j < perRow; j++) {
                if (j > 0) cells.add(const SizedBox(width: 10));
                final idx = i + j;
                cells.add(Expanded(
                    child: idx < stats.length
                        ? _statCard(t, stats[idx])
                        : const SizedBox()));
              }
              rows.add(Padding(
                padding: EdgeInsets.only(
                    bottom: i + perRow < stats.length ? 10 : 0),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: cells),
              ));
            }
            return Column(children: rows);
          }),
          const SizedBox(height: 18),
          Text('最近 7 天学习情况',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: t.text)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: last7.map((e) {
                  final maxV =
                      last7.fold<int>(1, (m, x) => x.$2 > m ? x.$2 : m);
                  final h = 12.0 + (e.$2 * 110 / maxV);
                  final label = e.$1.substring(5).replaceFirst('-', '/');
                  return Expanded(
                    child: Column(
                      children: [
                        Text('${e.$2}',
                            style:
                                TextStyle(fontSize: 11, color: t.subText)),
                        const SizedBox(height: 3),
                        Container(
                          width: 26,
                          height: h,
                          decoration: BoxDecoration(
                            color: t.primary.withValues(alpha: .7),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(label,
                            style:
                                TextStyle(fontSize: 10, color: t.subText)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('说明：今日/本周学习与累计答题按实际答题记录统计；'
              '连续学习天数按有学习记录或登录打卡的日期连续计算。',
              style: TextStyle(fontSize: 11, color: t.subText)),
        ],
      ),
    );
  }

  Widget _statCard(AppColors t, (String, String) s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: t.subText)),
            const SizedBox(height: 6),
            Text(s.$2,
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
}
