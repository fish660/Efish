import 'package:flutter_test/flutter_test.dart';
import 'package:efish_app/db.dart';
import 'package:efish_app/services.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('services 全链路（含评分/进度/外键）', () async {
    final dataDir = await AppDb.dataDir();
    print('dataDir = $dataDir');
    await AppDb.init();
    final db = AppDb.instance;

    final words = Services.pickNewWords(3, null);
    print('pickNewWords -> ${words.length} 个');
    expect(words.length, greaterThanOrEqualTo(1));

    final sid = Services.createSession('new', 'en', null);
    print('createSession -> sid=$sid');
    for (final w in words) {
      Services.addRecord(sid, w.id);
    }
    print('addRecord 完成');

    // 答案：第 1 个答对，其余答错（空答案）
    final answers = <int, String>{};
    for (var i = 0; i < words.length; i++) {
      answers[words[i].id] = i == 0 ? words[i].word : '___wrong___';
    }
    final result = Services.gradeSession(sid, answers, false);
    print('gradeSession -> $result');
    expect(result['total'], words.length);
    expect(result['correct'], 1);
    expect(result['wrong'], words.length - 1);
    expect((result['accuracy'] as double).toStringAsFixed(1),
        (100 / words.length).toStringAsFixed(1));

    // word_progress 应已写入（这是提交卡死的根因：外键指向 words_old）
    final pCount = db.select(
        'SELECT COUNT(*) c FROM word_progress WHERE word_id IN (${words.map((_) => '?').join(',')})',
        words.map((w) => w.id).toList());
    print('word_progress 写入 -> ${pCount.first['c']}');
    expect(pCount.first['c'], words.length);

    // 会话应标记完成
    final s = db.select('SELECT completed, correct_count, wrong_count FROM study_sessions WHERE id=?', [sid]);
    print('session -> ${s.first}');
    expect(s.first['completed'], 1);

    // 外键完整性检查：不能再有违反
    db.execute('PRAGMA foreign_keys=ON;');
    final violations = db.select('PRAGMA foreign_key_check');
    print('foreign_key_check 违规数 -> ${violations.length}');
    // 仅校验本次涉及的表无违规
    final bad = violations.where((r) =>
        (r['table'] == 'word_progress') || (r['table'] == 'study_records')).toList();
    expect(bad, isEmpty);

    // 答案规范化
    expect(Services.checkEn('  Abandon  ', 'abandon', ''), true);
    expect(Services.checkEn('graphic', 'graphic', 'graphical'), true);
    expect(Services.checkEn('xyz', 'graphic', ''), false);
    // 中文：写对一个即正确；多写一个错的算错
    expect(Services.checkCn('图形', '图形；图表'), true);
    expect(Services.checkCn('图形；图表', '图形；图表'), true);
    expect(Services.checkCn('图形；错误', '图形；图表'), false);

    // 到期复习查询不报错
    final due = Services.dueReviews(null);
    print('dueReviews -> ${due.length}');

    // 总测试抽词不报错
    final quiz = Services.quizWords(5, null);
    print('quizWords -> ${quiz.length}');
  });
}
