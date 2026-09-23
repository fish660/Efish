import 'package:flutter_test/flutter_test.dart';
import 'package:efish_app/db.dart';
import 'package:efish_app/services.dart';

/// Efish 2.1 词书隔离、主题持久化、内置词书数量测试
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bookA = 'test_隔离词书A';
  const bookB = 'test_隔离词书B';
  const sameWord = 'zzz_isolate_word';

  setUpAll(() async {
    await AppDb.init();
  });

  tearDownAll(() {
    final db = AppDb.instance;
    for (final b in [bookA, bookB]) {
      // 先删篇章日志，再删会话，避免外键约束
      final sids = db
          .select('SELECT id FROM study_sessions WHERE book_name=?', [b])
          .map((r) => r['id'])
          .toList();
      for (final sid in sids) {
        db.execute('DELETE FROM study_logs WHERE session_id=?', [sid]);
      }
      final ids = db.select('SELECT id FROM words WHERE book_name=?', [b]);
      for (final r in ids) {
        final id = r['id'] as int;
        db.execute('DELETE FROM word_progress WHERE word_id=?', [id]);
        db.execute('DELETE FROM study_records WHERE word_id=?', [id]);
      }
      db.execute('DELETE FROM study_sessions WHERE book_name=?', [b]);
      db.execute('DELETE FROM words WHERE book_name=?', [b]);
    }
  });

  int addWord(String book, String word) {
    final db = AppDb.instance;
    db.execute(
      "INSERT OR IGNORE INTO words(word, normalized_word, pos, meaning, phonetic, "
      "example, book_name, aliases, created_at) "
      "VALUES (?,?,?,?,?,?,?,?,datetime('now','localtime'))",
      [word, word.toLowerCase(), 'n.', '测试义', '/t/', '', book, ''],
    );
    return db
        .select(
            'SELECT id FROM words WHERE book_name=? AND normalized_word=?',
            [book, word.toLowerCase()])
        .first['id'] as int;
  }

  test('内置词书数量：红宝书 6548、六级 2003', () {
    final db = AppDb.instance;
    final cet6 = db
        .select('SELECT COUNT(*) c FROM words WHERE book_name=?',
            ['六级真题核心词汇'])
        .first['c'];
    final red = db
        .select('SELECT COUNT(*) c FROM words WHERE book_name=?',
            ['2027考研英语红宝书'])
        .first['c'];
    expect(cet6, 2003);
    expect(red, 6548);
    // 六级全部含音标
    final empty = db
        .select(
            "SELECT COUNT(*) c FROM words WHERE book_name='六级真题核心词汇' "
            "AND (phonetic IS NULL OR phonetic='')")
        .first['c'] as int;
    expect(empty, 0);
  });

  test('settings 主题持久化读写', () {
    AppDb.setSetting('theme_index', '2');
    expect(AppDb.getSetting('theme_index'), '2');
    AppDb.setSetting('theme_index', '1');
    expect(AppDb.getSetting('theme_index'), '1');
    AppDb.setSetting('theme_index', '0');
  });

  test('同一英文在不同词书是独立词条', () {
    final idA = addWord(bookA, sameWord);
    final idB = addWord(bookB, sameWord);
    expect(idA == idB, false);
  });

  test('学习进度与统计按词书隔离', () {
    final idA = addWord(bookA, sameWord);
    final idB = addWord(bookB, sameWord);

    // 仅在 A 书学习该词并答对
    final sid = Services.createSession('new', 'en', bookA);
    Services.addRecord(sid, idA);
    final res = Services.gradeSession(sid, {idA: sameWord}, false);
    expect(res['correct'], 1);

    final db = AppDb.instance;
    final pa = db
        .select('SELECT COUNT(*) c FROM word_progress WHERE word_id=?', [idA])
        .first['c'];
    final pb = db
        .select('SELECT COUNT(*) c FROM word_progress WHERE word_id=?', [idB])
        .first['c'];
    expect(pa, 1); // A 书有进度
    expect(pb, 0); // B 书无进度

    // 抽新词：A 书已学过不再出现，B 书仍为新词
    final newA =
        Services.pickNewWords(100, bookA).map((w) => w.id).contains(idA);
    final newB =
        Services.pickNewWords(100, bookB).map((w) => w.id).contains(idB);
    expect(newA, false);
    expect(newB, true);

    // 统计按书隔离：A 书今日有学习，B 书为 0
    expect(Services.todayLearned(bookA), greaterThanOrEqualTo(1));
    expect(Services.todayLearned(bookB), 0);
    expect(Services.dashboard(bookB)['learned'], 0);
    expect(Services.dashboard(bookA)['learned'], greaterThanOrEqualTo(1));
  });
}
