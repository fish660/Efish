import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'db.dart';
import 'pages/home_page.dart';
import 'pages/import_page.dart';
import 'pages/learn_flow.dart';
import 'pages/mistakes_page.dart';
import 'pages/passages_page.dart';
import 'pages/quiz_page.dart';
import 'pages/statistics_page.dart';
import 'pages/words_page.dart';
import 'services.dart';

/// 全局应用状态：当前词书、背景主题、页面导航
class AppState extends ChangeNotifier {
  String? currentBook;
  int themeIndex = 0; // 0 海系（默认） 1 日系

  void setBook(String? b) {
    currentBook = b;
    notifyListeners();
  }

  void setTheme(int i) {
    themeIndex = i;
    // 持久化主题选择：下次启动仍保持，除非再次手动切换
    try {
      AppDb.setSetting('theme_index', '$i');
    } catch (_) {}
    notifyListeners();
  }
}

final appState = AppState();

/// 应用配色（随主题切换）。通过 ThemeExtension 注入 ThemeData，
/// 这样无论是左侧导航的页面，还是 Navigator.push 打开的页面，
/// 只要用 Theme.of(context) 取色，都会在切换主题时自动重建变色。
class AppColors extends ThemeExtension<AppColors> {
  final String name;
  final Color scaffold;
  final Color card;
  final Color primary;
  final Color text;
  final Color subText;
  final Color divider;
  final Color field; // 输入框/浅色填充

  const AppColors(
    this.name,
    this.scaffold,
    this.card,
    this.primary,
    this.text,
    this.subText,
    this.divider,
    this.field,
  );

  /// 兜底主题（与默认主题一致，保证 extension 缺失时也呈现默认配色）
  static const AppColors fallback = AppColors(
    '海系',
    Color(0xFFE6F2FB),
    Color(0xFFF3FAFF),
    Color(0xFF0C74B8),
    Color(0xFF1B3A52),
    Color(0xFF5C7892),
    Color(0xFFCCE2F2),
    Color(0xFFE2F0FA),
  );

  @override
  AppColors copyWith({
    String? name,
    Color? scaffold,
    Color? card,
    Color? primary,
    Color? text,
    Color? subText,
    Color? divider,
    Color? field,
  }) {
    return AppColors(
      name ?? this.name,
      scaffold ?? this.scaffold,
      card ?? this.card,
      primary ?? this.primary,
      text ?? this.text,
      subText ?? this.subText,
      divider ?? this.divider,
      field ?? this.field,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      t < 0.5 ? name : other.name,
      Color.lerp(scaffold, other.scaffold, t)!,
      Color.lerp(card, other.card, t)!,
      Color.lerp(primary, other.primary, t)!,
      Color.lerp(text, other.text, t)!,
      Color.lerp(subText, other.subText, t)!,
      Color.lerp(divider, other.divider, t)!,
      Color.lerp(field, other.field, t)!,
    );
  }
}

/// 便捷取色：context.c 即当前主题配色
extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>() ?? AppColors.fallback;
}

/// 两套主题（海系为默认 / 日系）。海系整体淡蓝，与 Efish 桌宠配色一致。
const themes = <AppColors>[
  AppColors(
    '海系',
    Color(0xFFE6F2FB),
    Color(0xFFF3FAFF),
    Color(0xFF0C74B8),
    Color(0xFF1B3A52),
    Color(0xFF5C7892),
    Color(0xFFCCE2F2),
    Color(0xFFE2F0FA),
  ),
  AppColors(
    '日系',
    Color(0xFFF6EFE2),
    Color(0xFFFDFAF2),
    Color(0xFFB0552F),
    Color(0xFF4A3B2C),
    Color(0xFF8A7664),
    Color(0xFFE9DCC6),
    Color(0xFFF3EADB),
  ),
];


/// 供首页快捷按钮 push 使用的独立页面包装：
/// 提供主题背景色与带“返回上一级”按钮的顶部栏。
class StandalonePage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  const StandalonePage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.c;
    return Scaffold(
      backgroundColor: t.scaffold,
      appBar: AppBar(
        backgroundColor: t.card,
        surfaceTintColor: t.card,
        foregroundColor: t.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 19),
          tooltip: '返回上一级',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(title),
        actions: actions,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: t.divider),
        ),
      ),
      body: child,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 全局异常：记录到日志文件，避免崩溃无痕迹
  FlutterError.onError = (details) {
    _logError('FlutterError: ${details.exception}\n${details.stack}');
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _logError('PlatformError: $error\n$stack');
    return true;
  };
  try {
    await AppDb.init();
  } catch (e, st) {
    _logError('DbInit: $e\n$st');
    rethrow;
  }
  // 恢复上次选择的主题（持久化）
  try {
    final tiOld = int.tryParse(AppDb.getSetting('theme_index') ?? '');
    // 旧版索引：0 默认白 / 1 日系 / 2 海系；新版：0 海系 / 1 日系
    // 白(0)与海系(2)统一落到海系(0)，日系(1)保持日系，无设置走默认海系。
    if (tiOld == 1) {
      appState.themeIndex = 1;
    } else {
      appState.themeIndex = 0;
    }
  } catch (_) {}
  runApp(const EfishApp());
}

void _logError(String msg) {
  try {
    final f = File('${AppDb.dataDirSync()}${Platform.pathSeparator}error.log');
    f.writeAsStringSync(
        '${DateTime.now()}\n$msg\n${'=' * 40}\n',
        mode: FileMode.append);
  } catch (_) {}
}

class EfishApp extends StatelessWidget {
  const EfishApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final t = themes[appState.themeIndex];
        return MaterialApp(
          title: 'Efish',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: t.scaffold,
            colorScheme: ColorScheme.fromSeed(
              seedColor: t.primary,
              surface: t.card,
              primary: t.primary,
              brightness: Brightness.light,
            ),
            extensions: [t],
            appBarTheme: AppBarTheme(
              backgroundColor: t.card,
              surfaceTintColor: t.card,
              foregroundColor: t.text,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
            cardTheme: CardThemeData(
              color: t.card,
              surfaceTintColor: t.card,
              elevation: 1.5,
              shadowColor: Colors.black.withValues(alpha: .06),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            dividerColor: t.divider,
            fontFamily: 'Microsoft YaHei',
          ),
          home: const MainShell(),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _page = 0;
  bool _bookInit = false;
  bool _bookMenuOpen = false;

  static const _pages = [
    HomePage(),
    LearnPage(),
    ReviewPage(),
    MistakesPage(),
    WordsPage(),
    StatisticsPage(),
    PassagesPage(),
    ImportPage(),
  ];

  static const _labels = [
    '首页',
    '学习新词',
    '今日复习',
    '错词本',
    '单词库',
    '学习统计',
    '每日篇章收录',
    '导入单词',
  ];

  static const _headerHeight = 60.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final books = Services.books();
      if (books.isNotEmpty && appState.currentBook == null) {
        appState.setBook(books.first);
      }
      setState(() => _bookInit = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 监听词书/主题变化；颜色统一通过 Theme.of(context)（context.c）获取，
    // 因此 push 打开的页面也能随主题切换。
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final t = context.c;
        return Scaffold(
          backgroundColor: t.scaffold,
          body: Row(
            children: [
              _sidebar(t),
              Expanded(
                child: Column(
                  children: [
                    _topBar(t),
                    Expanded(
                      child: IndexedStack(
                        index: _page,
                        children: [
                          for (final p in _pages)
                            Material(
                              type: MaterialType.transparency,
                              child: p,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------- 左侧导航 ----------

  Widget _sidebar(AppColors t) {
    return Container(
      width: 188,
      decoration: BoxDecoration(
        color: t.card,
        border: Border(right: BorderSide(color: t.divider)),
      ),
      child: Column(
        children: [
          _brand(t),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              itemCount: _labels.length,
              itemBuilder: (context, i) {
                final sel = i == _page;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: sel
                        ? t.primary.withValues(alpha: .12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _page = i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        child: Row(
                          children: [
                            Icon(_iconFor(i),
                                size: 19,
                                color: sel ? t.primary : t.subText),
                            const SizedBox(width: 10),
                            Text(
                              _labels[i],
                              style: TextStyle(
                                fontSize: 14,
                                color: sel ? t.primary : t.text,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 底部：作者邮箱反馈
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.divider)),
            ),
            child: Tooltip(
              message: '有任何使用建议，欢迎发送至作者邮箱',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('使用建议请发送至',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: t.subText)),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('2460951290@qq.com',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: t.text)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(int i) => const [
        Icons.home_outlined,
        Icons.school_outlined,
        Icons.refresh_outlined,
        Icons.error_outline,
        Icons.menu_book_outlined,
        Icons.bar_chart_outlined,
        Icons.article_outlined,
        Icons.file_upload_outlined,
      ][i];

  /// 品牌区：与右侧顶部栏等高，底部一条分隔线，保证横向对齐
  Widget _brand(AppColors t) {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.divider)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset('assets/fish_logo.png',
                width: 32, height: 32, fit: BoxFit.cover),
          ),
          const SizedBox(width: 9),
          Text('Efish',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: t.primary)),
        ],
      ),
    );
  }

  // ---------- 右侧顶部栏 ----------

  Widget _topBar(AppColors t) {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: t.card,
        border: Border(bottom: BorderSide(color: t.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Text('当前词书', style: TextStyle(fontSize: 12, color: t.subText)),
          const SizedBox(width: 8),
          _bookSelect(t),
          const SizedBox(width: 10),
          Text('顶部可切换词书',
              style: TextStyle(fontSize: 11, color: t.subText)),
          const Spacer(),
          _themeToggle(t),
          const SizedBox(width: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: t.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 38),
            ),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const QuizSetupPage()));
            },
            icon: const Icon(Icons.quiz_outlined, size: 18),
            label: const Text('总测试'),
          ),
        ],
      ),
    );
  }

  Widget _bookSelect(AppColors t) {
    final books = _bookInit ? Services.books() : const <String>[];
    // null 表示“全部词书”，其余为具体词书名
    final options = <String?>[null, ...books];
    final cur = appState.currentBook;
    final curLabel = (cur == null || cur.isEmpty) ? '全部词书' : cur;

    return MenuAnchor(
      onOpen: () => setState(() => _bookMenuOpen = true),
      onClose: () => setState(() => _bookMenuOpen = false),
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(t.card),
        surfaceTintColor: WidgetStatePropertyAll(t.card),
        shadowColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: .18)),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6, horizontal: 6)),
        shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
      menuChildren: [
        for (final b in options)
          SizedBox(
            width: 248,
            child: MenuItemButton(
              style: ButtonStyle(
                padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
              onPressed: () => appState.setBook(b ?? ''),
              leadingIcon: SizedBox(
                width: 20,
                child: (b ?? '') == (cur ?? '')
                    ? Icon(Icons.check_rounded, size: 18, color: t.primary)
                    : const SizedBox.shrink(),
              ),
              child: Text(
                b ?? '全部词书',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      (b ?? '') == (cur ?? '') ? FontWeight.w700 : FontWeight.normal,
                  color: (b ?? '') == (cur ?? '') ? t.primary : t.text,
                ),
              ),
            ),
          ),
      ],
      builder: (context, controller, child) {
        return Material(
          color: t.field,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () =>
                controller.isOpen ? controller.close() : controller.open(),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: t.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_stories_rounded, size: 15, color: t.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(curLabel,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.text)),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _bookMenuOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.expand_more_rounded,
                        size: 18, color: t.subText),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 主题切换：分段式控件，选中段填充主题色
  Widget _themeToggle(AppColors t) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.field,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(themes.length, (i) {
          final sel = appState.themeIndex == i;
          return GestureDetector(
            onTap: () => appState.setTheme(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? t.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                themes[i].name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  color: sel ? Colors.white : t.subText,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
