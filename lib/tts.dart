import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 单词发音（Windows 离线方案）。
///
/// 不依赖任何第三方 TTS 插件，直接调用 Windows 自带的
/// System.Speech（SAPI）与系统英文语音 Microsoft Zira Desktop，
/// 通过 PowerShell 进程在后台朗读，因此无需联网、无需额外安装。
///
/// 说明：每次点击会启动一个轻量 PowerShell 进程（约几百毫秒后出声），
/// 连续点击会先停止上一次朗读。任何异常都静默处理，绝不影响学习流程。
class Tts {
  static Process? _proc;
  static bool _available = true;

  // 仅允许英文单词（字母、空格、连字符、撇号），从源头杜绝命令注入。
  static final RegExp _validWord = RegExp(r"^[A-Za-z][A-Za-z \-']*$");

  /// 将字符串编码为 PowerShell -EncodedCommand 所需的 UTF-16LE Base64。
  static String _utf16LeBase64(String s) {
    final bytes = <int>[];
    for (final cu in s.codeUnits) {
      bytes.add(cu & 0xFF);
      bytes.add((cu >> 8) & 0xFF);
    }
    return base64.encode(bytes);
  }

  /// 朗读英文单词。
  static Future<void> speak(String text) async {
    final w = text.trim();
    if (w.isEmpty || !_available) return;
    if (!_validWord.hasMatch(w)) return; // 非英文单词直接忽略
    final safe = w.replaceAll("'", '');

    final script = '''
Add-Type -AssemblyName System.Speech
\$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
try { \$s.SelectVoice('Microsoft Zira Desktop') } catch {}
try { \$s.Rate = -1 } catch {}
\$s.Speak('$safe')
\$s.Dispose()
''';
    try {
      _proc?.kill(); // 停止上一次朗读
      final enc = _utf16LeBase64(script);
      unawaited(Process.start(
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
         '-EncodedCommand', enc],
        mode: ProcessStartMode.detached,
      ).then((p) {
        _proc = p;
      }).catchError((_) {
        _available = false;
      }));
    } catch (_) {
      _available = false;
    }
  }

  /// 停止当前朗读。
  static void stop() {
    try {
      _proc?.kill();
    } catch (_) {}
  }
}
