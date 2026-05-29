// ═══════════════════════════════════════════════════════
// radar_overlay.dart — الرادار العسكري
// Canvas Engine — دائرة استشعار عسكرية خضراء
// ═══════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/geo_utils.dart';
import '../../models/node_info.dart';
import '../../models/mesh_message.dart';
import '../../theme/app_theme.dart';

class RadarOverlay extends StatefulWidget {
  final GeoLocation myLocation;
  final List<NodeInfo> nodes;
  static const double maxRangeMeters = 500.0;
  static const double radarSize = 280.0;

  const RadarOverlay({
    super.key,
    required this.myLocation,
    required this.nodes,
  });

  @override
  State<RadarOverlay> createState() => _RadarOverlayState();
}

class _RadarOverlayState extends State<RadarOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;
  late Animation<double> _sweepAnimation;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _sweepAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_sweepController);
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: RadarOverlay.radarSize + 20,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.6),
            Colors.black.withOpacity(0.9),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: SizedBox(
          width: RadarOverlay.radarSize,
          height: RadarOverlay.radarSize,
          child: AnimatedBuilder(
            animation: _sweepAnimation,
            builder: (context, _) {
              return CustomPaint(
                painter: _RadarPainter(
                  sweepAngle: _sweepAnimation.value,
                  nodes: widget.nodes,
                  myLocation: widget.myLocation,
                  maxRange: RadarOverlay.maxRangeMeters,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── الـ Painter الرئيسي ──────────────────────────────
class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final List<NodeInfo> nodes;
  final GeoLocation myLocation;
  final double maxRange;

  _RadarPainter({
    required this.sweepAngle,
    required this.nodes,
    required this.myLocation,
    required this.maxRange,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    _drawBackground(canvas, center, radius);
    _drawRings(canvas, center, radius);
    _drawGrid(canvas, center, radius);
    _drawSweep(canvas, center, radius);
    _drawCompassLabels(canvas, center, radius);
    _drawNodes(canvas, center, radius);
    _drawCenter(canvas, center);
    _drawRangeLabels(canvas, center, radius);
  }

  // ─── خلفية الرادار ───────────────────────────────
  void _drawBackground(Canvas canvas, Offset center, double radius) {
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF001500),
          const Color(0xFF000D00),
          Colors.black,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, bgPaint);

    // حد خارجي
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF004400)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  // ─── حلقات المسافة ────────────────────────────────
  void _drawRings(Canvas canvas, Offset center, double radius) {
    final ringPaint = Paint()
      ..color = const Color(0xFF003300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // 4 حلقات: 125m, 250m, 375m, 500m
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4), ringPaint);
    }
  }

  // ─── خطوط الشبكة ─────────────────────────────────
  void _drawGrid(Canvas canvas, Offset center, double radius) {
    final gridPaint = Paint()
      ..color = const Color(0xFF002200)
      ..strokeWidth = 0.5;

    // خطوط كل 30 درجة
    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        ),
        gridPaint,
      );
    }
  }

  // ─── خط المسح الدوار ─────────────────────────────
  void _drawSweep(Canvas canvas, Offset center, double radius) {
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF00FF00).withOpacity(0.0),
          const Color(0xFF00FF00).withOpacity(0.3),
          const Color(0xFF00FF00).withOpacity(0.0),
        ],
        stops: const [0.0, 0.7, 0.95, 1.0],
        startAngle: sweepAngle - 0.8,
        endAngle: sweepAngle,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint..style = PaintingStyle.fill);

    // خط المسح الرئيسي
    canvas.drawLine(
      center,
      Offset(
        center.dx + radius * math.cos(sweepAngle),
        center.dy + radius * math.sin(sweepAngle),
      ),
      Paint()
        ..color = const Color(0xFF00FF00).withOpacity(0.8)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  // ─── تسميات البوصلة ───────────────────────────────
  void _drawCompassLabels(Canvas canvas, Offset center, double radius) {
    final labels = {
      'N': -math.pi / 2,
      'S': math.pi / 2,
      'E': 0.0,
      'W': math.pi,
    };

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final entry in labels.entries) {
      final x = center.dx + (radius + 14) * math.cos(entry.value);
      final y = center.dy + (radius + 14) * math.sin(entry.value);

      textPainter.text = TextSpan(
        text: entry.key,
        style: const TextStyle(
          color: Color(0xFF00AA00),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: 'SpaceMono',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  // ─── تسميات المسافة ──────────────────────────────
  void _drawRangeLabels(Canvas canvas, Offset center, double radius) {
    final ranges = ['125m', '250m', '375m', '500m'];
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < ranges.length; i++) {
      final r = radius * ((i + 1) / 4);
      textPainter.text = TextSpan(
        text: ranges[i],
        style: const TextStyle(
          color: Color(0xFF005500),
          fontSize: 8,
          fontFamily: 'SpaceMono',
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(center.dx + 2, center.dy - r + 2),
      );
    }
  }

  // ─── نقاط الأجهزة ────────────────────────────────
  void _drawNodes(Canvas canvas, Offset center, double radius) {
    for (final node in nodes) {
      GeoLocation loc = node.location;

      // Geo-Interpolation إذا GPS مفقود
      if (loc.isGpsDenied && !myLocation.isGpsDenied) {
        loc = GeoUtils.interpolatePosition(
          rescuerLocation: myLocation,
          victimNodeId: node.nodeId,
        );
      }

      if (loc.lat == 0.0 || myLocation.lat == 0.0) continue;

      final distance = GeoUtils.distanceInMeters(
        myLocation.lat, myLocation.lng,
        loc.lat, loc.lng,
      );

      final bearing = GeoUtils.bearingDegrees(
        myLocation.lat, myLocation.lng,
        loc.lat, loc.lng,
      );

      final radarPoint = GeoUtils.toRadarPoint(
        distanceMeters: distance,
        bearingDegrees: bearing,
        radarRadiusPx: radius * 0.92,
        maxRangeMeters: maxRange,
      );

      final nodePos = Offset(
        center.dx + radarPoint.x,
        center.dy + radarPoint.y,
      );

      // لون النقطة
      final color = node.isCritical
          ? AppTheme.accentRed
          : node.isVictim
              ? AppTheme.accentOrange
              : AppTheme.accentGreen;

      // هالة
      canvas.drawCircle(
        nodePos,
        8,
        Paint()..color = color.withOpacity(0.2),
      );

      // النقطة الرئيسية
      canvas.drawCircle(
        nodePos,
        4,
        Paint()..color = color,
      );

      // نص Node ID
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: node.nodeId.replaceAll('Node_', ''),
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 7,
            fontFamily: 'SpaceMono',
          ),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(nodePos.dx + 6, nodePos.dy - 4),
      );
    }
  }

  // ─── مركز الرادار (أنا) ───────────────────────────
  void _drawCenter(Canvas canvas, Offset center) {
    // هالة خارجية
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..color = AppTheme.accentCyan.withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );

    // نقطة مركزية
    canvas.drawCircle(
      center,
      5,
      Paint()..color = AppTheme.accentCyan,
    );

    // حد
    canvas.drawCircle(
      center,
      5,
      Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.nodes != nodes;
  }
}
