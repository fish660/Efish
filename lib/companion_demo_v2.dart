// 桌宠动效样板 · 副本2(幅度加大)（独立预览，不接入 Efish 主程序）
// 运行：flutter run -t lib/companion_demo.dart -d windows
// 分层动画：身体底图 + 耳朵/呆毛/尾巴独立摆动 + 眨眼
//   呼吸浮动 / 左右摇摆 / 鼠标跟随 / 点击弹跳 + 鼓励气泡。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: CompanionDemo(),
  ));
}

const _demoLines = [
  '背单词的每一分钟都不会白费！',
  '今天也要元气满满地背词哦~',
  '累了就休息一下，但别忘了回来继续~',
  '每记住一个单词，都离梦想更近一步！',
  '坚持就是胜利，你已经很棒了！',
  '嘿嘿，我在盯着你学习哦！',
  '要不要来 20 个新单词热热身？',
  '复习时间到！旧单词在等你呢~',
  '错词本里的老朋友，该去看看它们了。',
  '日积月累，量变一定会引起质变！',
  '今天的你，比昨天又强了一点！',
  '别怕记不住，重复是最好的老师。',
  '我帮你盯着日历，可别断签呀~',
  '小小单词，轻松拿下！',
  '想象一下考场上挥笔如飞的样子~',
  '你的努力，时间都会记得。',
  '深呼吸，这个词你可以的！',
  '红宝书 6548 词，一个一个拿下！',
  '错误不可怕，重复练习就好啦~',
  '背完这一批，奖励自己一杯奶茶吧！',
];

// 一个可摆动部件（坐标均为 1024 原图归一化）
class _Part {
  final String asset;
  final Rect rect; // 在 1024 画布中的包围盒
  final Alignment pivot; // 旋转支点（部件局部 -1..1）
  const _Part(this.asset, this.rect, this.pivot);
}

const _parts = <_Part>[
  // 尾叶（最靠后，在右侧）
  _Part('assets/part_tail.png', Rect.fromLTWH(0.8193, 0.4082, 0.1738, 0.1377),
      Alignment(-0.37, 0.30)),
  // 头顶猫耳（黑色耳朵 + 白色耳羽，支点在耳根发带边缘）
  _Part('assets/part_earL.png', Rect.fromLTWH(0.2656, 0.1289, 0.1416, 0.2051),
      Alignment(-0.2, 0.39)),
  _Part('assets/part_earR.png', Rect.fromLTWH(0.6504, 0.1445, 0.1299, 0.1914),
      Alignment(-0.04, 0.02)),
  // 发带前景层（固定不旋转，压在两侧耳根，保证发带不随耳朵抖动且无缝）
  _Part('assets/part_headband.png', Rect.fromLTWH(0.2441, 0.2324, 0.5371, 0.1201),
      Alignment(0.0, -0.008)),
  // 头部两侧鱼鳍（耳羽：深色三角 + 白色波浪边，绕根部上下摆动）
  _Part('assets/part_finL.png', Rect.fromLTWH(0.166, 0.4004, 0.0801, 0.0986),
      Alignment(-0.27, -0.21)),
  _Part('assets/part_finR.png', Rect.fromLTWH(0.7051, 0.4531, 0.1797, 0.1689),
      Alignment(0.17, 0.11)),
  // 蝴蝶结（静态层，不旋转，压在右鱼鳍根部前方遮挡下摆缝隙）
  _Part('assets/part_bow.png', Rect.fromLTWH(0.6846, 0.4111, 0.1201, 0.0957),
      Alignment(-0.01, 0)),
  // 呆毛（含描边与高光，支点在根部发带内，整体摆动）
  _Part('assets/part_ahoge.png', Rect.fromLTWH(0.4189, 0.0811, 0.2471, 0.1416),
      Alignment(0.842, 1.167)),
  // 呆毛根部发带遮挡层（静态不旋转，压在呆毛之后，始终盖住根部下端）
  _Part('assets/part_ahcover.png', Rect.fromLTWH(0.6152, 0.2148, 0.0693, 0.0283),
      Alignment(-0.014, -0.034)),
];

class CompanionDemo extends StatefulWidget {
  const CompanionDemo({super.key});

  @override
  State<CompanionDemo> createState() => _CompanionDemoState();
}

class _CompanionDemoState extends State<CompanionDemo>
    with TickerProviderStateMixin {
  late final AnimationController _breathe =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
        ..repeat(reverse: true);
  late final AnimationController _sway =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3800))
        ..repeat(reverse: true);
  late final AnimationController _bounce =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  // 部件缓慢摆动
  late final AnimationController _ear =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
        ..repeat();
  late final AnimationController _ahoge =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))
        ..repeat();
  late final AnimationController _tail =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
        ..repeat();
  // 头部两侧鱼鳍（耳羽）缓慢上下摆动
  late final AnimationController _fin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
        ..repeat();

  bool _kBreath = true;
  bool _kSway = true;
  bool _kBlink = true;
  bool _kPart = true;
  bool _kFollow = true;
  bool _kTap = true;

  Offset _pointer = Offset.zero;
  Offset _smooth = Offset.zero;

  bool _blinking = false;
  Timer? _blinkTimer;

  String _bubble = '';
  bool _bubbleOn = false;
  Timer? _bubbleHide;
  Timer? _autoBubble;
  final _rand = math.Random();

  static const double _petSize = 300;

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
    Future.delayed(const Duration(milliseconds: 1500),
        () => _say(_demoLines[5]));
    _autoBubble = Timer.periodic(const Duration(seconds: 16),
        (_) => _say(_demoLines[_rand.nextInt(_demoLines.length)]));
  }

  @override
  void dispose() {
    _breathe.dispose();
    _sway.dispose();
    _bounce.dispose();
    _ear.dispose();
    _ahoge.dispose();
    _tail.dispose();
    _fin.dispose();
    _blinkTimer?.cancel();
    _bubbleHide?.cancel();
    _autoBubble?.cancel();
    super.dispose();
  }

  void _scheduleBlink() {
    // 随机 2.2~4.6 秒眨一次眼
    final ms = 2200 + _rand.nextInt(2400);
    _blinkTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      if (_kBlink) {
        setState(() => _blinking = true);
        Timer(const Duration(milliseconds: 130), () {
          if (mounted) setState(() => _blinking = false);
        });
      }
      _scheduleBlink();
    });
  }

  void _say(String text) {
    setState(() {
      _bubble = text;
      _bubbleOn = true;
    });
    _bubbleHide?.cancel();
    _bubbleHide = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _bubbleOn = false);
    });
  }

  void _onTap() {
    if (!_kTap) return;
    _bounce.forward(from: 0);
    _say(_demoLines[_rand.nextInt(_demoLines.length)]);
  }

  // 演示用：保持闭眼约 1 秒，便于观察眨眼位置
  void _testBlink() {
    if (!mounted) return;
    setState(() => _blinking = true);
    Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _blinking = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF4F6FA);
    const card = Colors.white;
    const primary = Color(0xFF0E7AB8);
    const sub = Color(0xFF6B7A8E);
    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // 顶部标题栏
          Container(
            height: 60,
            color: card,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const Icon(Icons.pets, color: primary),
                const SizedBox(width: 10),
                const Text('Efish 桌宠动效样板 · 副本2(幅度加大)',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2D3D))),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('预览版 · 尚未实装到软件',
                      style: TextStyle(fontSize: 12, color: Colors.orange)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 左：舞台
                  Expanded(flex: 2, child: _stage(card, primary, sub)),
                  const SizedBox(width: 16),
                  // 右：控制面板
                  SizedBox(width: 320, child: _controlPanel(card, primary, sub)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stage(Color card, Color primary, Color sub) {
    return MouseRegion(
      onHover: (e) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final size = box.size;
        // 以舞台中心为原点
        final dx = ((e.position.dx - size.width * 0.42) / (size.width * 0.42))
            .clamp(-1.0, 1.0);
        final dy = ((e.position.dy - size.height * 0.5) / (size.height * 0.5))
            .clamp(-1.0, 1.0);
        if (_kFollow) setState(() => _pointer = Offset(dx, dy));
      },
      child: Card(
        color: card,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 提示文字
              Positioned(
                bottom: 0,
                child: Text('移动鼠标，桌宠会朝你看；点击桌宠和你打招呼',
                    style: TextStyle(fontSize: 12, color: sub)),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 气泡
                  SizedBox(
                    height: 64,
                    child: AnimatedOpacity(
                      opacity: _bubbleOn ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: _bubbleWidget(primary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _pet(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pet() {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_breathe, _sway, _bounce, _ear, _ahoge, _tail, _fin]),
      builder: (context, _) {
        // 平滑跟随
        _smooth = Offset.lerp(_smooth, _kFollow ? _pointer : Offset.zero, 0.12)!;
        final breatheV = _breathe.value;
        final swayV = _sway.value;
        final bounceV = Curves.elasticOut.transform(
            _bounce.status == AnimationStatus.dismissed ? 0 : _bounce.value);

        final scale =
            (_kBreath ? 1.0 + breatheV * 0.028 : 1.0) * (1.0 + bounceV * 0.12);
        final rot = (_kSway ? (swayV - 0.5) * 0.05 : 0.0) +
            _smooth.dx * 0.05;
        final ty = (_kBreath ? -breatheV * 6.0 : 0.0) - bounceV * 18;
        final tx = _smooth.dx * 10;

        // 部件角度（顺序与 _parts 一致：尾、左耳、右耳、左鱼鳍、右鱼鳍、蝴蝶结、呆毛）
        final p = _kPart;
        final earA = p ? math.sin(_ear.value * 2 * math.pi) * 0.09 : 0.0;
        final earB = p ? math.sin(_ear.value * 2 * math.pi + 0.9) * 0.09 : 0.0;
        final ahogeA =
            p ? math.sin(_ahoge.value * 2 * math.pi) * 0.15 : 0.0;
        final tailA = p ? math.sin(_tail.value * 2 * math.pi) * 0.09 : 0.0;
        final finA = p ? math.sin(_fin.value * 2 * math.pi) * 0.10 : 0.0;
        final finB = p ? math.sin(_fin.value * 2 * math.pi + 1.1) * 0.10 : 0.0;
        final partAngles = [
          tailA, earA, earB, 0.0, finA, finB, 0.0, ahogeA, 0.0,
        ];

        return Transform.translate(
          offset: Offset(tx, ty),
          child: Transform.rotate(
            angle: rot,
            child: Transform.scale(
              scale: scale,
              child: GestureDetector(
                onTap: _onTap,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: SizedBox(
                    width: _petSize,
                    height: _petSize,
                    child: Stack(
                      children: [
                        // 身体底图（已去掉耳朵/呆毛/鱼鳍/尾巴）
                        Positioned.fill(
                          child: Image.asset('assets/body_base.png',
                              fit: BoxFit.contain),
                        ),
                        // 8 个独立部件（尾/耳/发带/鱼鳍/蝴蝶结/呆毛）
                        for (var i = 0; i < _parts.length; i++)
                          _partWidget(_parts[i], partAngles[i]),
                        // 眨眼叠加层（睁眼时不绘制，保留原图眼睛）
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _EyePainter(blinking: _blinking),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _partWidget(_Part part, double angle) {
    return Positioned(
      left: part.rect.left * _petSize,
      top: part.rect.top * _petSize,
      width: part.rect.width * _petSize,
      height: part.rect.height * _petSize,
      child: Transform.rotate(
        angle: angle,
        alignment: part.pivot,
        child: Image.asset(part.asset, fit: BoxFit.fill),
      ),
    );
  }

  Widget _bubbleWidget(Color primary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primary.withValues(alpha: .35)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Text(_bubble,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, height: 1.35, color: Color(0xFF1F2D3D))),
          ),
        ),
        CustomPaint(size: const Size(16, 8), painter: _Triangle(primary)),
      ],
    );
  }

  Widget _controlPanel(Color card, Color primary, Color sub) {
    return Card(
      color: card,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('动效开关',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2D3D))),
            const SizedBox(height: 12),
            _switch('呼吸浮动', _kBreath, (v) => setState(() => _kBreath = v), sub),
            _switch('左右摇摆', _kSway, (v) => setState(() => _kSway = v), sub),
            _switch('耳朵/鱼鳍/呆毛/尾巴摆动', _kPart,
                (v) => setState(() => _kPart = v), sub),
            _switch('定时眨眼', _kBlink, (v) => setState(() => _kBlink = v), sub),
            _switch('身体跟随', _kFollow, (v) {
              setState(() {
                _kFollow = v;
                if (!v) _pointer = Offset.zero;
              });
            }, sub),
            _switch('点击互动', _kTap, (v) => setState(() => _kTap = v), sub),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: primary),
                onPressed: () =>
                    _say(_demoLines[_rand.nextInt(_demoLines.length)]),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('让它说句话'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _testBlink,
                icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                label: const Text('测试眨眼位置'),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '说明：桌宠已拆分为“身体 + 猫耳 + 头部两侧鱼鳍 + 呆毛 + 尾巴”分层素材，'
                '各部件围绕根部缓慢摆动；身体会随鼠标轻微倾斜，并会自然眨眼。',
                style: TextStyle(fontSize: 11.5, height: 1.5, color: sub),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> on, Color sub) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF1F2D3D))),
      value: value,
      onChanged: on,
    );
  }
}

// 气泡底部小三角
class _Triangle extends CustomPainter {
  final Color primary;
  _Triangle(this.primary);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
    // 描边（只画两条斜边）
    final edge = Paint()
      ..color = primary.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, 0), Offset(size.width / 2, size.height), edge);
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width / 2, size.height), edge);
  }

  @override
  bool shouldRepaint(covariant _Triangle old) => false;
}

// 眼睛层：睁眼时不绘制（保留原图眼睛）；闭眼时画肤色眼睑 + 睫毛线
class _EyePainter extends CustomPainter {
  final bool blinking;
  // 眼睛中心（归一化）：右眼(画面左)、左眼(画面右)
  static const _eyes = [
    Offset(0.396, 0.527),
    Offset(0.568, 0.539),
  ];

  _EyePainter({required this.blinking});

  @override
  void paint(Canvas canvas, Size size) {
    if (!blinking) return; // 睁眼时保留原图眼睛，不做任何覆盖
    final w = size.width, h = size.height;

    // 闭眼：肤色眼睑（上缘加高，盖住黑色上眼线，避免眉毛处黑影）
    final skin = Paint()
      ..color = const Color(0xFFFCF5EA)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.005);
    for (final e in _eyes) {
      final cx = e.dx * w;
      final cy = (e.dy - 0.012) * h; // 整体上移盖住上眼线
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, cy),
            width: w * 0.128,
            height: h * 0.105),
        skin,
      );
    }
    // ︶ 形闭眼睫毛线（平滑贝塞尔）
    final lash = Paint()
      ..color = const Color(0xFF2A2330)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.0068
      ..strokeCap = StrokeCap.round;
    for (final e in _eyes) {
      final cx = e.dx * w, cy = (e.dy - 0.012) * h;
      final hw = w * 0.045;
      final path = Path()
        ..moveTo(cx - hw, cy - h * 0.004)
        ..quadraticBezierTo(
            cx, cy + h * 0.009, cx + hw, cy - h * 0.004);
      canvas.drawPath(path, lash);
    }
  }

  @override
  bool shouldRepaint(covariant _EyePainter old) =>
      old.blinking != blinking;
}
