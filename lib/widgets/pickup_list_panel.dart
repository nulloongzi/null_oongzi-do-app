// pickup_list_panel.dart — 픽업 탭 목록 패널. 웹 renderPickupList 포팅.
// 이번주 배지·일정·종목/레벨/초보/English 칩·장소·게임비. 탭 → 상세.
import 'package:flutter/material.dart';
import '../models/pickup_spot.dart';
import '../services/i18n.dart';
import '../theme.dart';

class PickupListPanel extends StatelessWidget {
  final List<PickupSpot> spots; // englishOnly 등 이미 필터된 목록
  final void Function(PickupSpot) onTap;
  final void Function(PickupSpot)? onInstaTap; // 인스타 핸들 탭(상세 열지 않고 바로 이동)
  const PickupListPanel({
    super.key,
    required this.spots,
    required this.onTap,
    this.onInstaTap,
  });

  String _sport(String? s) => s == '6s'
      ? t('sport_6s')
      : (s == '9s' ? t('sport_9s') : t('sport_mixed'));
  String _level(String? l) => l == 'beginner'
      ? t('lv_beginner')
      : l == 'intermediate'
      ? t('lv_intermediate')
      : l == 'advanced'
      ? t('lv_advanced')
      : t('lv_any');

  @override
  Widget build(BuildContext context) {
    if (spots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t('pk_empty'),
            style: const TextStyle(color: NurungjiColors.brown),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: spots.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _item(spots[i]),
    );
  }

  Widget _chip(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
    ),
  );

  Widget _item(PickupSpot s) {
    final sched = (s.schedule != null && s.schedule!.isNotEmpty)
        ? s.schedule
        : s.scheduleText;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onTap(s),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s.thisWeek != null && s.thisWeek!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      _chip(
                        t('this_week'),
                        NurungjiColors.yellow,
                        NurungjiColors.dark,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          s.thisWeek!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: NurungjiColors.dark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (sched != null && sched.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '🗓 ${i18nSchedule(sched)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: NurungjiColors.chipFg,
                    ),
                  ),
                ),
              Text(
                s.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: NurungjiColors.dark,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(
                    _sport(s.sport),
                    NurungjiColors.yellow,
                    NurungjiColors.dark,
                  ),
                  _chip(
                    _level(s.level),
                    NurungjiColors.chipBg,
                    NurungjiColors.chipFg,
                  ),
                  if (s.beginnerFriendly)
                    _chip(
                      t('beginner_ok'),
                      const Color(0xFFE7F6E7),
                      const Color(0xFF2E7D32),
                    ),
                  if (s.englishOk)
                    _chip(
                      t('english_ok'),
                      const Color(0xFFE6F0FB),
                      const Color(0xFF1565C0),
                    ),
                ],
              ),
              if (s.venueName != null && s.venueName!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '📍 ${s.venueName}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: NurungjiColors.brown,
                    ),
                  ),
                )
              // 장소가 유동적인 크루: 체육관 대신 지역만 보여준다.
              else if (s.region != null && s.region!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '📍 ${i18nRegion(s.region!)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: NurungjiColors.brown,
                    ),
                  ),
                ),
              // 인스타 핸들 — 외국인에게 건네는 주 연락처라 목록에서 바로 보이게 한다.
              if (s.insta != null && s.insta!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: GestureDetector(
                    onTap: () => onInstaTap?.call(s),
                    child: Text(
                      '📷 @${s.insta}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ),
                ),
              if (s.feeInfo != null && s.feeInfo!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '💰 ${i18nPrice(s.feeInfo)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: NurungjiColors.brown,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
