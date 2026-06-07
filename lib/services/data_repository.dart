// data_repository.dart — Firestore 읽기 (clubs, pickup_games). 룰: 둘 다 공개 읽기.
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/club.dart';
import '../models/pickup_spot.dart';

class DataRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Club>> loadClubs() async {
    final snap = await _db.collection('clubs').get();
    return snap.docs.map((d) => Club.fromDoc(d)).toList();
  }

  Future<List<PickupSpot>> loadPickups() async {
    final snap = await _db.collection('pickup_games').get();
    return snap.docs.map((d) => PickupSpot.fromDoc(d)).toList();
  }
}
