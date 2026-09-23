import 'package:flutter/material.dart';

import '../main.dart';
import '../tts.dart';

/// 国际音标（IPA）专用文本样式。
///
/// 说明：音标必须用正体（非斜体），并优先选用对 IPA 字符
/// （如 ˈ ˌ æ ɪ ʃ ŋ ɒ ə ʒ θ 等）支持完整的字体，否则雅黑在
/// 斜体下会把这些字符渲染成怪异字形，看起来像“乱码”。
TextStyle ipaTextStyle({double fontSize = 12, Color? color}) {
  return TextStyle(
    fontSize: fontSize,
    color: color,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
    fontFamily: 'Segoe UI',
    fontFamilyFallback: const [
      'Arial',
      'Lucida Sans Unicode',
      'Microsoft YaHei',
    ],
    letterSpacing: 0.2,
  );
}

/// 一段可发音的英文单词：文字 + 喇叭按钮（点击朗读）。
class SpeakableWord extends StatelessWidget {
  final String word;
  final double fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final bool showSpeaker;
  final TextAlign? textAlign;
  const SpeakableWord(
    this.word, {
    super.key,
    this.fontSize = 15,
    this.fontWeight,
    this.color,
    this.showSpeaker = true,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.c;
    final c = color ?? t.text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            word,
            textAlign: textAlign,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: c,
            ),
          ),
        ),
        if (showSpeaker && word.isNotEmpty)
          SpeakerButton(
            word: word,
            size: fontSize + 6,
            color: t.primary,
          ),
      ],
    );
  }
}

/// 喇叭发音按钮
class SpeakerButton extends StatefulWidget {
  final String word;
  final double size;
  final Color? color;
  final EdgeInsetsGeometry padding;
  const SpeakerButton({
    super.key,
    required this.word,
    this.size = 20,
    this.color,
    this.padding = const EdgeInsets.all(2),
  });

  @override
  State<SpeakerButton> createState() => _SpeakerButtonState();
}

class _SpeakerButtonState extends State<SpeakerButton> {
  bool _playing = false;

  Future<void> _play() async {
    setState(() => _playing = true);
    await Tts.speak(widget.word);
    // 短暂高亮反馈
    await Future.delayed(const Duration(milliseconds: 450));
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? context.c.primary;
    return IconButton(
      padding: widget.padding,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      visualDensity: VisualDensity.compact,
      splashRadius: 16,
      tooltip: '朗读单词',
      onPressed: _play,
      icon: Icon(
        _playing ? Icons.volume_up : Icons.volume_up_outlined,
        size: widget.size,
        color: c,
      ),
    );
  }
}
