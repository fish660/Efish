import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../services.dart';
import '../widgets/word_widgets.dart';

/// 单词库：搜索 / 词书筛选 / 分页
class WordsPage extends StatefulWidget {
  const WordsPage({super.key});

  @override
  State<WordsPage> createState() => _WordsPageState();
}

class _WordsPageState extends State<WordsPage> {
  final _searchCtrl = TextEditingController();
  String _book = '';
  int _page = 1;
  static const _perPage = 20;
  int _total = 0;
  List<WordWithProgress> _list = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _total = Services.searchCount(_searchCtrl.text, _book);
      _list = Services.searchWords(
          _searchCtrl.text, _book, _page, _perPage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.c;
    final pages = (_total / _perPage).ceil().clamp(1, 1 << 20);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              Text('单词库',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: t.text)),
              const SizedBox(width: 8),
              Text('共 $_total 词',
                  style: TextStyle(fontSize: 13, color: t.subText)),
              const Spacer(),
              SizedBox(
                width: 160,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _book,
                    isDense: true,
                    style: TextStyle(fontSize: 13, color: t.text),
                    dropdownColor: t.card,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('全部词书')),
                      ...Services.books()
                          .map((b) =>
                              DropdownMenuItem(value: b, child: Text(b)))
                    ],
                    onChanged: (v) {
                      _book = v ?? '';
                      _page = 1;
                      _reload();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: TextField(
            controller: _searchCtrl,
            onSubmitted: (_) {
              _page = 1;
              _reload();
            },
            decoration: InputDecoration(
              isDense: true,
              hintText: '搜索英文单词或中文词义',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 60),
            itemCount: _list.length,
            itemBuilder: (context, i) {
              final w = _list[i];
              return Card(
                child: ListTile(
                  title: Row(
                    children: [
                      SpeakableWord(w.word.word,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: t.text),
                      const SizedBox(width: 8),
                      Text(w.word.pos,
                          style:
                              TextStyle(fontSize: 12, color: t.subText)),
                    ],
                  ),
                  subtitle: Text(
                    w.word.meaning,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: t.subText),
                  ),
                  trailing: _statusTag(w, t),
                ),
              );
            },
          ),
        ),
        // 分页
        Container(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _page > 1
                    ? () {
                        _page--;
                        _reload();
                      }
                    : null,
              ),
              Text('第 $_page / $pages 页',
                  style: TextStyle(fontSize: 13, color: t.subText)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _page < pages
                    ? () {
                        _page++;
                        _reload();
                      }
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusTag(WordWithProgress w, AppColors t) {
    final status = w.status;
    final (label, color) = switch (status) {
      'mastered' => ('已掌握', Colors.green),
      'wrong' => ('错词', Colors.red),
      'learning' => ('学习中', Colors.orange),
      _ => ('新词', t.subText),
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        Text('对${w.correctCount} 错${w.wrongCount}',
            style: TextStyle(fontSize: 11, color: t.subText)),
      ],
    );
  }
}
