import 'dart:convert';

import 'package:flutter/material.dart';

import '../db.dart';
import '../main.dart';

/// 导入单词：粘贴 CSV / JSON 文本导入
/// CSV 列：word,pos,meaning,phonetic,example,book_name
class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final _ctrl = TextEditingController();
  String _format = 'csv';
  String _result = '';
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.c;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('导入单词',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: t.text)),
        const SizedBox(height: 4),
        Text('支持 CSV 与 JSON 格式，重复单词不会重复插入',
            style: TextStyle(fontSize: 13, color: t.subText)),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'csv', label: Text('CSV')),
            ButtonSegment(value: 'json', label: Text('JSON')),
          ],
          selected: {_format},
          onSelectionChanged: (s) => setState(() => _format = s.first),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _ctrl,
          maxLines: 10,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: _format == 'csv'
                ? 'CSV 格式示例：\nword,pos,meaning,phonetic,example,book_name\nabandon,vt.,放弃；抛弃,,,考研英语词汇\n请粘贴数据到此处'
                : 'JSON 格式示例：\n[{"word":"abandon","pos":"vt.","meaning":"放弃；抛弃","phonetic":"","example":"","book_name":"考研英语词汇"}]',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: t.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12)),
              onPressed: _busy ? null : _import,
              icon: const Icon(Icons.file_upload),
              label: Text(_busy ? '导入中…' : '开始导入'),
            ),
            TextButton.icon(
              onPressed: () => _ctrl.clear(),
              icon: const Icon(Icons.clear),
              label: const Text('清空'),
            ),
          ],
        ),
        if (_result.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_result,
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: _result.contains('失败') &&
                                !_result.contains('失败 0')
                            ? Colors.red.shade700
                            : Colors.green.shade700)),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CSV 字段说明',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: t.text)),
                const SizedBox(height: 6),
                Text(
                  'word（必填）, pos, meaning（必填）, phonetic, example, book_name\n'
                  '· 英文单词忽略大小写与首尾空格自动去重\n'
                  '· book_name 不填时归入"默认词书"',
                  style: TextStyle(fontSize: 12, height: 1.6, color: t.subText),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _import() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      setState(() => _result = '请先粘贴要导入的内容。');
      return;
    }
    setState(() => _busy = true);
    try {
      if (_format == 'json') {
        _result = _importJson(text);
      } else {
        _result = _importCsv(text);
      }
    } catch (e) {
      _result = '导入失败：$e';
    }
    setState(() => _busy = false);
  }

  String _importJson(String text) {
    final data = jsonDecode(text);
    if (data is! List || data.isEmpty) return '导入失败：JSON 应为对象数组';
    var ok = 0, dup = 0, fail = 0;
    final errs = <String>[];
    for (final item in data) {
      if (item is! Map) {
        fail++;
        continue;
      }
      final r = _insertOne(
          item['word']?.toString() ?? '',
          item['pos']?.toString() ?? '',
          item['meaning']?.toString() ?? '',
          item['phonetic']?.toString() ?? '',
          item['example']?.toString() ?? '',
          item['book_name']?.toString() ?? '');
      if (r == 'ok') {
        ok++;
      } else if (r == 'dup') {
        dup++;
      } else {
        fail++;
        if (errs.length < 5) errs.add(r);
      }
    }
    return _summary(data.length, ok, dup, fail, errs);
  }

  String _importCsv(String text) {
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return '导入失败：内容为空';
    // 检测表头
    var start = 0;
    if (lines.first.contains('word') && lines.first.contains('meaning')) {
      start = 1;
    }
    var ok = 0, dup = 0, fail = 0;
    final errs = <String>[];
    for (var i = start; i < lines.length; i++) {
      final parts = _splitCsv(lines[i]);
      if (parts.length < 2) {
        fail++;
        errs.add('第${i + 1}行字段不足');
        continue;
      }
      final r = _insertOne(
        parts[0].trim(),
        parts.length > 1 ? parts[1].trim() : '',
        parts.length > 2 ? parts[2].trim() : '',
        parts.length > 3 ? parts[3].trim() : '',
        parts.length > 4 ? parts[4].trim() : '',
        parts.length > 5 ? parts[5].trim() : '',
      );
      if (r == 'ok') {
        ok++;
      } else if (r == 'dup') {
        dup++;
      } else {
        fail++;
        if (errs.length < 5) errs.add('第${i + 1}行: $r');
      }
    }
    return _summary(lines.length - start, ok, dup, fail, errs);
  }

  List<String> _splitCsv(String line) {
    final out = <String>[];
    var cur = StringBuffer();
    var inQ = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQ && i + 1 < line.length && line[i + 1] == '"') {
          cur.write('"');
          i++;
        } else {
          inQ = !inQ;
        }
      } else if (c == ',' && !inQ) {
        out.add(cur.toString());
        cur = StringBuffer();
      } else {
        cur.write(c);
      }
    }
    out.add(cur.toString());
    return out;
  }

  String _insertOne(String word, String pos, String meaning, String phonetic,
      String example, String book) {
    if (word.trim().isEmpty) return '单词不能为空';
    if (meaning.trim().isEmpty) return '词义不能为空';
    final normalized = word.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final bookName = book.trim().isEmpty ? '默认词书' : book.trim();
    final db = AppDb.instance;
    final exists = db.select(
        'SELECT id FROM words WHERE book_name=? AND normalized_word=?',
        [bookName, normalized]);
    if (exists.isNotEmpty) return 'dup';
    try {
      db.execute(
          'INSERT INTO words (word, normalized_word, pos, meaning, phonetic, example, book_name, created_at) '
          'VALUES (?,?,?,?,?,?,?,datetime(\'now\',\'localtime\'))',
          [word.trim(), normalized, pos, meaning, phonetic, example, bookName]);
      return 'ok';
    } catch (e) {
      return '数据库错误';
    }
  }

  String _summary(int total, int ok, int dup, int fail, List<String> errs) {
    final buf = StringBuffer('导入完成\n')
      ..writeln('总行数：$total')
      ..writeln('成功导入：$ok')
      ..writeln('重复跳过：$dup')
      ..writeln('失败：$fail');
    if (errs.isNotEmpty) {
      buf.writeln('失败原因：${errs.take(5).join('；')}');
    }
    return buf.toString();
  }
}
