import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../services.dart';
import '../widgets/word_widgets.dart';

/// 每日篇章收录：按日期记录每天学过的篇章
class PassagesPage extends StatefulWidget {
  const PassagesPage({super.key});

  @override
  State<PassagesPage> createState() => _PassagesPageState();
}

class _PassagesPageState extends State<PassagesPage> {
  @override
  Widget build(BuildContext context) {
    final t = context.c;
    final list = Services.passages(appState.currentBook);
    // 按日期分组
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final p in list) {
      groups.putIfAbsent(p['log_date'] as String, () => []).add(p);
    }
    final dates = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Text('每日篇章收录',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: t.text)),
              const SizedBox(width: 8),
              Text('记录每天学过的每个篇章',
                  style: TextStyle(fontSize: 13, color: t.subText)),
            ],
          ),
        ),
        Expanded(
          child: dates.isEmpty
              ? Center(
                  child: Text('还没有篇章记录，完成一次学习或测试后即可查看',
                      style:
                          TextStyle(fontSize: 14, color: t.subText)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  itemCount: dates.length,
                  itemBuilder: (context, i) {
                    final date = dates[i];
                    final items = groups[date]!;
                    final dayTotal =
                        items.fold<int>(0, (s, p) => s + (p['word_count'] as int));
                    return Card(
                      child: ExpansionTile(
                        title: Text(date,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: t.text)),
                        subtitle: Text('${items.length} 个篇章 · 共 $dayTotal 词',
                            style: TextStyle(
                                fontSize: 12, color: t.subText)),
                        children: items.map((p) {
                          final acc = p['accuracy'] as double;
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  t.primary.withValues(alpha: .12),
                              child: Text('${p['sequence']}',
                                  style: TextStyle(
                                      fontSize: 13, color: t.primary)),
                            ),
                            title: Text('${p['subtitle']} · ${p['word_count']} 词',
                                style: TextStyle(
                                    fontSize: 13, color: t.text)),
                            trailing: Text(
                              '${acc.toStringAsFixed(0)}%',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: acc >= 80
                                      ? Colors.green.shade600
                                      : Colors.orange.shade700),
                            ),
                            onTap: () => _showWords(context, p),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showWords(BuildContext context, Map<String, dynamic> p) {
    final words = Services.passageWords(p['session_id'] as int);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PassageWordsPage(
          title: p['title'] as String, words: words),
    ));
  }
}

class PassageWordsPage extends StatelessWidget {
  const PassageWordsPage(
      {super.key, required this.title, required this.words});
  final String title;
  final List<Word> words;

  @override
  Widget build(BuildContext context) {
    final t = context.c;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: words.length,
        itemBuilder: (context, i) {
          final w = words[i];
          return Card(
            child: ListTile(
              title: Row(
                children: [
                  Text('${i + 1}. ',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: t.text)),
                  SpeakableWord(w.word,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.text),
                ],
              ),
              subtitle: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '${w.pos}  ${w.meaning}',
                      style: TextStyle(fontSize: 12, color: t.subText)),
                  if (w.phonetic.isNotEmpty)
                    TextSpan(
                        text: '  ${w.phonetic}',
                        style:
                            ipaTextStyle(fontSize: 12, color: t.subText)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
