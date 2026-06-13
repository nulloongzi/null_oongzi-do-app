/// 클럽/팀 모델. 웹 data.js의 clubs 문서 + customTeams 구조와 호환.
class Club {
  final String id;
  final String name;
  final String schedule; // "월 19:00~21:00 / 화 20:00~22:00"
  final String? target;
  final String? address;
  final double? lat;
  final double? lng;
  final bool isCustom;

  const Club({
    required this.id,
    required this.name,
    this.schedule = '',
    this.target,
    this.address,
    this.lat,
    this.lng,
    this.isCustom = false,
  });

  /// Firestore clubs 문서(coordinates 평탄화 포함) → Club.
  factory Club.fromFirestore(String id, Map<String, dynamic> d) {
    double? lat;
    double? lng;
    final coords = d['coordinates'];
    if (coords is Map) {
      lat = (coords['lat'] as num?)?.toDouble();
      lng = (coords['lng'] as num?)?.toDouble();
    } else {
      lat = (d['lat'] as num?)?.toDouble();
      lng = (d['lng'] as num?)?.toDouble();
    }
    return Club(
      id: id,
      name: (d['name'] ?? '') as String,
      schedule: (d['schedule'] ?? d['schedule_raw'] ?? '') as String,
      target: d['target'] as String?,
      address: d['address'] as String?,
      lat: lat,
      lng: lng,
      isCustom: (d['isCustom'] ?? false) as bool,
    );
  }

  /// customTeams 맵 항목(웹 addCustomTeam 구조) → Club.
  factory Club.fromMap(Map<String, dynamic> m) {
    return Club(
      id: (m['id'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      schedule: (m['schedule'] ?? m['schedule_raw'] ?? '') as String,
      target: m['target'] as String?,
      address: m['address'] as String?,
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      isCustom: (m['isCustom'] ?? false) as bool,
    );
  }

  /// customTeams 저장용 직렬화 (웹 newTeam 구조와 동일 키).
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'schedule': schedule,
        'schedule_raw': schedule,
        'isCustom': isCustom,
        'target': target,
        'address': address,
        'lat': lat,
        'lng': lng,
      };
}
