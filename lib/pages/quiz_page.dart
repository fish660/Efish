import 'package:flutter/material.dart';

import '../main.dart';
import '../services.dart';
import 'learn_flow.dart';

/// 总测试：从当前词书抽取指定数量，可选 看中文默写英文 / 看英文默写中文
class QuizSetupPage extends StatefulWidget {
  const QuizSetupPage({super.key});

  @override
  State<QuizSetupPage> createState() => _QuizSetupPageState();
}

class _QuizSetupPageState extends State<QuizSetupPage> {
  int _count = 20;
  bool _cnMode = false;
  bool _custom = false;
  final _customCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.c;
    final total = Services.wordTotal(appState.currentBook);
    return Scaffold(
      appBar: AppBar(title: const Text('总测试')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text('从当前词书中随机抽取单词进行测试',
              style: TextStyle(fontSize: 14, color: t.subText)),
          const SizedBox(height: 6),
          Text('当前词书共 $total 词',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: t.text)),
          const SizedBox(height: 18),
          Text('抽取数量', style: TextStyle(fontSize: 13, color: t.subText)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [10, 20, 30, 50]
                .map((n) => ChoiceChip(
                      label: Text('$n 个'),
                      selected: !_custom && _count == n,
                      onSelected: (_) => setState(() {
                        _custom = false;
                        _count = n;
                      }),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('自定义数量'),
                selected: _custom,
                onSelected: (v) => setState(() => _custom = v),
              ),
              if (_custom)
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _customCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        isDense: true, hintText: '数量'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('测试方式', style: TextStyle(fontSize: 13, color: t.subText)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(
                avatar: const Icon(Icons.translate, size: 16),
                label: const Text('看中文默写英文'),
                selected: !_cnMode,
                onSelected: (_) => setState(() => _cnMode = false),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.menu_book, size: 16),
                label: const Text('看英文默写中文'),
                selected: _cnMode,
                onSelected: (_) => setState(() => _cnMode = true),
              ),
            ],
          ),
          if (_cnMode)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('默写中文规则：写对一个意思即正确；写多个意思时有一个出错即算错。',
                  style: TextStyle(fontSize: 11, color: t.subText)),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: t.primary,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始测试', style: TextStyle(fontSize: 15)),
          ),
          ],
        ),
      ),
    );
  }

  void _start() {
    try {
      var n = _count;
      if (_custom) {
        final v = int.tryParse(_customCtrl.text.trim());
        n = (v ?? 20).clamp(1, 1000);
      }
      final words = Services.quizWords(n, appState.currentBook);
      if (words.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('词库为空，请先导入单词')));
        return;
      }
      if (words.length < n) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('词库不足 $n 个，本次测试 ${words.length} 个')));
      }
      final sid = Services.createSession(
          'quiz', _cnMode ? 'cn' : 'en', appState.currentBook);
      for (final w in words) {
        Services.addRecord(sid, w.id);
      }
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => TestPage(
          sessionId: sid,
          words: words,
          title: _cnMode ? '总测试 · 看英文默写中文' : '总测试 · 看中文默写英文',
          cnMode: _cnMode,
        ),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')));
    }
  }
}

/// 总测试快捷入口（顶部按钮），直接进入设置页
class QuizPage extends StatelessWidget {
  const QuizPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const QuizSetupPage();
  }
}
