import 'package:sqlite3/sqlite3.dart';

/// 清洗音标：把爬虫可能留下的空占位（null、none、n/a、/null/、单个破折号等）视为空。
String cleanPhonetic(Object? v) {
  final p = (v as String? ?? '').trim();
  final core = p.replaceAll('/', '').replaceAll(' ', '').toLowerCase();
  if (core.isEmpty ||
      core == 'null' ||
      core == 'none' ||
      core == 'na' ||
      core == 'n/a' ||
      core == '-') {
    return '';
  }
  return p;
}

/// 单词
class Word {
  Word({
    required this.id,
    required this.word,
    required this.normalizedWord,
    required this.pos,
    required this.meaning,
    required this.phonetic,
    required this.example,
    required this.bookName,
    this.aliases = '',
  });

  final int id;
  final String word;
  final String normalizedWord;
  final String pos;
  final String meaning;
  final String phonetic;
  final String example;
  final String bookName;
  final String aliases;

  factory Word.fromRow(Row r) => Word(
        id: r['id'] as int,
        word: r['word'] as String? ?? '',
        normalizedWord: r['normalized_word'] as String? ?? '',
        pos: r['pos'] as String? ?? '',
        meaning: r['meaning'] as String? ?? '',
        phonetic: cleanPhonetic(r['phonetic']),
        example: r['example'] as String? ?? '',
        bookName: r['book_name'] as String? ?? '默认词书',
        aliases: r['aliases'] as String? ?? '',
      );
}

/// 单词学习进度
class Progress {
  Progress({
    required this.id,
    required this.wordId,
    required this.status,
    required this.correctCount,
    required this.wrongCount,
    required this.reviewStage,
    this.nextReviewAt,
  });

  final int id;
  final int wordId;
  final String status;
  final int correctCount;
  final int wrongCount;
  final int reviewStage;
  final String? nextReviewAt;

  factory Progress.fromRow(Row r) => Progress(
        id: r['id'] as int,
        wordId: r['word_id'] as int,
        status: r['status'] as String? ?? 'new',
        correctCount: r['correct_count'] as int? ?? 0,
        wrongCount: r['wrong_count'] as int? ?? 0,
        reviewStage: r['review_stage'] as int? ?? 0,
        nextReviewAt: r['next_review_at'] as String?,
      );
}

/// 带进度的单词（列表用）
class WordWithProgress {
  WordWithProgress(this.word, this.progress);
  final Word word;
  final Progress? progress;

  String get status => progress?.status ?? 'new';
  int get correctCount => progress?.correctCount ?? 0;
  int get wrongCount => progress?.wrongCount ?? 0;
  int get reviewStage => progress?.reviewStage ?? 0;
}
