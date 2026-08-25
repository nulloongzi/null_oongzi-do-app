// anchigi_common.dart — 안치기 화면 공용 조각(카드/칩/안내 박스).
// 웹 .fold-card, .seg, .msg 스타일을 앱 디자인 토큰으로 옮김.
import 'package:flutter/material.dart';

import '../../theme.dart';

/// 안치기 카드 한 장. 웹의 .card와 같은 크림색 박스.
class AgCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AgCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: padding,
    decoration: BoxDecoration(
      color: NurungjiColors.light,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x22000000)),
    ),
    child: child,
  );
}

/// 접히는 카드. 결과가 나오면 설정 카드를 접어 결과를 위로 올린다.
class AgFoldCard extends StatelessWidget {
  final String title;
  final String? trailing;
  final bool initiallyExpanded;
  final List<Widget> children;

  const AgFoldCard({
    super.key,
    required this.title,
    this.trailing,
    this.initiallyExpanded = true,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0x22000000)),
    ),
    clipBehavior: Clip.antiAlias,
    // 배경색은 Material에 둔다 — Container에 두면 ExpansionTile의
    // 잉크 효과가 그 뒤에 그려져 보이지 않는다(프레임워크 assert).
    child: Material(
      color: NurungjiColors.light,
      child: Theme(
        // ExpansionTile 기본 구분선을 없애 카드 테두리만 보이게.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          // 같은 자리에 다른 상태로 다시 그릴 때 접힘이 갱신되도록.
          key: PageStorageKey('$title-$initiallyExpanded'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: NurungjiColors.brown,
          collapsedIconColor: NurungjiColors.brown,
          title: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: NurungjiColors.dark,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trailing!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: NurungjiColors.brown,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          children: children,
        ),
      ),
    ),
  );
}

/// 안내 박스 종류.
enum AgMsgKind { ok, info, err }

class AgMessage extends StatelessWidget {
  final String text;
  final AgMsgKind kind;
  final Widget? child;

  const AgMessage(
    this.text, {
    super.key,
    this.kind = AgMsgKind.info,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      AgMsgKind.ok => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      AgMsgKind.err => (const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      AgMsgKind.info => (const Color(0xFFF0ECE2), NurungjiColors.chipFg),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text.isNotEmpty)
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          if (child != null) ...[
            if (text.isNotEmpty) const SizedBox(height: 6),
            child!,
          ],
        ],
      ),
    );
  }
}

/// 세그먼트 선택(모드·게임 성격). 라벨 아래 부제를 넣을 수 있다.
class AgSegmented extends StatelessWidget {
  final List<({String value, String label, String? sub})> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const AgSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final o in options) ...[
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(o.value),
            child: Semantics(
              selected: o.value == selected,
              button: true,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                decoration: BoxDecoration(
                  color: o.value == selected
                      ? NurungjiColors.yellow
                      : NurungjiColors.chipBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      o.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: o.value == selected
                            ? NurungjiColors.dark
                            : NurungjiColors.chipFg,
                      ),
                    ),
                    if (o.sub != null)
                      Text(
                        o.sub!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: o.value == selected
                              ? NurungjiColors.dark.withValues(alpha: .7)
                              : NurungjiColors.brown,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (o != options.last) const SizedBox(width: 6),
      ],
    ],
  );
}

/// 작은 라벨 + 값 한 줄(참석/대기 같은 요약).
class AgStatChip extends StatelessWidget {
  final String label;
  final String value;

  const AgStatChip({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: NurungjiColors.chipBg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: NurungjiColors.brown,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: NurungjiColors.dark,
            ),
          ),
        ],
      ),
    ),
  );
}
