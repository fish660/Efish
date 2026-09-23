import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:efish_app/db.dart';
import 'package:efish_app/main.dart';

void main() {
  testWidgets('首页渲染含日历与桌宠', (tester) async {
    await AppDb.init();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(const EfishApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('今日新词'), findsOneWidget);
    final cal = find.textContaining('年');
    print('日历标题: ${tester.widgetList(cal).length} 个匹配');
    expect(find.textContaining('月'), findsWidgets);
    expect(find.textContaining('您一共已学习了'), findsOneWidget);
    expect(find.textContaining('有任何使用建议'), findsOneWidget);
  });
}
