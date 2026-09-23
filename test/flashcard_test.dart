import 'package:flutter_test/flutter_test.dart';
import 'package:efish_app/db.dart';
import 'package:efish_app/services.dart';

/// 闪卡自评流程：不认识 -> 进入错词；认识 -> 累计正确；结束汇总。
/// 使用 BEGIN/ROLLBACK 包裹，测试结束回滚，不污染真实数据库。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('闪卡自评与错词进度', () async {
    await AppDb.init();
    final db = AppDb.instance;
    db.execute('BEGIN');
    try {
      final words = Services.pickNewWords(1, null);
      expect(words.length, greaterThanOrEqualTo(1));
      final w = words.first;

      final sid = Services.createSession('review', 'en', null);

      // 第一次：不认识 -> 写入 wrong_count=1，status=wrong
      Services.recordFlashcard(sid, w.id, false);
      var p = db.select(
          'SELECT * FROM word_progress WHERE word_id=?', [w.id]);
      expect(p.isNotEmpty, true);
      expect(p.first['wrong_count'], 1);
      expect(p.first['status'], 'wrong');

      // 错词本应包含该词，且带进度（错次为 1，而不是 0）
      final m = Services.mistakes(null)
          .where((x) => x.word.id == w.id)
          .toList();
      expect(m.length, 1);
      expect(m.first.wrongCount, 1);

      // 第二次：认识 -> correct_count=1，阶段回升
      Services.recordFlashcard(sid, w.id, true);
      p = db.select('SELECT * FROM word_progress WHERE word_id=?', [w.id]);
      expect(p.first['correct_count'], 1);
      expect(p.first['wrong_count'], 1);

      // 结束会话：汇总
      final r = Services.finishFlashcardSession(sid, 2, 1);
      expect(r['total'], 2);
      expect(r['correct'], 1);
      expect(r['wrong'], 1);
      final s = db.select(
          'SELECT completed FROM study_sessions WHERE id=?', [sid]);
      expect(s.first['completed'], 1);
    } finally {
      db.execute('ROLLBACK');
    }
  });
}
