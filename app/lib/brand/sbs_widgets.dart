import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'sbs_colors.dart';
import 'sbs_theme.dart';

bool sbsReduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Stoppuhr-Ring: Fortschritt als Lünetten-Bogen mit Strichen.
///
/// Zeichnet sich beim Erscheinen per Zeiger-Sweep (600 ms) auf [progress].
class StopwatchRing extends StatefulWidget {
  const StopwatchRing({
    super.key,
    required this.progress,
    this.size = 260,
    this.color = SbsColors.fg,
    this.strokeWidth = 6,
    this.ticks = 60,
    this.sweepOnAppear = true,
    this.child,
  });

  /// 0..1 (im Uhrzeigersinn ab 12 Uhr).
  final double progress;
  final double size;
  final Color color;
  final double strokeWidth;

  /// Anzahl Striche am Außenrand; 0 = keine Striche.
  final int ticks;
  final bool sweepOnAppear;
  final Widget? child;

  @override
  State<StopwatchRing> createState() => _StopwatchRingState();
}

class _StopwatchRingState extends State<StopwatchRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    if (!widget.sweepOnAppear || sbsReduceMotion(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _RingPainter(
                  progress: widget.progress.clamp(0.0, 1.0) *
                      Curves.easeOutCubic.transform(_c.value),
                  color: widget.color,
                  strokeWidth: widget.strokeWidth,
                  ticks: widget.ticks,
                ),
              ),
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.ticks,
  });

  final double progress;
  final Color color;
  final double strokeWidth;
  final int ticks;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    var arcR = outer - strokeWidth / 2;

    if (ticks > 0) {
      final major = outer * 0.085;
      final minor = outer * 0.05;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      for (var i = 0; i < ticks; i++) {
        final f = i / ticks;
        final lit = f <= progress && progress > 0;
        final isMajor = i % (ticks ~/ 12 == 0 ? 1 : ticks ~/ 12) == 0;
        final len = isMajor ? major : minor;
        p
          ..strokeWidth = isMajor ? 2.2 : 1.4
          ..color = lit ? color : SbsColors.lineStrong;
        final a = -math.pi / 2 + 2 * math.pi * f;
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + dir * (outer - len), c + dir * outer, p);
      }
      arcR = outer - major - 7 - strokeWidth / 2;
    }

    final rect = Rect.fromCircle(center: c, radius: arcR);
    canvas.drawCircle(
        c,
        arcR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, strokeWidth / 4)
          ..color = SbsColors.line);
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt
          ..color = color,
      );
      // Zeigerspitze
      final a = -math.pi / 2 + 2 * math.pi * progress;
      final tip = c + Offset(math.cos(a), math.sin(a)) * arcR;
      canvas.drawCircle(tip, strokeWidth * 0.9, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) =>
      o.progress != progress ||
      o.color != color ||
      o.strokeWidth != strokeWidth ||
      o.ticks != ticks;
}

/// Einfahren von links (−24 px, Unschärfe 6 → 0, 380 ms, expo-out),
/// gestaffelt um 40 ms je [index]. Bei „Animationen entfernen" nur Einblenden.
class SlideIn extends StatefulWidget {
  const SlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<SlideIn> with SingleTickerProviderStateMixin {
  static const _dur = 380;
  static const _step = 40;

  late final AnimationController _c;
  bool _init = false;

  @override
  void initState() {
    super.initState();
    final delay = math.min(widget.index, 12) * _step;
    _c = AnimationController(
        vsync: this, duration: Duration(milliseconds: _dur + delay));
    _delayFrac = delay / (_dur + delay);
  }

  late final double _delayFrac;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    if (sbsReduceMotion(context)) {
      _c.duration = const Duration(milliseconds: 200);
      _reduced = true;
    }
    _c.forward();
  }

  bool _reduced = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final raw = _c.value;
        final u = _reduced
            ? raw
            : Interval(_delayFrac, 1, curve: const Cubic(.16, 1, .3, 1))
                .transform(raw);
        if (u >= 1) return child!;
        Widget w = child!;
        if (!_reduced) {
          final sigma = 6 * (1 - u);
          if (sigma > 0.3) {
            w = ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                  sigmaX: sigma, sigmaY: 0, tileMode: TileMode.decal),
              child: w,
            );
          }
          w = Transform.translate(offset: Offset(-24 * (1 - u), 0), child: w);
        }
        return Opacity(opacity: u.clamp(0.0, 1.0), child: w);
      },
    );
  }
}

/// Liste von Kindern mit gestaffeltem Einfahren (Spalte).
///
/// Jedes Kind sollte einen stabilen [Key] tragen, wenn die Liste sich je
/// nach Ladezustand in Länge/Reihenfolge ändert: ohne Key matcht Flutter
/// Elemente rein nach Position, sodass ein eingefügtes/entferntes Element
/// alle nachfolgenden als "neu" ansieht und ihre Einfahr-Animation erneut
/// abspielt.
List<Widget> sbsStagger(List<Widget> children, {int start = 0}) {
  var i = start;
  return [
    for (final c in children)
      if (c is SizedBox) c else SlideIn(key: c.key, index: i++, child: c),
  ];
}

/// Kleines Label (GROSSBUCHSTABEN, +0,12 em).
class SbsLabel extends StatelessWidget {
  const SbsLabel(this.text, {super.key, this.color = SbsColors.fgMuted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: SbsText.label(color: color));
}

/// Überschrift im Display-Stil.
class SbsHeading extends StatelessWidget {
  const SbsHeading(this.text,
      {super.key, this.size = 26, this.color = SbsColors.fg, this.align});

  final String text;
  final double size;
  final Color color;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      textAlign: align, style: SbsText.display(size, color: color));
}

/// Karte mit 1-px-Rahmen (Variante für Statusfarben).
class SbsCard extends StatelessWidget {
  const SbsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor = SbsColors.line,
    this.color = SbsColors.surface,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color borderColor;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: child,
      );
}

/// Schräge Striche als Trenner / Ladeanzeige (n Striche, [lit] leuchten).
class TickRow extends StatelessWidget {
  const TickRow({
    super.key,
    required this.count,
    required this.lit,
    this.height = 14,
    this.color = SbsColors.fg,
  });

  final int count;
  final int lit;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: EdgeInsets.only(right: i == count - 1 ? 0 : 7),
            child: Transform(
              transform: Matrix4.skewX(-0.25),
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: 5,
                height: height,
                color: i < lit ? color : SbsColors.lineStrong,
              ),
            ),
          ),
      ],
    );
  }
}
