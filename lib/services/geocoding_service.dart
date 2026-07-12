// geocoding_service.dart — 주소 → 좌표. 서버 Cloud Function(geocodeAddress) 호출.
// 시크릿(네이버 Maps Client Secret)은 앱에 없고 함수에만 있음. 미배포/실패 시 null → 지도피커 폴백.
import 'package:cloud_functions/cloud_functions.dart';

class GeoResult {
  final double lat;
  final double lng;
  final String? roadAddress;
  GeoResult(this.lat, this.lng, this.roadAddress);
}

class GeocodingService {
  /// 성공 시 좌표, 못 찾거나 오류면 null.
  static Future<GeoResult?> geocode(String address) async {
    final q = address.trim();
    if (q.isEmpty) return null;
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'geocodeAddress',
      );
      final res = await callable.call({'address': q});
      final d = Map<String, dynamic>.from(res.data as Map);
      final lat = (d['lat'] as num?)?.toDouble();
      final lng = (d['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return GeoResult(lat, lng, d['roadAddress'] as String?);
    } catch (_) {
      return null;
    }
  }
}
