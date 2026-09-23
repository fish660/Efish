import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:efish_app/db.dart';
import 'package:efish_app/main.dart';
import 'package:efish_app/pages/mistakes_page.dart';
import 'package:efish_app/services.dart';

/// 错词闪卡 UI 流程：开始封面 -> 正面 -> 翻面 -> 认识 -> 下一张。
/// 数据库初始化放在 setUpAll（真实 async），testWidgets 内仅做同步调用与手动 pump。
/// 用事务回滚，避免污染真实数据库。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppDb.init();
  });

  testWidgets('错词闪卡：开始-翻面-认识', (tester) async {
    final db = AppDb.instance;
    db.execute('BEGIN');
    try {
      final words = Services.pickNewWords(1, null);
      if (words.isNotEmpty) {
        final sid = Services.createSession('review', 'en', null);
        Services.recordFlashcard(sid, words.first.id, false);
      }
      appState.setBook('');

      await tester.pumpWidget(const MaterialApp(home: MistakesPage()));
      await tester.pump(const Duration(milliseconds: 100));

      // 开始封面
      expect(find.text('开始闪卡'), findsOneWidget);
      await tester.tap(find.text('开始闪卡'));
      await tester.pump(const Duration(milliseconds: 400));

      // 正面
      expect(find.text('点击卡片查看英文'), findsOneWidget);
      expect(find.text('还不认识'), findsNothing);

      // 翻面
      await tester.tap(find.text('点击卡片查看英文'));
      await tester.pump(const Duration(milliseconds: 400));

      // 背面自评按钮
      expect(find.text('还不认识'), findsOneWidget);
      expect(find.text('认识'), findsOneWidget);

      // 认识 -> 下一张正面
      await tester.tap(find.text('认识'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('点击卡片查看英文'), findsOneWidget);
    } finally {
      db.execute('ROLLBACK');
    }
  });
}
