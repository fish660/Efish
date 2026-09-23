import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../services.dart';
import '../widgets/word_widgets.dart';
import 'learn_flow.dart';

/// 错词本：默认闪卡模式（逐张翻面、自评认识/不认识），可切换列表模式。
class MistakesPage extends StatefulWidget {
  const MistakesPage({super.key});

  @override
  State<MistakesPage> createState() => _MistakesPageState();
}

class _MistakesPageState extends State<MistakesPage> {
  // 0 = 闪卡，1 = 列表
  int _mode = 0;

  // 闪卡状态
  List<WordWithProgress> _cards = [];
  int _index = 0;
  bool _flipped = false;
  bool _started = false;
  bool _finished = false;
  int _known = 0;
  int _unknown = 0;
  int _sessionId = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.c;
    final total = Services.mistakes(appState.currentBook).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Row(
            children: [
              Text('错词本',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: t.text)),
              const SizedBox(width: 10),
              Text('未掌握错词 $total 个',
                  style: TextStyle(fontSize: 13, color: t.subText)),
              const Spacer(),
              _modeSwitch(t),
              const SizedBox(width: 10),
              if (total > 0)
                TextButton.icon(
                  onPressed: () => _confirmClear(context),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('清除记录'),
                ),
            ],
          ),
        ),
        Expanded(
          child: _mode == 0 ? _flashcardView(t, total) : _listView(t),
        ),
      ],
    );
  }

  // ---------- 模式切换 ----------

  Widget _modeSwitch(AppColors t) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.field,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: t.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeSegment(t, 0, '闪卡', Icons.style_outlined),
          _modeSegment(t, 1, '列表', Icons.list),
        ],
      ),
    );
  }

  Widget _modeSegment(AppColors t, int mode, String label, IconData icon) {
    final sel = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? t.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 15, color: sel ? Colors.white : t.subText),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    color: sel ? Colors.white : t.subText)),
          ],
        ),
      ),
    );
  }

  // ---------- 闪卡 ----------

  Widget _flashcardView(AppColors t, int total) {
    if (total == 0) {
      return _empty(t, '太棒了，当前没有错词！');
    }
    if (!_started) {
      return _startCover(t, total);
    }
    if (_finished) {
      return _resultView(t);
    }
    final w = _cards[_index];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Column(
        children: [
          const SizedBox(height: 6),
          // 进度
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('第 ${_index + 1} / ${_cards.length} 张',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.text)),
              const SizedBox(width: 16),
              Text('认识 $_known',
                  style: TextStyle(
                      fontSize: 12, color: Colors.green.shade700)),
              const SizedBox(width: 10),
              Text('不认识 $_unknown',
                  style: TextStyle(
                      fontSize: 12, color: Colors.red.shade600)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_index + (_flipped ? 0.5 : 0)) / _cards.length,
              minHeight: 6,
              backgroundColor: t.field,
              valueColor: AlwaysStoppedAnimation(t.primary),
            ),
          ),
          const SizedBox(height: 22),
          // 卡片
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: GestureDetector(
              onTap: () => setState(() => _flipped = !_flipped),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.96, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: _flipped
                    ? _backCard(t, w, key: const ValueKey('back'))
                    : _frontCard(t, w, key: const ValueKey('front')),
              ),
            ),
          ),
          const SizedBox(height: 22),
          // 操作按钮
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _flipped
                ? Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () => _answer(false),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('还不认识'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () => _answer(true),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('认识'),
                        ),
                      ),
                    ],
                  )
                : Container(
                    height: 48,
                    alignment: Alignment.center,
                    child: Text('先在心里回想英文，再点击卡片查看答案',
                        style: TextStyle(fontSize: 13, color: t.subText)),
                  ),
          ),
        ],
      ),
    );
  }

  /// 开始封面
  Widget _startCover(AppColors t, int total) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.style_outlined, size: 56, color: t.primary),
                const SizedBox(height: 16),
                Text('错词闪卡复习',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: t.text)),
                const SizedBox(height: 10),
                Text('本轮共 $total 张错词卡。\n'
                    '先看中文回忆英文，点击卡片翻面查看，\n'
                    '再如实标记“认识 / 还不认识”。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.7, color: t.subText)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: t.primary,
                    minimumSize: const Size(200, 46),
                  ),
                  onPressed: _startRound,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('开始闪卡'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 正面：看中文回忆英文
  Widget _frontCard(AppColors t, WordWithProgress w, {required Key key}) {
    return Card(
      key: key,
      child: Container(
        height: 360,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _tag(t, w.word.pos, t.primary),
                const Spacer(),
                Text('错 ${w.wrongCount} 次',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade600)),
              ],
            ),
            Expanded(
              child: Center(
                child: Text(
                  w.word.meaning,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                      color: t.text),
                ),
              ),
            ),
            Center(
              child: Text('点击卡片查看英文',
                  style: TextStyle(fontSize: 12, color: t.subText)),
            ),
          ],
        ),
      ),
    );
  }

  /// 背面：英文 + 音标 + 例句
  Widget _backCard(AppColors t, WordWithProgress w, {required Key key}) {
    return Card(
      key: key,
      child: Container(
        height: 360,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _tag(t, w.word.pos, t.primary),
                const Spacer(),
                Text('阶段 ${w.reviewStage}',
                    style: TextStyle(fontSize: 12, color: t.subText)),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: SpeakableWord(
                w.word.word,
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: t.primary,
              ),
            ),
            if (w.word.phonetic.isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(w.word.phonetic,
                    style: ipaTextStyle(fontSize: 15, color: t.subText)),
              ),
            ],
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 12),
            Text('中文释义',
                style: TextStyle(fontSize: 12, color: t.subText)),
            const SizedBox(height: 4),
            Text(w.word.meaning,
                style: TextStyle(fontSize: 15, height: 1.5, color: t.text)),
            if (w.word.example.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('例句', style: TextStyle(fontSize: 12, color: t.subText)),
              const SizedBox(height: 4),
              Text(w.word.example,
                  style: TextStyle(fontSize: 13, height: 1.5, color: t.text)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tag(AppColors t, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text.isEmpty ? '—' : text,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }

  /// 结果页
  Widget _resultView(AppColors t) {
    final acc = _cards.isEmpty
        ? 0.0
        : (_known * 100.0 / _cards.length);
    final remaining = Services.mistakes(appState.currentBook).length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined,
                    size: 56, color: Colors.green.shade600),
                const SizedBox(height: 16),
                Text('本轮闪卡完成',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: t.text)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _resultStat(t, '认识', '$_known', Colors.green.shade700),
                    const SizedBox(width: 28),
                    _resultStat(t, '还不认识', '$_unknown', Colors.red.shade600),
                    const SizedBox(width: 28),
                    _resultStat(t, '正确率', '${acc.toStringAsFixed(0)}%', t.primary),
                  ],
                ),
                const SizedBox(height: 24),
                if (remaining > 0)
                  Text('仍有 $remaining 个错词待巩固',
                      style: TextStyle(fontSize: 13, color: t.subText)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    if (remaining > 0)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: t.primary,
                            minimumSize: const Size(160, 44)),
                        onPressed: _startRound,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('再来一轮'),
                      ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(160, 44)),
                      onPressed: () => setState(() {
                        _mode = 1;
                        _started = false;
                        _finished = false;
                      }),
                      icon: const Icon(Icons.list),
                      label: const Text('查看列表'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultStat(AppColors t, String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: t.subText)),
      ],
    );
  }

  void _startRound() {
    final list = Services.mistakes(appState.currentBook);
    if (list.isEmpty) {
      setState(() {
        _started = false;
        _finished = false;
      });
      return;
    }
    final sid = Services.createSession('review', 'en', appState.currentBook);
    setState(() {
      _cards = list;
      _index = 0;
      _known = 0;
      _unknown = 0;
      _flipped = false;
      _started = true;
      _finished = false;
      _sessionId = sid;
    });
  }

  void _answer(bool known) {
    final w = _cards[_index];
    Services.recordFlashcard(_sessionId, w.word.id, known);
    setState(() {
      if (known) {
        _known++;
      } else {
        _unknown++;
      }
      if (_index >= _cards.length - 1) {
        Services.finishFlashcardSession(
            _sessionId, _cards.length, _known);
        _finished = true;
      } else {
        _index++;
        _flipped = false;
      }
    });
  }

  // ---------- 列表 ----------

  Widget _listView(AppColors t) {
    final list = Services.mistakes(appState.currentBook);
    if (list.isEmpty) {
      return _empty(t, '太棒了，没有错词！');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final w = list[i];
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
                    style: TextStyle(fontSize: 12, color: t.subText)),
              ],
            ),
            subtitle: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: w.word.meaning,
                    style: TextStyle(fontSize: 12, color: t.subText)),
                if (w.word.phonetic.isNotEmpty)
                  TextSpan(
                      text: '  ${w.word.phonetic}',
                      style: ipaTextStyle(fontSize: 12, color: t.subText)),
              ]),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('错 ${w.wrongCount} · 对 ${w.correctCount}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.red.shade600)),
                Text('阶段${w.reviewStage}',
                    style: TextStyle(fontSize: 11, color: t.subText)),
              ],
            ),
            onTap: () => _reviewOne(context, w),
          ),
        );
      },
    );
  }

  Widget _empty(AppColors t, String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sentiment_satisfied_outlined,
              size: 56, color: Colors.green.shade600),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(fontSize: 14, color: t.subText)),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除错词记录？'),
        content: const Text('仅重置错误统计，不会删除单词本身。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Services.clearMistakes(appState.currentBook);
              Navigator.pop(ctx);
              setState(() {
                _started = false;
                _finished = false;
              });
            },
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }

  void _reviewOne(BuildContext context, dynamic w) {
    final sid = Services.createSession('review', 'en', appState.currentBook);
    Services.addRecord(sid, w.word.id);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => TestPage(
        sessionId: sid,
        words: [w.word],
        title: '立即复习 · ${w.word.word}',
        cnMode: false,
        onDone: (_) => setState(() {}),
      ),
    ));
  }
}
