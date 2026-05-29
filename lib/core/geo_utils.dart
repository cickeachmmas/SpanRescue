// ═══════════════════════════════════════════════════════
// geo_utils.dart — الحسابات الجغرافية
// Haversine Formula + Geo-Interpolation للضحايا بدون GPS
// ═══════════════════════════════════════════════════════

import 'dart:math' as math;
import '../models/mesh_message.dart';

class GeoUtils {
  static const double _earthRadius = 6371000.0; // بالأمتار

  // ─── Haversine Formula ────────────────────────────
  // تحسب المسافة الكرومغناطيسية بين نقطتين بالأمتار
  static double distanceInMeters(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
        math.cos(_toRad(lat2)) *
        math.sin(dLng / 2) *
        math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadius * c;
  }

  // ─── Bearing (زاوية البوصلة) ─────────────────────
  // تحسب الزاوية من نقطة إلى نقطة (0-360 درجة)
  // تُستخدم لوضع النقاط على الرادار
  static double bearingDegrees(
    double fromLat, double fromLng,
    double toLat, double toLng,
  ) {
    final dLng = _toRad(toLng - fromLng);
    final lat1 = _toRad(fromLat);
    final lat2 = _toRad(toLat);

    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    final bearing = _toDeg(math.atan2(y, x));
    return (bearing + 360) % 360;
  }

  // ─── Geo-Interpolation ────────────────────────────
  // للضحايا تحت الأنقاض بدون GPS
  // نضعهم على محيط الرادار بزاوية عشوائية ثابتة مشتقة من Node ID
  static GeoLocation interpolatePosition({
    required GeoLocation rescuerLocation,
    required String victimNodeId,
    double radiusMeters = 300.0, // نضعهم في نطاق 300 متر
  }) {
    // نشتق زاوية ثابتة وفريدة من Node ID
    final seed = victimNodeId.hashCode.abs();
    final angle = _toRad((seed % 360).toDouble());

    // نحسب الإحداثيات التقديرية
    final deltaLat = (radiusMeters / _earthRadius) * math.cos(angle);
    final deltaLng = (radiusMeters / _earthRadius) *
        math.sin(angle) /
        math.cos(_toRad(rescuerLocation.lat));

    return GeoLocation(
      lat: rescuerLocation.lat + _toDeg(deltaLat),
      lng: rescuerLocation.lng + _toDeg(deltaLng),
      isInterpolated: true,
    );
  }

  // ─── موقع النقطة على الرادار ─────────────────────
  // تحوّل المسافة والزاوية إلى إحداثيات (x, y) على الرادار
  static RadarPoint toRadarPoint({
    required double distanceMeters,
    required double bearingDegrees,
    required double radarRadiusPx,    // نصف قطر الرادار بالبكسل
    required double maxRangeMeters,   // المدى الأقصى (500m)
  }) {
    // نسبة المسافة إلى المدى الأقصى
    final ratio = (distanceMeters / maxRangeMeters).clamp(0.0, 1.0);
    final distPx = ratio * radarRadiusPx;

    // تحويل الزاوية إلى إحداثيات x, y
    final angleRad = _toRad(bearingDegrees - 90); // تعديل الاتجاه
    final x = distPx * math.cos(angleRad);
    final y = distPx * math.sin(angleRad);

    return RadarPoint(x: x, y: y, distanceMeters: distanceMeters);
  }

  // ─── Helpers ──────────────────────────────────────
  static double _toRad(double deg) => deg * math.pi / 180.0;
  static double _toDeg(double rad) => rad * 180.0 / math.pi;

  // تنسيق المسافة للعرض
  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  // تنسيق الإحداثيات للعرض
  static String formatCoords(double lat, double lng) {
    return '${lat.toStringAsFixed(7)}, ${lng.toStringAsFixed(7)}';
  }
}

// ─── نقطة على الرادار ────────────────────────────────
class RadarPoint {
  final double x;
  final double y;
  final double distanceMeters;

  const RadarPoint({
    required this.x,
    required this.y,
    required this.distanceMeters,
  });
}
