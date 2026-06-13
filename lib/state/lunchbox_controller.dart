import 'package:flutter/foundation.dart';

import '../models/club.dart';
import '../services/auth_service.dart';
import '../services/clubs_repository.dart';
import '../services/lunchbox_repository.dart';

/// 도시락 상태 + 로직. 웹 lunchbox.js의 tempSlots/편집/식단/저장 흐름 포팅.
class LunchboxController extends ChangeNotifier {
  LunchboxController({
    required AuthService auth,
    required ClubsRepository clubs,
    required LunchboxRepository repo,
  })  : _auth = auth,
        _clubs = clubs,
        _repo = repo;

  final AuthService _auth;
  final ClubsRepository _clubs;
  final LunchboxRepository _repo;

  // 저장된 북마크(영속 상태) + 편집용 임시 복사본.
  List<String?> _bookmarks = List<String?>.filled(5, null);
  List<String?> _tempSlots = List<String?>.filled(5, null);
  Map<String, Club> _customTeams = {};

  bool isEditMode = false;
  bool isDietOpen = false;
  int? selectedSlotIndex;
  bool isLoading = false;

  List<String?> get slots => _tempSlots;
  Map<String, Club> get customTeams => _customTeams;
  bool get isLoggedIn => _auth.isLoggedIn;

  Club? findClub(String? id) =>
      _clubs.findClub(id, customTeams: _customTeams);

  /// 앱 시작/로그인 변화 시 데이터 로드.
  Future<void> loadData() async {
    isLoading = true;
    notifyListeners();
    try {
      if (!_clubs.isLoaded) {
        await _clubs.loadAll();
      }
      final data = await _repo.load(_auth.uid);
      _bookmarks = normalizeSlots(data.bookmarks);
      _customTeams = data.customTeams;
    } catch (e) {
      debugPrint('Lunchbox load failed: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// 시트 오픈: 편집/식단 초기화 + tempSlots = bookmarks 복사.
  void open() {
    isEditMode = false;
    isDietOpen = false;
    selectedSlotIndex = null;
    _tempSlots = normalizeSlots(List<String?>.from(_bookmarks));
    notifyListeners();
  }

  void toggleEdit() {
    isEditMode = !isEditMode;
    selectedSlotIndex = null;
    if (!isEditMode) {
      _save(); // 편집 종료 시 저장 (웹과 동일)
    }
    notifyListeners();
  }

  void toggleDiet() {
    isDietOpen = !isDietOpen;
    notifyListeners();
  }

  /// 편집모드 슬롯 탭: 첫 탭 선택 → 두 번째 탭과 스왑.
  void handleSlotTap(int index) {
    if (selectedSlotIndex == null) {
      selectedSlotIndex = index;
    } else {
      if (selectedSlotIndex != index) {
        final tmp = _tempSlots[selectedSlotIndex!];
        _tempSlots[selectedSlotIndex!] = _tempSlots[index];
        _tempSlots[index] = tmp;
      }
      selectedSlotIndex = null;
    }
    notifyListeners();
  }

  void deleteSlot(int index) {
    _tempSlots[index] = null;
    notifyListeners();
  }

  /// 커스텀 팀 추가 후 첫 빈 슬롯에 담기. 성공 시 추가된 슬롯 인덱스 반환, 실패 시 null.
  /// 반환값이 null이면 도시락이 가득 찼다는 의미.
  int? addCustomTeam(String name, String schedule) {
    final newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final team = Club(
      id: newId,
      name: name,
      schedule: schedule,
      isCustom: true,
      target: '나만의 메뉴',
      address: '사용자 추가',
    );
    _customTeams = {..._customTeams, newId: team};
    final idx = _packIntoFirstEmpty(newId);
    if (idx != null) _save(); // 즉시 영속화 (웹 bookmarkTeam과 동일)
    notifyListeners();
    return idx;
  }

  /// 기존 클럽을 첫 빈 슬롯에 담기. 이미 담겼으면 -2, 가득 차면 -1, 성공 시 인덱스.
  int bookmarkTeam(String teamId) {
    if (_tempSlots.contains(teamId)) return -2;
    final idx = _packIntoFirstEmpty(teamId);
    if (idx != null) _save(); // 즉시 영속화
    notifyListeners();
    return idx ?? -1;
  }

  int? _packIntoFirstEmpty(String teamId) {
    final empty = _tempSlots.indexWhere((s) => s == null);
    if (empty == -1) return null;
    _tempSlots[empty] = teamId;
    return empty;
  }

  /// 시트 닫힘: 편집모드였다면 저장.
  void close() {
    if (isEditMode) _save();
  }

  void _save() {
    _bookmarks = normalizeSlots(List<String?>.from(_tempSlots));
    // Optimistic: 비동기 저장, 실패해도 UI 유지.
    _repo
        .save(_auth.uid, bookmarks: _bookmarks, customTeams: _customTeams)
        .catchError((e) => debugPrint('Lunchbox save failed: $e'));
  }
}
