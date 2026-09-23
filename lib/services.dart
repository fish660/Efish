import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import 'db.dart';
import 'models.dart';

/// 业务逻辑层：抽取、评分、复习计划、统计。
class Services {
  static const reviewIntervals = [1, 3, 7, 15, 30];

  static String todayStr([DateTime? d]) {
    final t = d ?? DateTime.now();
    return '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }

  static String nowStr() {
    final t = DateTime.now();
    return todayStr(t) + ' ' +
        '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')}:'
            '${t.second.toString().padLeft(2, '0')}';
  }

  /// 规范化英文答案
  static String normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// 判断默写英文是否正确（忽略大小写、首尾空格、连续空格）
  static bool checkEn(String userAnswer, String word, String aliases) {
    final u = normalize(userAnswer);
    if (u.isEmpty) return false;
    final answers = <String>{normalize(word)};
    for (final a in (aliases + ',').split(RegExp(r'[,，;；]'))) {
      final t = normalize(a);
      if (t.isNotEmpty) answers.add(t);
    }
    return answers.contains(u);
  }

  /// 判断默写中文是否正确：
  /// 只要默写对任意一个中文意思即正确；写了多个意思时，任何一个出错即整题算错。
  static bool checkCn(String userAnswer, String meaning) {
    final u = userAnswer.trim();
    if (u.isEmpty) return false;
    final correct = meaning
        .split(RegExp(r'[，,;；、/]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (correct.isEmpty) return false;
    final answers =
        u.split(RegExp(r'[，,;；、/]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (answers.isEmpty) return false;
    if (answers.length == 1) return correct.contains(answers.first);
    // 多个意思：每个都必须在正确集合中
    for (final a in answers) {
      if (!correct.contains(a)) return false;
    }
    return true;
  }

  // ---------- 查询 ----------

  static Database get _db => AppDb.instance;

  /// 词书列表
  static List<String> books() {
    final rs = _db.select(
        'SELECT DISTINCT book_name FROM words ORDER BY book_name');
    return rs.map((r) => r['book_name'] as String? ?? '默认词书').toList();
  }

  static int _count(String sql, [List<Object?> args = const []]) {
    final r = _db.select(sql, args);
    return r.isEmpty ? 0 : (r.first.values.first as int? ?? 0);
  }

  /// 未学习单词数量（可限定词书）
  static int newWordCount(String? book) {
    final b = book ?? '';
    return _count(
      'SELECT COUNT(*) FROM words w WHERE NOT EXISTS '
      '(SELECT 1 FROM word_progress p WHERE p.word_id=w.id) '
      '${b.isEmpty ? '' : 'AND w.book_name=?'}',
      b.isEmpty ? const [] : [b],
    );
  }

  /// 词书过滤参数（空或 null 表示全部词书）
  static List<Object?> _bArgs(String? book) {
    final b = book ?? '';
    return b.isEmpty ? const [] : [b];
  }

  /// study_records r JOIN words w 后追加的词书条件（接在 WHERE 条件之后）
  static String _bookAnd(String? book) =>
      (book == null || book.isEmpty) ? '' : ' AND w.book_name=?';

  /// 今日待复习数量（可限定词书）
  static int reviewCount(String? book) => dueReviews(book).length;

  /// 带进度的计数（progress p JOIN words w）
  static int _progressCount(String? book, String extra) {
    final b = book ?? '';
    final args = <Object?>[];
    final conds = <String>[extra];
    if (b.isNotEmpty) {
      conds.add('w.book_name=?');
      args.add(b);
    }
    return _count(
      'SELECT COUNT(*) FROM word_progress p JOIN words w ON w.id=p.word_id '
      'WHERE ${conds.join(' AND ')}',
      args,
    );
  }

  /// 首页统计（可限定词书；不同词书数据互不相通）
  static Map<String, int> dashboard(String? book) {
    final total = wordTotal(book);
    final learned = _progressCount(book, "p.status!='new'");
    final learning = _progressCount(book, "p.status='learning'");
    final mastered = _progressCount(book, "p.status='mastered'");
    final wrong = _progressCount(
        book, "p.status IN ('wrong','learning') AND p.wrong_count>0");
    return {
      'total': total,
      'learned': learned,
      'learning': learning,
      'mastered': mastered,
      'wrong': wrong,
    };
  }

  static double overallAccuracy(String? book) {
    final r = _db.select(
      'SELECT SUM(p.correct_count) c, SUM(p.wrong_count) w '
      'FROM word_progress p JOIN words w ON w.id=p.word_id '
      '${(book == null || book.isEmpty) ? '' : 'WHERE w.book_name=?'}',
      _bArgs(book),
    );
    final c = r.first['c'] as int? ?? 0;
    final w = r.first['w'] as int? ?? 0;
    if (c + w == 0) return 0;
    return c * 100.0 / (c + w);
  }

  static int todayLearned(String? book) => _count(
      'SELECT COUNT(*) FROM study_records r JOIN words w ON w.id=r.word_id '
      'WHERE substr(r.created_at,1,10)=?${_bookAnd(book)}',
      [todayStr(), ..._bArgs(book)]);

  static int weekLearned(String? book) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    return _count(
        'SELECT COUNT(*) FROM study_records r JOIN words w ON w.id=r.word_id '
        'WHERE substr(r.created_at,1,10)>=?${_bookAnd(book)}',
        [todayStr(start), ..._bArgs(book)]);
  }

  static int totalAnswered(String? book) => _count(
      'SELECT COUNT(*) FROM study_records r JOIN words w ON w.id=r.word_id '
      'WHERE r.is_correct IS NOT NULL${_bookAnd(book)}',
      _bArgs(book));

  /// 连续学习天数（从今天或昨天往回连续；可限定词书）
  static int streakDays(String? book) {
    final dates = _db
        .select(
          'SELECT DISTINCT substr(r.created_at,1,10) d FROM study_records r '
          'JOIN words w ON w.id=r.word_id WHERE 1=1${_bookAnd(book)}',
          _bArgs(book),
        )
        .map((r) => r['d'] as String)
        .toSet();
    if (dates.isEmpty) return 0;
    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    if (!dates.contains(todayStr(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var days = 0;
    while (dates.contains(todayStr(cursor))) {
      days++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return days;
  }

  /// 最近 7 天学习数量（可限定词书）
  static List<(String, int)> last7Days(String? book) {
    final db = _db;
    final today = DateTime.now();
    final counts = <String, int>{};
    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      counts[todayStr(d)] = 0;
    }
    for (final r in db.select(
      "SELECT substr(r.created_at,1,10) d, COUNT(*) c FROM study_records r "
      "JOIN words w ON w.id=r.word_id "
      "WHERE r.is_correct IS NOT NULL AND substr(r.created_at,1,10)>=?${_bookAnd(book)} "
      "GROUP BY substr(r.created_at,1,10)",
      [todayStr(today.subtract(const Duration(days: 6))), ..._bArgs(book)],
    )) {
      final d = r['d'] as String;
      if (counts.containsKey(d)) counts[d] = r['c'] as int? ?? 0;
    }
    final ordered = counts.keys.toList()..sort();
    return ordered.map((k) => (k, counts[k]!)).toList();
  }

  /// 每日学习数量（按词书，从答题明细实时统计）：date -> 去重词数
  static Map<String, int> dailyLogs(String? book) {
    final m = <String, int>{};
    for (final r in _db.select(
      'SELECT substr(r.created_at,1,10) d, COUNT(DISTINCT r.word_id) c '
      'FROM study_records r JOIN words w ON w.id=r.word_id '
      'WHERE 1=1${_bookAnd(book)} GROUP BY d',
      _bArgs(book),
    )) {
      m[r['d'] as String] = r['c'] as int? ?? 0;
    }
    return m;
  }

  /// 累计学习天数（可限定词书）
  static int totalStudyDays(String? book) => _count(
      'SELECT COUNT(DISTINCT substr(r.created_at,1,10)) FROM study_records r '
      'JOIN words w ON w.id=r.word_id WHERE 1=1${_bookAnd(book)}',
      _bArgs(book));

  // ---------- 新词学习 ----------

  /// 抽取指定数量未学习单词（排除今日已开始学习的），不足则返回全部
  static List<Word> pickNewWords(int count, String? book) {
    final b = book ?? '';
    final today = todayStr();
    final excluded = _db
        .select(
            "SELECT DISTINCT r.word_id FROM study_records r "
            "JOIN study_sessions s ON s.id=r.session_id "
            "WHERE s.session_type='new' AND substr(s.created_at,1,10)=?",
            [today])
        .map((r) => r['word_id'] as int)
        .toSet();
    final sql = 'SELECT * FROM words w WHERE NOT EXISTS '
        '(SELECT 1 FROM word_progress p WHERE p.word_id=w.id) '
        '${b.isEmpty ? '' : 'AND w.book_name=?'} '
        '${excluded.isEmpty ? '' : 'AND w.id NOT IN (${excluded.map((_) => '?').join(',')})'} '
        'ORDER BY RANDOM() LIMIT ?';
    final args = <Object?>[
      if (b.isNotEmpty) b,
      ...excluded,
      count,
    ];
    return _db.select(sql, args).map(Word.fromRow).toList();
  }

  /// 创建学习会话（new/review/quiz）
  static int createSession(String type, String testMode, String? book) {
    _db.execute(
        'INSERT INTO study_sessions (session_type, test_mode, book_name, created_at) '
        'VALUES (?,?,?,?)',
        [type, testMode, book, nowStr()]);
    return _db.lastInsertRowId;
  }

  static void addRecord(int sessionId, int wordId) {
    _db.execute(
        'INSERT INTO study_records (session_id, word_id, created_at) VALUES (?,?,?)',
        [sessionId, wordId, nowStr()]);
  }

  /// 熟悉阶段直接标记“已学会”：等同于答对一次——
  /// 进入学习库（不再作为新词被抽取），并安排 1 天后进行第一轮复习。
  /// 立即写入 progress 与 study_records（is_correct=1），这些词不再进入默写。
  static void markWordsKnown(int sessionId, List<int> wordIds) {
    if (wordIds.isEmpty) return;
    final db = _db;
    final today = todayStr();
    final now = nowStr();
    for (final wid in wordIds) {
      _updateProgress(wid, true, false, today);
      db.execute(
          'UPDATE study_records SET user_answer=?, is_correct=1, created_at=? '
          'WHERE session_id=? AND word_id=? AND is_correct IS NULL',
          ['已学会（直接标记）', now, sessionId, wid]);
    }
  }

  /// 评分并更新进度、会话。answers: {wordId: userAnswer}
  static Map<String, dynamic> gradeSession(
      int sessionId, Map<int, String> answers, bool cnMode) {
    final db = _db;
    final recs = db.select(
        'SELECT r.id, r.word_id, r.is_correct, r.user_answer, w.word, w.meaning, w.aliases, w.book_name '
        'FROM study_records r JOIN words w ON w.id=r.word_id WHERE r.session_id=?',
        [sessionId]);
    var correct = 0;
    final today = todayStr();
    final now = nowStr();
    final todayWords = <int>{};
    final todayCorrect = <int>{};
    final bookNames = <String>{};
    for (final r in recs) {
      final wid = r['word_id'] as int;
      final word = r['word'] as String;
      final meaning = r['meaning'] as String? ?? '';
      final aliases = r['aliases'] as String? ?? '';
      bookNames.add(r['book_name'] as String? ?? '默认词书');
      final pre = r['is_correct'];
      bool ok;
      var ua = (r['user_answer'] as String?) ?? '';
      if (pre != null) {
        // 熟悉阶段已直接标记“已学会”，按既有判分计入，不重复更新进度
        ok = (pre as int) == 1;
      } else {
        ua = (answers[wid] ?? '').trim();
        ok = cnMode ? checkCn(ua, meaning) : checkEn(ua, word, aliases);
        db.execute(
            'UPDATE study_records SET user_answer=?, is_correct=?, created_at=? '
            'WHERE id=?',
            [ua, ok ? 1 : 0, now, r['id'] as int]);
        _updateProgress(wid, ok, cnMode, today);
      }
      if (ok) {
        correct++;
        todayCorrect.add(wid);
      }
      todayWords.add(wid);
    }
    final total = recs.length;
    final wrong = total - correct;
    final acc = total == 0 ? 0.0 : correct * 100.0 / total;
    final session = db.select(
        'SELECT session_type FROM study_sessions WHERE id=?', [sessionId]);
    final sType = session.isEmpty ? 'new' : session.first['session_type'] as String;
    db.execute(
        'UPDATE study_sessions SET total_count=?, correct_count=?, wrong_count=?, '
        'accuracy=?, completed=1, completed_at=? WHERE id=?',
        [total, correct, wrong, acc, now, sessionId]);
    // 每日日志：新词/复习/总测试完成即记学习日
    _bumpDailyLog(today, todayWords.length);
    // 篇章记录（复习/总测试不重复生成已有逻辑，这里统一为完成会话生成篇章）
    _createStudyLog(sessionId, today, total, acc, db);
    return {
      'total': total,
      'correct': correct,
      'wrong': wrong,
      'accuracy': acc,
      'type': sType,
    };
  }

  static void _updateProgress(int wordId, bool ok, bool cnMode, String today) {
    final db = _db;
    final rows = db
        .select('SELECT * FROM word_progress WHERE word_id=?', [wordId]);
    final now = nowStr();
    if (rows.isEmpty) {
      var stage = ok ? 1 : 0;
      var status = ok ? 'learning' : 'wrong';
      final next = ok && stage >= 1
          ? _nextReviewDate(today, min(stage, 5) - 1)
          : _nextReviewDate(today, 0);
      db.execute(
          'INSERT INTO word_progress (word_id,status,first_learned_at,last_reviewed_at,'
          'next_review_at,correct_count,wrong_count,review_stage,created_at,updated_at) '
          'VALUES (?,?,?,?,?,?,?,?,?,?)',
          [wordId, status, now, now, next, ok ? 1 : 0, ok ? 0 : 1, stage, now, now]);
      return;
    }
    final row = rows.first;
    var stage = row['review_stage'] as int? ?? 0;
    var c = row['correct_count'] as int? ?? 0;
    var w = row['wrong_count'] as int? ?? 0;
    if (ok) {
      c++;
      stage++;
    } else {
      w++;
      stage = max(0, stage - 1);
    }
    final status = stage >= 5 && ok
        ? 'mastered'
        : (ok ? 'learning' : 'wrong');
    final next = _nextReviewDate(today, ok ? min(stage, 5) - 1 : 0);
    db.execute(
        'UPDATE word_progress SET status=?, last_reviewed_at=?, next_review_at=?, '
        'correct_count=?, wrong_count=?, review_stage=?, updated_at=? WHERE word_id=?',
        [status, now, next, c, w, stage, now, wordId]);
  }

  static String _nextReviewDate(String today, int stageIdx) {
    final days = stageIdx >= 0 && stageIdx < reviewIntervals.length
        ? reviewIntervals[stageIdx]
        : 1;
    final t = DateTime.parse(today).add(Duration(days: days));
    return todayStr(t);
  }

  static void _bumpDailyLog(String today, int count) {
    final db = _db;
    final rows = db.select('SELECT id, learned_count FROM daily_logs WHERE log_date=?', [today]);
    final now = nowStr();
    if (rows.isEmpty) {
      db.execute('INSERT INTO daily_logs (log_date, learned_count, created_at, updated_at) '
          'VALUES (?,?,?,?)', [today, count, now, now]);
    } else {
      final total = (rows.first['learned_count'] as int? ?? 0) + count;
      db.execute('UPDATE daily_logs SET learned_count=?, updated_at=? WHERE log_date=?',
          [total, now, today]);
    }
  }

  static void _createStudyLog(int sessionId, String today, int wordCount,
      double accuracy, Database db) {
    final exists = _count('SELECT COUNT(*) FROM study_logs WHERE session_id=?', [sessionId]);
    if (exists > 0) return;
    final seqRows = db.select(
        'SELECT COUNT(*) c FROM study_logs WHERE log_date=?', [today]);
    final seq = (seqRows.first['c'] as int? ?? 0) + 1;
    db.execute(
        'INSERT INTO study_logs (log_date, session_id, sequence, word_count, accuracy, created_at) '
        'VALUES (?,?,?,?,?,?)',
        [today, sessionId, seq, wordCount, accuracy, nowStr()]);
  }

  // ---------- 复习 ----------

  static List<WordWithProgress> dueReviews(String? book) {
    final b = book ?? '';
    final today = todayStr();
    final sql = 'SELECT w.*, p.status, p.correct_count, p.wrong_count, p.review_stage '
        'FROM word_progress p JOIN words w ON w.id=p.word_id '
        "WHERE p.status IN ('learning','wrong') AND p.next_review_at IS NOT NULL "
        "AND substr(p.next_review_at,1,10)<=? "
        '${b.isEmpty ? '' : 'AND w.book_name=?'} ORDER BY p.next_review_at ASC';
    final args = <Object?>[today, if (b.isNotEmpty) b];
    return _db.select(sql, args).map(_wordWithProgress).toList();
  }

  // ---------- 错词本 ----------

  static List<WordWithProgress> mistakes(String? book) {
    final b = book ?? '';
    final sql = 'SELECT w.*, p.status, p.correct_count, p.wrong_count, p.review_stage '
        'FROM word_progress p JOIN words w ON w.id=p.word_id '
        "WHERE p.wrong_count>0 AND p.status IN ('wrong','learning') "
        '${b.isEmpty ? '' : 'AND w.book_name=?'} '
        'ORDER BY p.wrong_count DESC, p.next_review_at ASC';
    final args = <Object?>[if (b.isNotEmpty) b];
    return _db.select(sql, args).map(_wordWithProgress).toList();
  }

  /// 由“单词字段 + 进度字段（同名列）”构造带进度的单词。
  static WordWithProgress _wordWithProgress(Row r) {
    final word = Word.fromRow(r);
    final progress = Progress(
      id: 0,
      wordId: word.id,
      status: r['status'] as String? ?? 'new',
      correctCount: r['correct_count'] as int? ?? 0,
      wrongCount: r['wrong_count'] as int? ?? 0,
      reviewStage: r['review_stage'] as int? ?? 0,
    );
    return WordWithProgress(word, progress);
  }

  static void clearMistakes(String? book) {
    final b = book ?? '';
    final sql = "UPDATE word_progress SET wrong_count=0, status='new', "
        'review_stage=0, next_review_at=NULL WHERE wrong_count>0 '
        "AND status IN ('wrong','learning') ${b.isEmpty ? '' : 'AND word_id IN (SELECT id FROM words WHERE book_name=?)'}";
    _db.execute(sql, [if (b.isNotEmpty) b]);
  }

  /// 闪卡自评：记录单张卡片结果并即时更新复习进度。
  /// known=true 视为答对（推进复习阶段），false 视为答错（降阶段、次日再复习）。
  static void recordFlashcard(int sessionId, int wordId, bool known) {
    final db = _db;
    final today = todayStr();
    final now = nowStr();
    db.execute(
      'INSERT INTO study_records (session_id, word_id, user_answer, is_correct, created_at) '
      'VALUES (?,?,?,?,?)',
      [sessionId, wordId, known ? '认识' : '不认识', known ? 1 : 0, now]);
    _updateProgress(wordId, known, false, today);
  }

  /// 一轮闪卡结束：汇总会话、写每日日志与背诵篇章。
  static Map<String, dynamic> finishFlashcardSession(
      int sessionId, int total, int known) {
    final db = _db;
    final wrong = total - known;
    final acc = total == 0 ? 0.0 : known * 100.0 / total;
    final now = nowStr();
    final today = todayStr();
    db.execute(
      'UPDATE study_sessions SET total_count=?, correct_count=?, wrong_count=?, '
      'accuracy=?, completed=1, completed_at=? WHERE id=?',
      [total, known, wrong, acc, now, sessionId]);
    if (total > 0) {
      _bumpDailyLog(today, total);
      _createStudyLog(sessionId, today, total, acc, db);
    }
    return {'total': total, 'correct': known, 'wrong': wrong, 'accuracy': acc};
  }

  // ---------- 单词库 ----------

  static List<WordWithProgress> searchWords(
      String keyword, String book, int page, int perPage) {
    final k = keyword.trim();
    final where = <String>[];
    final args = <Object?>[];
    if (k.isNotEmpty) {
      where.add('(w.word LIKE ? OR w.meaning LIKE ? OR w.normalized_word LIKE ?)');
      final like = '%$k%';
      args.addAll([like, like, like]);
    }
    if (book.isNotEmpty) {
      where.add('w.book_name=?');
      args.add(book);
    }
    final cond = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final sql = 'SELECT w.*, p.status, p.correct_count, p.wrong_count, p.review_stage '
        'FROM words w LEFT JOIN word_progress p ON p.word_id=w.id '
        '$cond ORDER BY w.id LIMIT ? OFFSET ?';
    args.addAll([perPage, (page - 1) * perPage]);
    return _db.select(sql, args).map(_wordWithProgress).toList();
  }

  static int searchCount(String keyword, String book) {
    final k = keyword.trim();
    final where = <String>[];
    final args = <Object?>[];
    if (k.isNotEmpty) {
      where.add('(word LIKE ? OR meaning LIKE ? OR normalized_word LIKE ?)');
      final like = '%$k%';
      args.addAll([like, like, like]);
    }
    if (book.isNotEmpty) {
      where.add('book_name=?');
      args.add(book);
    }
    final cond = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    return _count('SELECT COUNT(*) FROM words $cond', args);
  }

  // ---------- 总测试 ----------

  static List<Word> quizWords(int count, String? book) {
    final b = book ?? '';
    final sql = 'SELECT * FROM words w '
        '${b.isEmpty ? '' : 'WHERE w.book_name=?'} '
        'ORDER BY RANDOM() LIMIT ?';
    final args = <Object?>[if (b.isNotEmpty) b, count];
    return _db.select(sql, args).map(Word.fromRow).toList();
  }

  static int wordTotal(String? book) {
    final b = book ?? '';
    return b.isEmpty
        ? _count('SELECT COUNT(*) FROM words')
        : _count('SELECT COUNT(*) FROM words WHERE book_name=?', [b]);
  }

  // ---------- 背诵篇章 ----------

  static List<Map<String, dynamic>> passages(String? book) {
    final b = book ?? '';
    final rs = _db.select(
        'SELECT l.log_date, l.id, l.session_id AS sid, l.sequence, l.word_count, l.accuracy, '
        's.session_type, s.test_mode FROM study_logs l '
        'JOIN study_sessions s ON s.id=l.session_id '
        '${b.isEmpty ? '' : 'WHERE s.book_name=?'} '
        'ORDER BY l.log_date DESC, l.sequence DESC',
        b.isEmpty ? const [] : [b]);
    return rs.map((r) {
      final logDate = r['log_date'] as String;
      final sequence = r['sequence'] as int? ?? 1;
      final sessionType = r['session_type'] as String? ?? 'new';
      final testMode = r['test_mode'] as String? ?? 'en';
      final typeLabel = sessionType == 'review'
          ? '复习'
          : (sessionType == 'quiz' ? '总测试' : '新学');
      final modeLabel = testMode == 'cn' ? '看英文默写中文' : '看中文默写英文';
      return {
        'log_date': logDate,
        'title': '$logDate 第$sequence篇',
        'subtitle': '$typeLabel · $modeLabel',
        'word_count': r['word_count'] as int? ?? 0,
        'accuracy': r['accuracy'] as double? ?? 0,
        'session_id': r['sid'] as int? ?? 0,
      };
    }).toList();
  }

  static List<Word> passageWords(int sessionId) {
    final rs = _db.select(
        'SELECT w.* FROM study_records r JOIN words w ON w.id=r.word_id '
        'WHERE r.session_id=? ORDER BY r.id',
        [sessionId]);
    return rs.map(Word.fromRow).toList();
  }

  /// 指定月份有学习记录的日期集合（可限定词书）
  static Set<String> monthStudyDates(int year, int month, String? book) {
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final set = <String>{};
    for (final r in _db.select(
        "SELECT DISTINCT substr(r.created_at,1,10) d FROM study_records r "
        "JOIN words w ON w.id=r.word_id "
        "WHERE substr(r.created_at,1,7)=?${_bookAnd(book)}",
        [prefix, ..._bArgs(book)])) {
      set.add(r['d'] as String);
    }
    return set;
  }

  // ---------- 学习计划（日历，按日期，全局通用） ----------

  /// 某一天的计划，未完成在前、已完成在后
  static List<Map<String, dynamic>> plansFor(String date) {
    return _db
        .select(
            'SELECT id, plan_date, content, is_done FROM plans WHERE plan_date=? '
            'ORDER BY is_done ASC, id ASC',
            [date])
        .map((r) => {
              'id': r['id'] as int,
              'date': r['plan_date'] as String,
              'content': r['content'] as String,
              'done': (r['is_done'] as int? ?? 0) == 1,
            })
        .toList();
  }

  /// 新增一条计划，返回新 id（空内容返回 0）
  static int addPlan(String date, String content) {
    final text = content.trim();
    if (text.isEmpty) return 0;
    _db.execute(
        'INSERT INTO plans (plan_date, content, is_done, created_at, updated_at) '
        'VALUES (?,?,0,?,?)',
        [date, text, nowStr(), nowStr()]);
    return _db.lastInsertRowId;
  }

  /// 切换完成状态
  static void togglePlan(int id, bool done) {
    _db.execute('UPDATE plans SET is_done=?, updated_at=? WHERE id=?',
        [done ? 1 : 0, nowStr(), id]);
  }

  /// 删除一条计划
  static void deletePlan(int id) {
    _db.execute('DELETE FROM plans WHERE id=?', [id]);
  }

  /// 指定月份“存在计划”的日期集合（用于小红点）
  static Set<String> planDates(int year, int month) {
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final set = <String>{};
    for (final r in _db.select(
        'SELECT DISTINCT plan_date d FROM plans WHERE substr(plan_date,1,7)=?',
        [prefix])) {
      set.add(r['d'] as String);
    }
    return set;
  }
}
