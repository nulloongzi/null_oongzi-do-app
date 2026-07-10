// station_service.dart — 좌표 → 가까운 지하철역 (서버 nearestStation, 카카오 로컬). 실패 시 null.
import 'package:cloud_functions/cloud_functions.dart';

class StationInfo {
  final String name;
  final int distance; // m
  StationInfo(this.name, this.distance);

  /// "🚇 강남역  320m · 도보 5분"
  String get label {
    final walk = distance > 0 ? (distance / 67).round().clamp(1, 999) : 0;
    final dist = distance > 0 ? '  ${distance}m · 도보 $walk분' : '';
    return '🚇 $name$dist';
  }
}

class StationService {
  static Future<StationInfo?> nearest(double lat, double lng) async {
    try {
      final c = FirebaseFunctions.instance.httpsCallable('nearestStation');
      final res = await c.call({'lat': lat, 'lng': lng});
      final d = Map<String, dynamic>.from(res.data as Map);
      final name = d['name'] as String?;
      if (name == null || name.isEmpty) return null;
      return StationInfo(name, (d['distance'] as num?)?.toInt() ?? 0);
    } catch (_) {
      return null;
    }
  }
}
