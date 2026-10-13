import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'logo_paths.dart';
import 'sbs_colors.dart';

/// Dekodierte Logo-Pfade (ViewBox 840×770, evenOdd).
class SbsLogoPaths {
  SbsLogoPaths._();

  static Path _decode(List<List<double>> list) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final enc in list) {
      var i = 0;
      while (i < enc.length) {
        final op = enc[i++].toInt();
        switch (op) {
          case 0:
            path.moveTo(enc[i], enc[i + 1]);
            i += 2;
          case 1:
            path.lineTo(enc[i], enc[i + 1]);
            i += 2;
          case 2:
            path.cubicTo(enc[i], enc[i + 1], enc[i + 2], enc[i + 3],
                enc[i + 4], enc[i + 5]);
            i += 6;
          case 3:
            path.close();
          default:
            return path;
        }
      }
    }
    return path;
  }

  static final Path arc = _decode(kLogoArc);
  static final Path ticks = _decode(kLogoTicks);
  static final Path sbs = _decode(kLogoSbs);
  static final Path num24 = _decode(kLogo24);

  static const Offset pivot = Offset(kLogoPivotX, kLogoPivotY);
  static const Size viewBox = Size(kLogoWidth, kLogoHeight);

  /// Radius der Lünette (Zeigerlänge) in ViewBox-Einheiten.
  static const double bezelRadius = 350;

  /// Äußerer Radius (Striche) – Startradius des Ring-Pulses.
  static const double outerRadius = 380;
}

/// Zeichnet das Logo zum Zeitpunkt [t] (Sekunden) des Intro-Zeitplans
/// aus BRAND.md. `t >= SbsLogoPainter.totalSeconds` ergibt das fertige Logo.
class SbsLogoPainter extends CustomPainter {
  const SbsLogoPainter({this.t = totalSeconds, this.color = SbsColors.fg});

  static const double totalSeconds = 2.6;

  final double t;
  final Color color;

  static const _sweepCurve = Cubic(.6, 0, .2, 1);
  static const _expoOut = Cubic(.16, 1, .3, 1);

  static double _span(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    const vb = SbsLogoPaths.viewBox;
    final scale = math.min(size.width / vb.width, size.height / vb.height);
    final dx = (size.width - vb.width * scale) / 2;
    final dy = (size.height - vb.height * scale) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    const pivot = SbsLogoPaths.pivot;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..color = color;

    final sweepP = _sweepCurve.transform(_span(t, 0, 1.1));
    final sbsU = _expoOut.transform(_span(t, 1.05, 1.45));
    final numU = _expoOut.transform(_span(t, 1.40, 1.80));
    final ringP = Curves.easeOut.transform(_span(t, 1.75, 2.45));

    // 1) Lünette + Striche, vom Zeiger-Sektor freigelegt.
    if (sweepP > 0) {
      canvas.save();
      if (sweepP < 1) {
        final sector = Path()
          ..moveTo(pivot.dx, pivot.dy)
          ..arcTo(Rect.fromCircle(center: pivot, radius: 900), -math.pi / 2,
              2 * math.pi * sweepP, false)
          ..close();
        canvas.clipPath(sector, doAntiAlias: true);
      }
      canvas.drawPath(SbsLogoPaths.arc, fill);
      canvas.drawPath(SbsLogoPaths.ticks, fill);
      canvas.restore();
    }

    // 2) Zeiger (dünne Linie), blendet am Ende aus.
    final handFade = 1 - _span(t, 0.95, 1.15);
    if (t > 0 && handFade > 0) {
      final a = -math.pi / 2 + 2 * math.pi * sweepP;
      final tip = pivot +
          Offset(math.cos(a), math.sin(a)) * SbsLogoPaths.bezelRadius;
      canvas.drawLine(
        pivot,
        tip,
        Paint()
          ..color = color.withValues(alpha: handFade)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(
          pivot, 7, Paint()..color = color.withValues(alpha: handFade));
    }

    // 3) „SBS": von links, Unschärfe 12 → 0.
    if (sbsU > 0) {
      final b = SbsLogoPaths.sbs.getBounds();
      _drawBlurred(canvas, scale, SbsLogoPaths.sbs, fill, sbsU,
          Offset(-0.6 * b.width * (1 - sbsU), 0));
    }
    // 4) „24": von rechts unten.
    if (numU > 0) {
      final b = SbsLogoPaths.num24.getBounds();
      _drawBlurred(canvas, scale, SbsLogoPaths.num24, fill, numU,
          Offset(0.4 * b.width * (1 - numU), 0.1 * b.height * (1 - numU)));
    }

    // 5) Ring-Puls um den Drehpunkt.
    if (ringP > 0 && ringP < 1) {
      canvas.drawCircle(
        pivot,
        SbsLogoPaths.outerRadius * (0.85 + 0.4 * ringP),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / scale
          ..color = color.withValues(alpha: 0.4 * (1 - ringP)),
      );
    }
    canvas.restore();
  }

  void _drawBlurred(
      Canvas canvas, double scale, Path path, Paint fill, double u, Offset off) {
    final sigma = 12 * (1 - u) / scale;
    canvas.save();
    canvas.translate(off.dx, off.dy);
    if (u >= 1) {
      canvas.drawPath(path, fill);
    } else {
      final layer = Paint()
        ..color = Color.fromRGBO(255, 255, 255, u.clamp(0.0, 1.0))
        ..imageFilter = ui.ImageFilter.blur(
            sigmaX: sigma, sigmaY: sigma * 0.15, tileMode: TileMode.decal);
      canvas.saveLayer(path.getBounds().inflate(sigma * 3), layer);
      canvas.drawPath(path, fill);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SbsLogoPainter old) =>
      old.t != t || old.color != color;
}

/// Statisches Logo (fertiges Bild).
class SbsLogo extends StatelessWidget {
  const SbsLogo({super.key, this.width = 160, this.color = SbsColors.fg});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * kLogoHeight / kLogoWidth,
      child: CustomPaint(painter: SbsLogoPainter(color: color)),
    );
  }
}

/// Animiertes Logo-Intro (2,6 s, BRAND.md). Tippen überspringt.
/// [onFinished] wird genau einmal aufgerufen.
class SbsLogoIntro extends StatefulWidget {
  const SbsLogoIntro({
    super.key,
    this.onFinished,
    this.width,
    this.skippable = true,
  });

  final VoidCallback? onFinished;

  /// Logo-Breite; Standard: 78 % der verfügbaren Breite.
  final double? width;
  final bool skippable;

  @override
  State<SbsLogoIntro> createState() => _SbsLogoIntroState();
}

class _SbsLogoIntroState extends State<SbsLogoIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(
        milliseconds: (SbsLogoPainter.totalSeconds * 1000).round()),
  );
  bool _done = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      // Keine Bewegung: fertiges Logo einblenden, kurz halten.
      _c.duration = const Duration(milliseconds: 700);
    }
    _c.forward();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.skippable ? _finish : null,
      child: LayoutBuilder(builder: (context, c) {
        final w = widget.width ?? c.maxWidth * 0.78;
        return Center(
          child: SizedBox(
            width: w,
            height: w * kLogoHeight / kLogoWidth,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                if (reduce) {
                  return Opacity(
                    opacity: Curves.easeOut.transform(_c.value.clamp(0, 1)),
                    child: const CustomPaint(painter: SbsLogoPainter()),
                  );
                }
                return CustomPaint(
                  painter: SbsLogoPainter(
                      t: _c.value * SbsLogoPainter.totalSeconds),
                );
              },
            ),
          ),
        );
      }),
    );
  }
}
