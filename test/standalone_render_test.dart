import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:efish_app/main.dart';

/// 验证首页快捷按钮 push 出来的页面由 StandalonePage 包裹：
/// 必须有 Scaffold 背景（非黑）、标题、返回上一级按钮。
/// 只 pump 静态子组件，不加载依赖数据库/定时器的真实页面，避免 pumpAndSettle 超时。
void main() {
  testWidgets('StandalonePage 有 Scaffold 背景与返回按钮（非黑屏）',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StandalonePage(
        title: '学习新单词',
        child: const Center(child: Text('设置内容')),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 存在 Scaffold
    final scaffoldFinder = find.byType(Scaffold);
    expect(scaffoldFinder, findsOneWidget);

    // 背景色等于当前主题 scaffold 色，且不是黑色
    final Scaffold scaffold = tester.widget(scaffoldFinder);
    final t = themes[appState.themeIndex];
    expect(scaffold.backgroundColor, t.scaffold);
    expect(t.scaffold == Colors.black, false);

    // 有“返回上一级”按钮
    expect(find.byTooltip('返回上一级'), findsOneWidget);

    // 标题与内容
    expect(find.text('学习新单词'), findsOneWidget);
    expect(find.text('设置内容'), findsOneWidget);
  });
}
