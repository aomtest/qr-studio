import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';

void main() => runApp(const QrStudioApp());

/// 品牌种子色（M3E 紫）
const _seed = Color(0xFF5058DE);

class QrStudioApp extends StatefulWidget {
  const QrStudioApp({super.key});

  @override
  State<QrStudioApp> createState() => _QrStudioAppState();
}

class _QrStudioAppState extends State<QrStudioApp> {
  ThemeMode _mode = ThemeMode.system;

  bool _isDark(BuildContext context) => switch (_mode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          MediaQuery.platformBrightnessOf(context) == Brightness.dark,
      };

  void _toggle(BuildContext context) {
    setState(() => _mode = _isDark(context) ? ThemeMode.light : ThemeMode.dark);
  }

  ThemeData _theme(ColorScheme scheme) => ThemeData(
        colorScheme: scheme,
        fontFamily: 'Segoe UI Variable Text',
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          width: 360,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Studio',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: _theme(ColorScheme.fromSeed(seedColor: _seed)),
      darkTheme: _theme(ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
      )),
      home: Builder(
        builder: (context) => HomePage(
          isDark: _isDark(context),
          onToggleTheme: () => _toggle(context),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.isDark, required this.onToggleTheme});

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();
  final _qrBoundaryKey = GlobalKey();

  QrImage? _qr;
  String? _error;
  QrErrorCorrectLevel _ecl = QrErrorCorrectLevel.M;
  bool _dots = true;
  double _size = 320;

  static const _eclText = {
    QrErrorCorrectLevel.L: 'L · 7%',
    QrErrorCorrectLevel.M: 'M · 15%',
    QrErrorCorrectLevel.Q: 'Q · 25%',
    QrErrorCorrectLevel.H: 'H · 30%',
  };
  static const _eclShort = {
    QrErrorCorrectLevel.L: '低',
    QrErrorCorrectLevel.M: '中',
    QrErrorCorrectLevel.Q: '高',
    QrErrorCorrectLevel.H: '最高',
  };

  @override
  void initState() {
    super.initState();
    _controller.addListener(_regen);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _regen() {
    setState(() {
      _error = null;
      final text = _controller.text;
      if (text.trim().isEmpty) {
        _qr = null;
        return;
      }
      try {
        _qr = QrImage.fromData(data: text, errorCorrectLevel: _ecl);
      } catch (_) {
        _qr = null;
        _error = '内容过长：超出当前纠错等级的容量上限\n请缩短内容或降低纠错等级';
      }
    });
  }

  int get _bytes {
    try {
      return utf8.encode(_controller.text).length;
    } catch (_) {
      return _controller.text.length;
    }
  }

  Future<void> _savePng() async {
    final boundary = _qrBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null || !mounted) return;

    final location = await getSaveLocation(
      suggestedName: 'qrcode.png',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'PNG 图片', extensions: ['png']),
      ],
    );
    if (location == null || !mounted) return;

    try {
      await XFile.fromData(
        data.buffer.asUint8List(),
        name: 'qrcode.png',
        mimeType: 'image/png',
      ).saveTo(location.path);
      _toast('已保存 PNG');
    } catch (_) {
      _toast('保存失败，请检查写入路径');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          Positioned(
            top: -160,
            right: -120,
            child: _Blob(color: scheme.primaryContainer.withValues(alpha: .5)),
          ),
          Positioned(
            bottom: -180,
            left: -140,
            child: _Blob(color: scheme.tertiaryContainer.withValues(alpha: .4)),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth > 900;
                final input = _inputCard(context);
                final preview = _previewCard(context);
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1060),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      children: [
                        _header(context),
                        const SizedBox(height: 8),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 11, child: input),
                              const SizedBox(width: 20),
                              Expanded(flex: 9, child: preview),
                            ],
                          )
                        else ...[
                          input,
                          const SizedBox(height: 20),
                          preview,
                        ],
                        const SizedBox(height: 12),
                        _footer(context),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 顶栏 ----------------
  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: .35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: CustomPaint(painter: _LogoPainter(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'QR Studio',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'EXPRESSIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '本地二维码生成器 · 粘贴即生成',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: widget.onToggleTheme,
            tooltip: '切换深浅色主题',
            icon: Icon(widget.isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined),
          ),
        ],
      ),
    );
  }

  // ---------------- 输入卡 ----------------
  Widget _inputCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = _controller.text;
    final over = _error != null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context, '内容 CONTENT'),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            minLines: 6,
            maxLines: 10,
            style: const TextStyle(fontSize: 15, height: 1.5),
            decoration: InputDecoration(
              hintText: '在此粘贴或输入文字、链接…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${text.length} 字符 · $_bytes 字节',
                  style: TextStyle(
                    fontSize: 12,
                    color: over ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: text.isEmpty ? null : _controller.clear,
                child: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _label(context, '纠错等级 ERROR CORRECTION'),
          const SizedBox(height: 8),
          SegmentedButton<QrErrorCorrectLevel>(
            segments: [
              for (final e in const [
                QrErrorCorrectLevel.L,
                QrErrorCorrectLevel.M,
                QrErrorCorrectLevel.Q,
                QrErrorCorrectLevel.H,
              ])
                ButtonSegment(value: e, label: Text(_eclText[e]!)),
            ],
            selected: {_ecl},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              _ecl = s.first;
              _regen();
            },
          ),
          const SizedBox(height: 18),
          _label(context, '模块样式 MODULE STYLE'),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('圆点')),
              ButtonSegment(value: false, label: Text('方块')),
            ],
            selected: {_dots},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _dots = s.first),
          ),
          const SizedBox(height: 18),
          _label(context, '导出尺寸 EXPORT SIZE'),
          const SizedBox(height: 8),
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: 240, label: Text('240')),
              ButtonSegment(value: 320, label: Text('320')),
              ButtonSegment(value: 400, label: Text('400')),
              ButtonSegment(value: 560, label: Text('560')),
            ],
            selected: {_size},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _size = s.first),
          ),
        ],
      ),
    );
  }

  // ---------------- 预览卡 ----------------
  Widget _previewCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qr = _qr;

    Widget stage;
    if (_error != null) {
      stage = _placeholder(
        context,
        icon: Icons.error_outline,
        bg: scheme.errorContainer,
        fg: scheme.onErrorContainer,
        child: Text(_error!, textAlign: TextAlign.center),
      );
    } else if (qr == null) {
      stage = _placeholder(
        context,
        icon: Icons.qr_code_2_outlined,
        bg: scheme.surfaceContainerHigh,
        fg: scheme.onSurfaceVariant,
        child: const Text('粘贴或输入内容\n二维码将在此实时生成',
            textAlign: TextAlign.center),
      );
    } else {
      stage = AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Container(
          key: ValueKey('qr-${qr.moduleCount}-${_controller.text.hashCode}'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? .45 : .08),
                blurRadius: 16,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: RepaintBoundary(
            key: _qrBoundaryKey,
            child: CustomPaint(
              size: Size.square(_size),
              painter: QrPainter(qr: qr, dots: _dots),
            ),
          ),
        ),
      );
    }

    final n = qr?.moduleCount ?? 0;
    final meta = qr == null
        ? ''
        : 'QR v${(n - 17) ~/ 4} · $n×$n 模块 · 纠错 ${_eclShort[_ecl]} · $_bytes 字节';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 340),
            child: Center(child: stage),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 18,
            child: Text(meta,
                style:
                    TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: qr == null ? null : _savePng,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('保存 PNG'),
              ),
              FilledButton.tonalIcon(
                onPressed: qr == null
                    ? null
                    : () async {
                        await Clipboard.setData(
                            ClipboardData(text: _controller.text));
                        _toast('已复制内容');
                      },
                icon: const Icon(Icons.content_copy_outlined, size: 18),
                label: const Text('复制内容'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder(
    BuildContext context, {
    required IconData icon,
    required Color bg,
    required Color fg,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 320),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 30, color: fg),
          ),
          const SizedBox(height: 14),
          DefaultTextStyle(
            style: TextStyle(color: fg, fontSize: 14),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );

  Widget _footer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bolt_outlined, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '所有生成均在本地完成 · 无网络请求 · 数据不出本机',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// QR 绘制：圆点模式（定位角圆角环 + 圆心）/ 方块模式
// ---------------------------------------------------------------------------
class QrPainter extends CustomPainter {
  QrPainter({required this.qr, required this.dots, this.dark = Colors.black});

  final QrImage qr;
  final bool dots;
  final Color dark;

  static bool _isFinder(int x, int y, int n) =>
      (x < 7 && y < 7) || (x >= n - 7 && y < 7) || (x < 7 && y >= n - 7);

  @override
  void paint(Canvas canvas, Size size) {
    final n = qr.moduleCount;
    const quiet = 4;
    final cell = size.shortestSide / (n + quiet * 2);
    final ox = (size.width - cell * (n + quiet * 2)) / 2;
    final oy = (size.height - cell * (n + quiet * 2)) / 2;

    final fill = Paint()..color = dark;

    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (!qr.isDark(x, y)) continue;
        if (dots && _isFinder(x, y, n)) continue; // 定位角后面整体绘制
        final px = ox + (quiet + x) * cell;
        final py = oy + (quiet + y) * cell;
        if (dots) {
          canvas.drawCircle(
              Offset(px + cell / 2, py + cell / 2), cell * .44, fill);
        } else {
          canvas.drawRect(Rect.fromLTWH(px, py, cell + .3, cell + .3), fill);
        }
      }
    }

    if (dots) {
      final stroke = Paint()
        ..color = dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell;
      for (final c in [
        const Offset(0, 0),
        Offset(n - 7.0, 0),
        Offset(0, n - 7.0),
      ]) {
        final fx = ox + (quiet + c.dx) * cell;
        final fy = oy + (quiet + c.dy) * cell;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(fx + cell * .5, fy + cell * .5, cell * 6, cell * 6),
            Radius.circular(cell * 1.6),
          ),
          stroke,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(fx + cell * 2, fy + cell * 2, cell * 3, cell * 3),
            Radius.circular(cell * 1.1),
          ),
          fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(QrPainter old) =>
      old.qr != qr || old.dots != dots || old.dark != dark;
}

// ---------------------------------------------------------------------------
// Logo（三个圆角块 + 圆点）与背景色块
// ---------------------------------------------------------------------------
class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final s = size.width;
    final cell = s * .38;
    final r = Radius.circular(s * .11);
    void blk(double x, double y) => canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, cell, cell), r), paint);
    blk(0, 0);
    blk(s - cell, 0);
    blk(0, s - cell);
    canvas.drawCircle(Offset(s - cell / 2, s - cell / 2), cell / 2, paint);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.color != color;
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: 480,
          height: 480,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
}
