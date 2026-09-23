// 动态桌宠组件（实装到 Efish 主程序）
// 分层素材：身体底图 + 耳朵/呆毛/尾巴/头部两侧鱼鳍独立摆动 + 自然眨眼。
// 仅保留：部件缓慢摆动、自然眨眼、点击弹跳；不含呼吸/摇摆/鼠标跟随。
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 一个可摆动部件（坐标均为 1024 原图归一化）
class _PetPart {
  final String asset;
  final Rect rect; // 在 1024 画布中的包围盒
  final Alignment pivot; // 旋转支点（部件局部 -1..1）
  const _PetPart(this.asset, this.rect, this.pivot);
}

const _parts = <_PetPart>[
  // 尾叶（最靠后，在右侧）
  _PetPart('assets/part_tail.png', Rect.fromLTWH(0.8193, 0.4082, 0.1738, 0.1377),
      Alignment(-0.37, 0.30)),
  // 头顶猫耳（黑色耳朵 + 白色耳羽，支点在耳根发带边缘）
  _PetPart('assets/part_earL.png', Rect.fromLTWH(0.2656, 0.1289, 0.1416, 0.2051),
      Alignment(-0.2, 0.39)),
  _PetPart('assets/part_earR.png', Rect.fromLTWH(0.6504, 0.1445, 0.1299, 0.1914),
      Alignment(-0.04, 0.02)),
  // 发带前景层（固定不旋转，压在两侧耳根，保证发带不随耳朵抖动且无缝）
  _PetPart('assets/part_headband.png',
      Rect.fromLTWH(0.2441, 0.2324, 0.5371, 0.1201),
      Alignment(0.0, -0.008)),
  // 头部两侧鱼鳍（耳羽：深色三角 + 白色波浪边，绕根部上下摆动）
  _PetPart('assets/part_finL.png', Rect.fromLTWH(0.166, 0.4004, 0.0801, 0.0986),
      Alignment(-0.27, -0.21)),
  _PetPart('assets/part_finR.png', Rect.fromLTWH(0.7051, 0.4531, 0.1797, 0.1689),
      Alignment(0.17, 0.11)),
  // 蝴蝶结（静态层，不旋转，压在右鱼鳍根部前方遮挡下摆缝隙）
  _PetPart('assets/part_bow.png', Rect.fromLTWH(0.6846, 0.4111, 0.1201, 0.0957),
      Alignment(-0.01, 0)),
  // 呆毛（含描边与高光，支点在根部发带内，整体摆动）
  _PetPart('assets/part_ahoge.png',
      Rect.fromLTWH(0.4189, 0.0811, 0.2471, 0.1416),
      Alignment(0.842, 1.167)),
  // 呆毛根部发带遮挡层（静态不旋转，压在呆毛之后，始终盖住根部下端）
  _PetPart('assets/part_ahcover.png',
      Rect.fromLTWH(0.6152, 0.2148, 0.0693, 0.0283),
      Alignment(-0.014, -0.034)),
];

class AnimatedPet extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;
  final bool bounceOnTap;

  const AnimatedPet({
    super.key,
    this.size = 148,
    this.onTap,
    this.bounceOnTap = true,
  });

  @override
  State<AnimatedPet> createState() => _AnimatedPetState();
}

class _AnimatedPetState extends State<AnimatedPet>
    with TickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
  late final AnimationController _ear =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
        ..repeat();
  late final AnimationController _ahoge =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))
        ..repeat();
  late final AnimationController _tail =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
        ..repeat();
  late final AnimationController _fin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
        ..repeat();

  bool _blinking = false;
  Timer? _blinkTimer;
  final _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
  }

  @override
  void dispose() {
    _bounce.dispose();
    _ear.dispose();
    _ahoge.dispose();
    _tail.dispose();
    _fin.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  // 随机 2.2~4.6 秒眨一次眼
  void _scheduleBlink() {
    final ms = 2200 + _rand.nextInt(2400);
    _blinkTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      setState(() => _blinking = true);
      Timer(const Duration(milliseconds: 130), () {
        if (mounted) setState(() => _blinking = false);
      });
      _scheduleBlink();
    });
  }

  void _handleTap() {
    if (widget.bounceOnTap) _bounce.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_bounce, _ear, _ahoge, _tail, _fin]),
      builder: (context, _) {
        final bounceV = Curves.elasticOut.transform(
            _bounce.status == AnimationStatus.dismissed ? 0 : _bounce.value);
        final scale = 1.0 + bounceV * 0.12;
        final ty = -bounceV * (widget.size * 0.06);

        final earA = math.sin(_ear.value * 2 * math.pi) * 0.06;
        final earB = math.sin(_ear.value * 2 * math.pi + 0.9) * 0.06;
        final ahogeA = math.sin(_ahoge.value * 2 * math.pi) * 0.10;
        final tailA = math.sin(_tail.value * 2 * math.pi) * 0.06;
        final finA = math.sin(_fin.value * 2 * math.pi) * 0.07;
        final finB = math.sin(_fin.value * 2 * math.pi + 1.1) * 0.07;
        final partAngles = [
          tailA, earA, earB, 0.0, finA, finB, 0.0, ahogeA, 0.0,
        ];

        return Transform.translate(
          offset: Offset(0, ty),
          child: Transform.scale(
            scale: scale,
            child: GestureDetector(
              onTap: _handleTap,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Stack(
                    children: [
                      // 身体底图
                      Positioned.fill(
                        child: Image.asset('assets/body_base.png',
                            fit: BoxFit.contain),
                      ),
                      // 独立部件
                      for (var i = 0; i < _parts.length; i++)
                        _partWidget(_parts[i], partAngles[i]),
                      // 眨眼叠加层
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _PetEyePainter(blinking: _blinking),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _partWidget(_PetPart part, double angle) {
    return Positioned(
      left: part.rect.left * widget.size,
      top: part.rect.top * widget.size,
      width: part.rect.width * widget.size,
      height: part.rect.height * widget.size,
      child: Transform.rotate(
        angle: angle,
        alignment: part.pivot,
        child: Image.asset(part.asset, fit: BoxFit.fill),
      ),
    );
  }
}

// 眼睛层：睁眼时不绘制（保留原图眼睛）；闭眼时画肤色眼睑 + 睫毛线
class _PetEyePainter extends CustomPainter {
  final bool blinking;
  static const _eyes = [
    Offset(0.396, 0.527),
    Offset(0.568, 0.539),
  ];

  _PetEyePainter({required this.blinking});

  @override
  void paint(Canvas canvas, Size size) {
    if (!blinking) return;
    final w = size.width, h = size.height;

    final skin = Paint()
      ..color = const Color(0xFFFCF5EA)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.005);
    for (final e in _eyes) {
      final cx = e.dx * w;
      final cy = (e.dy - 0.012) * h;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, cy),
            width: w * 0.128,
            height: h * 0.105),
        skin,
      );
    }
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
  bool shouldRepaint(covariant _PetEyePainter old) =>
      old.blinking != blinking;
}
