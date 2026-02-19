import 'package:flutter/material.dart';

class VoiceCurveCompareChart extends StatelessWidget {
  final List<double> referenceCurve;
  final List<double> userCurve;
  final String referenceLabel;
  final String userLabel;

  const VoiceCurveCompareChart({
    super.key,
    required this.referenceCurve,
    required this.userCurve,
    this.referenceLabel = '기준',
    this.userLabel = '내 음성',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _LegendDot(color: Color(0xFF1D4ED8)),
            const SizedBox(width: 4),
            Text(referenceLabel, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 10),
            const _LegendDot(color: Color(0xFFDC2626)),
            const SizedBox(width: 4),
            Text(userLabel, style: const TextStyle(fontSize: 11)),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: CustomPaint(
            painter: _VoiceCurvePainter(
              referenceCurve: referenceCurve,
              userCurve: userCurve,
            ),
            child: Container(),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _VoiceCurvePainter extends CustomPainter {
  final List<double> referenceCurve;
  final List<double> userCurve;

  _VoiceCurvePainter({
    required this.referenceCurve,
    required this.userCurve,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    final refPaint = Paint()
      ..color = const Color(0xFF1D4ED8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final userPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 3; i++) {
      final y = size.height * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      gridPaint..style = PaintingStyle.stroke,
    );

    _drawCurve(canvas, size, referenceCurve, refPaint);
    _drawCurve(canvas, size, userCurve, userPaint);
  }

  void _drawCurve(
    Canvas canvas,
    Size size,
    List<double> curve,
    Paint paint,
  ) {
    if (curve.length < 2) return;
    final path = Path();
    for (int i = 0; i < curve.length; i++) {
      final x = (i / (curve.length - 1)) * size.width;
      final y = (1 - curve[i].clamp(0.0, 1.0)) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _VoiceCurvePainter oldDelegate) {
    return oldDelegate.referenceCurve != referenceCurve ||
        oldDelegate.userCurve != userCurve;
  }
}
