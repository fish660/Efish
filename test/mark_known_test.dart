import 'package:flutter_test/flutter_test.dart';
import 'package:efish_app/db.dart';
import 'package:efish_app/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('熟悉阶段直接标记已学会：进入学习库 + 明天复习 + 评分不重复', () async {
    await AppDb.init();
    final db = AppDb.instance;

    final words = Services.pickNewWords(4, null);
    expect(words.length, greaterThanOrEqualTo(4),
        reason: '测试库应至少还有 4 个未学习单词');
    final sid = Services.createSession('new', 'en', null);
    for (final w in words) {
      Services.addRecord(sid, w.id);
    }

    // 前 2 个在熟悉阶段直接标记“已学会”
    final knownIds = [words[0].id, words[1].id];
    Services.markWordsKnown(sid, knownIds);

    final tomorrow =
        Services.todayStr(DateTime.now().add(const Duration(days: 1)));
    for (final id in knownIds) {
      final p = db.select(
          'SELECT status, correct_count, wrong_count, review_stage, next_review_at '
          'FROM word_progress WHERE word_id=?',
          [id]);
      expect(p, isNotEmpty, reason: '已标记词应写入 progress');
      expect(p.first['status'], 'learning');
      expect(p.first['correct_count'], 1);
      expect(p.first['wrong_count'], 0);
      expect(p.first['review_stage'], 1);
      // 已学会仍安排一轮复习：明天到期
      expect((p.first['next_review_at'] as String).substring(0, 10), tomorrow);
    }

    // 剩余 2 个进入默写：一个答对、一个答错
    final answers = <int, String>{
      words[2].id: words[2].word,
      words[3].id: '___definitely_wrong___',
    };
    final result = Services.gradeSession(sid, answers, false);

    // 4 题：2 个已标记(对) + 1 默写对 + 1 默写错 = 3 对 1 错
    expect(result['total'], 4);
    expect(result['correct'], 3);
    expect(result['wrong'], 1);

    // 已标记的词在评分时不被重复更新：correct_count 仍为 1
    final p0 = db.select(
        'SELECT correct_count FROM word_progress WHERE word_id=?',
        [words[0].id]);
    expect(p0.first['correct_count'], 1, reason: '已标记词不应被重复计分');

    // 已标记词的明细记录为“已学会”且判对
    final rec = db.select(
        'SELECT user_answer, is_correct FROM study_records '
        'WHERE session_id=? AND word_id=?',
        [sid, words[0].id]);
    expect(rec.first['is_correct'], 1);
    expect(rec.first['user_answer'], contains('已学会'));
  });
}
