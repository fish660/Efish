import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../services.dart';
import '../widgets/word_widgets.dart';

/// 学习新词：数量设置 → 词表 → 默写测试 → 结果
class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  int _count = 20;
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
    final available = Services.newWordCount(appState.currentBook);
    final book = appState.currentBook ?? '全部词书';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text('学习新单词',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: t.text)),
        const SizedBox(height: 4),
        Text('当前词书：$book · 可用新词 $available 个',
            style: TextStyle(fontSize: 13, color: t.subText)),
        const SizedBox(height: 18),
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
        const SizedBox(height: 10),
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
        SizedBox(
          width: 220,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: t.primary,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始学习', style: TextStyle(fontSize: 15)),
          ),
        ),
        if (available == 0)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text('当前词书暂无未学习的单词，可切换词书或导入新词库。',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _start() {
    try {
      var n = _count;
      if (_custom) {
        final v = int.tryParse(_customCtrl.text.trim());
        n = (v ?? 20).clamp(1, 500);
      }
      final words = Services.pickNewWords(n, appState.currentBook);
      if (words.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('没有可学习的单词，请先导入词库')));
        return;
      }
      if (words.length < n) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('新单词不足 $n 个，本次学习 ${words.length} 个')));
      }
      final sid = Services.createSession('new', 'en', appState.currentBook);
      for (final w in words) {
        Services.addRecord(sid, w.id);
      }
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => WordListPage(sessionId: sid, words: words),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')));
    }
  }
}

/// 单词展示页
class WordListPage extends StatefulWidget {
  const WordListPage({super.key, required this.sessionId, required this.words});
  final int sessionId;
  final List<Word> words;

  @override
  State<WordListPage> createState() => _WordListPageState();
}

class _WordListPageState extends State<WordListPage> {
  bool _showExtra = false;
  // 熟悉阶段直接标记“已学会”的单词 id（点击行尾 →）
  final Set<int> _known = {};

  @override
  Widget build(BuildContext context) {
    final t = context.c;
    return Scaffold(
      appBar: AppBar(title: const Text('单词学习')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Text('共 ${widget.words.length} 个新单词，先熟悉一下吧',
                  style: TextStyle(fontSize: 14, color: t.subText)),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _showExtra = !_showExtra),
                icon: Icon(_showExtra ? Icons.visibility_off : Icons.visibility),
                label: Text(_showExtra ? '隐藏音标例句' : '显示音标例句'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: t.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: t.primary.withValues(alpha: .25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.arrow_forward, size: 16, color: t.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '点击每个单词右侧的 → 即表示“已学会”：该词直接计入已学习、'
                    '不再作为新词，并在明天进入第一轮复习；未标记的单词将进入默写测试。',
                    style: TextStyle(fontSize: 12, color: t.text, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  _rowHeader(t),
                  const Divider(height: 1),
                  ...widget.words.map((w) => _row(w, t)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: t.primary,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _beginTest,
            icon: const Icon(Icons.edit),
            label: Text(
                _known.isEmpty
                    ? '开始默写测试'
                    : '开始默写测试（已标记 ${_known.length} 个已学会）',
                style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  void _beginTest() {
    try {
      final knownWords =
          widget.words.where((w) => _known.contains(w.id)).toList();
      final knownIds = knownWords.map((w) => w.id).toSet();
      final remaining =
          widget.words.where((w) => !_known.contains(w.id)).toList();
      if (knownWords.isNotEmpty) {
        Services.markWordsKnown(widget.sessionId, knownIds.toList());
      }
      if (remaining.isEmpty) {
        final result = Services.gradeSession(widget.sessionId, {}, false);
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ResultPage(
            result: result,
            words: widget.words,
            answers: const {},
            cnMode: false,
            knownIds: knownIds,
          ),
        ));
        return;
      }
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => TestPage(
          sessionId: widget.sessionId,
          words: remaining,
          title: '看中文默写英文',
          cnMode: false,
          allWords: widget.words,
          knownIds: knownIds,
        ),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败：$e')));
    }
  }

  Widget _rowHeader(AppColors t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
                flex: 3,
                child: Text('英文单词',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: t.subText))),
            Expanded(
                flex: 1,
                child: Text('词性',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: t.subText))),
            Expanded(
                flex: 4,
                child: Text('中文词义',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: t.subText))),
            if (_showExtra)
              Expanded(
                  flex: 3,
                  child: Text('音标 / 例句',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: t.subText))),
            SizedBox(
              width: 56,
              child: Text('已学会',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: t.subText)),
            ),
          ],
        ),
      );

  Widget _row(Word w, AppColors t) {
    final known = _known.contains(w.id);
    final mainColor = known ? t.subText : t.text;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: known ? Colors.green.withValues(alpha: .07) : null,
          border: const Border(
              bottom: BorderSide(color: Color(0x11000000))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                flex: 3,
                child: SpeakableWord(
                  w.word,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: mainColor,
                )),
            Expanded(
                flex: 1,
                child: Text(w.pos,
                    style: TextStyle(fontSize: 13, color: t.subText))),
            Expanded(
                flex: 4,
                child: Text(w.meaning,
                    style: TextStyle(fontSize: 13, color: mainColor))),
            if (_showExtra)
              Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (w.phonetic.isNotEmpty)
                        Text(w.phonetic,
                            style: ipaTextStyle(
                                fontSize: 12, color: t.primary)),
                      if (w.example.isNotEmpty)
                        Text(w.example,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: t.subText)),
                    ],
                  )),
            SizedBox(width: 56, child: _knownToggle(w, t)),
          ],
        ),
      );
  }

  /// 行尾“已学会”开关：→ 标记，再次点击对勾可取消
  Widget _knownToggle(Word w, AppColors t) {
    final known = _known.contains(w.id);
    return Center(
      child: IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: known ? '取消“已学会”标记' : '标记为已学会（计入学习，明天复习）',
        icon: known
            ? Icon(Icons.check_circle, color: Colors.green.shade600, size: 24)
            : Icon(Icons.arrow_forward, color: t.primary, size: 22),
        onPressed: () => setState(() {
          if (!_known.remove(w.id)) _known.add(w.id);
        }),
      ),
    );
  }
}

/// 默写测试页（一次显示全部题目）
class TestPage extends StatefulWidget {
  const TestPage({
    super.key,
    required this.sessionId,
    required this.words,
    required this.title,
    required this.cnMode,
    this.onDone,
    this.allWords = const [],
    this.knownIds = const {},
  });

  final int sessionId;
  final List<Word> words;
  final String title;
  final bool cnMode;
  final void Function(Map<String, dynamic> result)? onDone;
  // 熟悉阶段已直接标记“已学会”的词（不参与默写，但计入结果）
  final List<Word> allWords;
  final Set<int> knownIds;

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final Map<int, TextEditingController> _ctrls = {};
  bool _submitting = false;
  // 进入默写时随机打乱题目顺序，避免与熟悉页顺序一致
  late final List<Word> _questions;

  @override
  void initState() {
    super.initState();
    _questions = [...widget.words]..shuffle();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.c;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              '共 ${_questions.length} 题 · 在下方输入框作答（题目顺序已随机打乱）',
              style: TextStyle(fontSize: 13, color: t.subText),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 80),
              itemCount: _questions.length,
              itemBuilder: (context, i) {
                final w = _questions[i];
                final ctrl = _ctrls.putIfAbsent(
                    w.id, () => TextEditingController());
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        widget.cnMode
                            ? Row(children: [
                                Text('${i + 1}. ',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: t.text)),
                                SpeakableWord(
                                  w.word,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: t.text,
                                ),
                              ])
                            : Text('${i + 1}. ${w.meaning}',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: t.text)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (w.pos.isNotEmpty)
                              Text('${w.pos}  ',
                                  style: TextStyle(
                                      fontSize: 12, color: t.subText)),
                            if (w.phonetic.isNotEmpty)
                              Text(w.phonetic,
                                  style: ipaTextStyle(
                                      fontSize: 12, color: t.subText)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: ctrl,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: widget.cnMode ? '默写中文词义' : '默写英文单词',
                            border: const OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: t.primary,
        onPressed: _submitting ? null : () => _submit(),
        icon: const Icon(Icons.check),
        label: Text(_submitting ? '提交中…' : '提交答案'),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final answers = <int, String>{};
    for (final w in widget.words) {
      answers[w.id] = _ctrls[w.id]?.text ?? '';
    }
    setState(() => _submitting = true);
    try {
      final result =
          Services.gradeSession(widget.sessionId, answers, widget.cnMode);
      if (!mounted) return;
      final resultWords =
          widget.allWords.isNotEmpty ? widget.allWords : widget.words;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => ResultPage(result: result, words: resultWords,
            answers: answers, cnMode: widget.cnMode, onDone: widget.onDone,
            knownIds: widget.knownIds),
      ));
    } catch (e) {
      // 评分失败时必须复位按钮，否则会一直停在“提交中…”
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red.shade600,
        content: Text('提交失败：$e'),
      ));
    }
  }
}

/// 结果页
class ResultPage extends StatelessWidget {
  const ResultPage({
    super.key,
    required this.result,
    required this.words,
    required this.answers,
    required this.cnMode,
    this.onDone,
    this.knownIds = const {},
  });

  final Map<String, dynamic> result;
  final List<Word> words;
  final Map<int, String> answers;
  final bool cnMode;
  final void Function(Map<String, dynamic> result)? onDone;
  final Set<int> knownIds;

  @override
  Widget build(BuildContext context) {
    final t = context.c;
    final total = result['total'] as int;
    final correct = result['correct'] as int;
    final wrong = result['wrong'] as int;
    final acc = result['accuracy'] as double;
    return Scaffold(
      appBar: AppBar(
          title: const Text('测试结果'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '${acc.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: acc >= 80
                            ? Colors.green.shade600
                            : (acc >= 60
                                ? Colors.orange.shade700
                                : Colors.red.shade600)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _chip('总题数 $total', t),
                      const SizedBox(width: 8),
                      _chip('答对 $correct', t, Colors.green),
                      const SizedBox(width: 8),
                      _chip('答错 $wrong', t, Colors.red),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('本篇章已记录到「每日篇章收录」',
                      style: TextStyle(fontSize: 12, color: t.subText)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('题目',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: t.subText))),
                      Expanded(
                          child: Text('你的答案',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: t.subText))),
                      Expanded(
                          child: Text('正确答案',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: t.subText))),
                      SizedBox(
                          width: 46,
                          child: Text('结果',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: t.subText))),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ...words.map((w) {
                  final known = knownIds.contains(w.id);
                  final ua = known ? '已学会' : (answers[w.id] ?? '');
                  final ok = known ||
                      (cnMode
                          ? Services.checkCn(ua, w.meaning)
                          : Services.checkEn(ua, w.word, w.aliases));
                  final correctText = cnMode ? w.meaning : w.word;
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                        border: Border(
                            bottom:
                                BorderSide(color: Color(0x11000000)))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: cnMode
                                ? SpeakableWord(w.word,
                                    fontSize: 13, color: t.text)
                                : Text(w.meaning,
                                    style: TextStyle(
                                        fontSize: 13, color: t.text))),
                        Expanded(
                            child: Text(ua,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: ok
                                        ? Colors.green.shade700
                                        : Colors.red.shade700))),
                        Expanded(
                            child: cnMode
                                ? Text(correctText,
                                    style: TextStyle(
                                        fontSize: 13, color: t.text))
                                : SpeakableWord(w.word,
                                    fontSize: 13, color: t.text)),
                        SizedBox(
                          width: 46,
                          child: Icon(
                            ok ? Icons.check_circle : Icons.cancel,
                            color: ok
                                ? Colors.green.shade600
                                : Colors.red.shade600,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: t.primary,
                padding: const EdgeInsets.symmetric(vertical: 13)),
            onPressed: () {
              Navigator.popUntil(context, (r) => r.isFirst);
            },
            icon: const Icon(Icons.home),
            label: const Text('返回首页', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, AppColors t, [Color? color]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (color ?? t.primary).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? t.primary)),
    );
  }
}

/// 复习页
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  @override
  Widget build(BuildContext context) {
    final t = context.c;
    final due = Services.dueReviews(appState.currentBook);
    if (due.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration_outlined,
                size: 56, color: t.subText.withValues(alpha: .5)),
            const SizedBox(height: 12),
            Text('今天没有到期需要复习的单词',
                style: TextStyle(fontSize: 15, color: t.subText)),
            const SizedBox(height: 4),
            Text('坚持学习，明天会有的~',
                style: TextStyle(fontSize: 12, color: t.subText)),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('今日复习',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: t.text)),
              const SizedBox(height: 4),
              Text('共 ${due.length} 个到期单词，按 1/3/7/15/30 天记忆曲线安排',
                  style: TextStyle(fontSize: 13, color: t.subText)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            itemCount: due.length,
            itemBuilder: (context, i) {
              final w = due[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.refresh,
                      color: t.primary.withValues(alpha: .7)),
                  title: SpeakableWord(w.word.word,
                      fontSize: 14, fontWeight: FontWeight.w600),
                  subtitle: Text('${w.word.pos}  ${w.word.meaning}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(
                    '阶段${w.reviewStage}/${Services.reviewIntervals.length}',
                    style: TextStyle(fontSize: 12, color: t.subText),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: t.primary,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () {
              final sid = Services.createSession(
                  'review', 'en', appState.currentBook);
              for (final w in due) {
                Services.addRecord(sid, w.word.id);
              }
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => TestPage(
                  sessionId: sid,
                  words: due.map((e) => e.word).toList(),
                  title: '复习 · 看中文默写英文',
                  cnMode: false,
                ),
              ));
            },
            icon: const Icon(Icons.edit),
            label: const Text('开始复习默写', style: TextStyle(fontSize: 15)),
          ),
        ),
      ],
    );
  }
}
