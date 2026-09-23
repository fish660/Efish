import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

/// 数据库访问层：直接读写标准 SQLite 文件（与 Web 版 words.db 完全兼容）。
class AppDb {
  AppDb._(this.db);
  final Database db;

  static Database? _instance;

  static Database get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('数据库尚未初始化');
    }
    return i;
  }

  /// 数据目录：%APPDATA%/Efish（不依赖 path_provider，避免插件链）
  static Future<String> dataDir() async {
    final base = Platform.environment['APPDATA'] ??
        (Platform.environment['HOME'] ?? '.');
    final dir = Directory('$base${Platform.pathSeparator}Efish');
    await dir.create(recursive: true);
    return dir.path;
  }

  /// 同步版数据目录（供日志等场景使用）
  static String dataDirSync() {
    final base = Platform.environment['APPDATA'] ??
        (Platform.environment['HOME'] ?? '.');
    final dir = Directory('$base${Platform.pathSeparator}Efish');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  static Future<String> init() async {
    // Windows：加载系统自带 winsqlite3.dll
    try {
      open.overrideFor(OperatingSystem.windows, _openOnWindows);
    } catch (_) {}
    final dir = await dataDir();
    final dbFile = File('$dir${Platform.pathSeparator}words.db');
    if (!dbFile.existsSync()) {
      // 首次运行：从内置种子词库初始化（种子库只含单词，不含任何学习记录）
      final data = await rootBundle.load('assets/words.db');
      dbFile.writeAsBytesSync(data.buffer.asUint8List());
    }
    final db = sqlite3.open(dbFile.path);
    db.execute('PRAGMA journal_mode=WAL;');
    db.execute('PRAGMA foreign_keys=ON;');
    // 写锁冲突时等待而非立即报 database is locked（多窗口/测试并发更稳）
    db.execute('PRAGMA busy_timeout=8000;');
    _createTables(db);
    _repairForeignKeys(db);
    _instance = db;
    // 为老用户补齐新版本内置词书（新用户复制种子库后会自动跳过）
    try {
      await _seedBuiltinBooks(db);
    } catch (e) {
      // 补齐失败不阻断启动（词书缺失不影响已有功能）
      // ignore: avoid_print
      print('内置词书补齐失败：$e');
    }
    return dbFile.path;
  }

  /// 修复历史库中错误指向 words_old 的外键（Web 版旧库遗留问题）。
  /// 受影响的表至少包括 study_records、word_progress；在 foreign_keys=ON 时，
  /// 向这些表插入/更新会因 "no such table: main.words_old" 而失败，
  /// 表现为默写提交卡在“提交中”、复习/总测试无法评分。
  /// 这里做通用处理：扫描所有表，凡外键引用 words_old 的都按正确结构重建并保留数据。
  static void _repairForeignKeys(Database db) {
    // 表名 -> 正确建表语句（外键必须指向 words / study_sessions）
    final correctSchemas = <String, String>{
      'word_progress': '''
        CREATE TABLE word_progress (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word_id INTEGER NOT NULL UNIQUE,
          status TEXT DEFAULT 'new',
          first_learned_at DATETIME,
          last_reviewed_at DATETIME,
          next_review_at DATETIME,
          correct_count INTEGER DEFAULT 0,
          wrong_count INTEGER DEFAULT 0,
          review_stage INTEGER DEFAULT 0,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(word_id) REFERENCES words(id)
        )''',
      'study_records': '''
        CREATE TABLE study_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER NOT NULL,
          word_id INTEGER NOT NULL,
          user_answer TEXT,
          is_correct INTEGER,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(session_id) REFERENCES study_sessions(id),
          FOREIGN KEY(word_id) REFERENCES words(id)
        )''',
    };
    final indexes = <String, List<String>>{
      'word_progress': [
        'CREATE INDEX IF NOT EXISTS ix_progress_status ON word_progress(status)',
        'CREATE INDEX IF NOT EXISTS ix_progress_next_review ON word_progress(next_review_at)',
      ],
      'study_records': [
        'CREATE INDEX IF NOT EXISTS ix_records_session ON study_records(session_id)',
      ],
    };

    // 找出所有外键引用了 words_old 的表
    final tables = db
        .select(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '%_old%'")
        .map((r) => r['name'] as String)
        .toList();
    final broken = <String>[];
    for (final tbl in tables) {
      try {
        final fks = db.select('PRAGMA foreign_key_list($tbl)');
        if (fks.any((r) => r['table'] == 'words_old')) {
          broken.add(tbl);
        }
      } catch (_) {
        // 某些对象不支持 PRAGMA，忽略
      }
    }
    if (broken.isEmpty) return;

    db.execute('PRAGMA foreign_keys=OFF;');
    db.execute('BEGIN;');
    try {
      for (final tbl in broken) {
        final schema = correctSchemas[tbl];
        if (schema == null) {
          // 未知表：无法安全重建，跳过（不影响主流程）
          continue;
        }
        final tmp = '${tbl}_fkfix';
        db.execute('DROP TABLE IF EXISTS $tmp;');
        db.execute('ALTER TABLE $tbl RENAME TO $tmp;');
        db.execute(schema);
        // 按新表列名复制交集列数据（旧表列名与新表一致）
        final newCols = db
            .select('PRAGMA table_info($tbl)')
            .map((r) => r['name'] as String)
            .toList();
        final oldCols = db
            .select('PRAGMA table_info($tmp)')
            .map((r) => r['name'] as String)
            .toSet();
        final cols = newCols.where((c) => oldCols.contains(c)).toList();
        final colList = cols.join(', ');
        db.execute(
            'INSERT INTO $tbl ($colList) SELECT $colList FROM $tmp;');
        db.execute('DROP TABLE $tmp;');
        for (final idx in (indexes[tbl] ?? const <String>[])) {
          db.execute(idx);
        }
      }
      db.execute('COMMIT;');
    } catch (_) {
      db.execute('ROLLBACK;');
      rethrow;
    } finally {
      db.execute('PRAGMA foreign_keys=ON;');
    }
  }

  static DynamicLibrary _openOnWindows() {
    try {
      return DynamicLibrary.open('winsqlite3.dll');
    } catch (_) {
      return DynamicLibrary.open('sqlite3.dll');
    }
  }

  static void _createTables(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        normalized_word TEXT NOT NULL,
        pos TEXT DEFAULT '',
        meaning TEXT DEFAULT '',
        phonetic TEXT DEFAULT '',
        example TEXT DEFAULT '',
        book_name TEXT DEFAULT '默认词书',
        aliases TEXT DEFAULT '',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )''');
    db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS ux_words_book_normalized ON words(book_name, normalized_word)');
    db.execute('''
      CREATE TABLE IF NOT EXISTS word_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL UNIQUE,
        status TEXT DEFAULT 'new',
        first_learned_at DATETIME,
        last_reviewed_at DATETIME,
        next_review_at DATETIME,
        correct_count INTEGER DEFAULT 0,
        wrong_count INTEGER DEFAULT 0,
        review_stage INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )''');
    db.execute('CREATE INDEX IF NOT EXISTS ix_progress_status ON word_progress(status)');
    db.execute(
        'CREATE INDEX IF NOT EXISTS ix_progress_next_review ON word_progress(next_review_at)');
    db.execute('''
      CREATE TABLE IF NOT EXISTS study_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_type TEXT NOT NULL,
        test_mode TEXT DEFAULT 'en',
        book_name TEXT,
        total_count INTEGER DEFAULT 0,
        correct_count INTEGER DEFAULT 0,
        wrong_count INTEGER DEFAULT 0,
        accuracy REAL DEFAULT 0,
        completed INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        completed_at DATETIME
      )''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS study_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        word_id INTEGER NOT NULL,
        user_answer TEXT,
        is_correct INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )''');
    db.execute('CREATE INDEX IF NOT EXISTS ix_records_session ON study_records(session_id)');
    db.execute('''
      CREATE TABLE IF NOT EXISTS daily_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_date TEXT UNIQUE NOT NULL,
        learned_count INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS study_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        log_date TEXT NOT NULL,
        session_id INTEGER NOT NULL UNIQUE,
        sequence INTEGER DEFAULT 1,
        word_count INTEGER DEFAULT 0,
        accuracy REAL DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_date TEXT NOT NULL,
        content TEXT NOT NULL,
        is_done INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )''');
    db.execute(
        'CREATE INDEX IF NOT EXISTS idx_plans_date ON plans(plan_date)');
  }

  /// 读取设置项（主题、当前词书等）
  static String? getSetting(String key) {
    final rs =
        _instance?.select('SELECT value FROM settings WHERE key=?', [key]);
    if (rs == null || rs.isEmpty) return null;
    return rs.first['value'] as String?;
  }

  /// 写入设置项（持久化）
  static void setSetting(String key, String value) {
    _instance?.execute(
      'INSERT INTO settings(key,value) VALUES(?,?) '
      'ON CONFLICT(key) DO UPDATE SET value=excluded.value',
      [key, value],
    );
  }

  /// 内置词书清单（随安装包种子库下发；新版本增加词书时在此登记）
  static const builtinBooks = <String>['六级真题核心词汇'];

  /// 为已存在的运行库补齐内置词书（老用户升级到含新词书的版本时使用）。
  /// 新用户首次运行会整体复制种子库，此处检测到已存在会自动跳过。
  static Future<void> _seedBuiltinBooks(Database db) async {
    final missing = <String>[];
    for (final book in builtinBooks) {
      final rs =
          db.select('SELECT COUNT(*) c FROM words WHERE book_name=?', [book]);
      final n = rs.isEmpty ? 0 : (rs.first['c'] as int? ?? 0);
      if (n == 0) missing.add(book);
    }
    if (missing.isEmpty) return;

    // 把内置种子库临时落盘后只读打开
    final data = await rootBundle.load('assets/words.db');
    final dir = await dataDir();
    final tmp = File('$dir${Platform.pathSeparator}_seed_tmp.db');
    tmp.writeAsBytesSync(data.buffer.asUint8List());
    Database? seed;
    try {
      seed = sqlite3.open(tmp.path, mode: OpenMode.readOnly);
      db.execute('BEGIN');
      var imported = 0;
      for (final book in missing) {
        final rows = seed.select(
            'SELECT word, normalized_word, pos, meaning, phonetic, example, '
            'book_name, aliases FROM words WHERE book_name=?',
            [book]);
        for (final r in rows) {
          db.execute(
            'INSERT OR IGNORE INTO words (word, normalized_word, pos, meaning, '
            'phonetic, example, book_name, aliases, created_at) '
            "VALUES (?,?,?,?,?,?,?,?,datetime('now','localtime'))",
            [
              r['word'], r['normalized_word'], r['pos'], r['meaning'],
              r['phonetic'], r['example'], r['book_name'],
              r['aliases'] ?? '',
            ],
          );
          imported++;
        }
      }
      db.execute('COMMIT');
      // ignore: avoid_print
      print('内置词书补齐完成：$missing，共 $imported 词');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    } finally {
      seed?.dispose();
      if (tmp.existsSync()) {
        try {
          tmp.deleteSync();
        } catch (_) {}
      }
    }
  }
}

/// 关闭数据库（供测试/退出时调用）
void closeDb() {
  AppDb._instance?.dispose();
  AppDb._instance = null;
}
