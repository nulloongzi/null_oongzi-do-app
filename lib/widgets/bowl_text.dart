// bowl_text.dart — 문구 맨 앞 🍚 를 이모지 대신 로고 아이콘으로 그린다(식구 모집 배지·여기 자리 있어요? 등).
// 문구(KO/EN·웹과 같은 키)는 그대로 두고 그리는 자리에서만 바꾼다 — 웹 js/i18n.js setBowlText 와 같은 규칙.
import 'package:flutter/material.dart';

class BowlText extends StatelessWidget {
  const BowlText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    if (!text.startsWith('🍚')) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }
    final fs = DefaultTextStyle.of(context).style.merge(style).fontSize ?? 14;
    // 로고 그림 둘레에 여백이 있어 글자보다 크게 그리고, 자리는 글자 한 칸 남짓만 차지한다.
    final icon = SizedBox(
      width: fs * 1.45,
      height: fs * 1.1,
      child: OverflowBox(
        maxWidth: fs * 1.6,
        maxHeight: fs * 1.6,
        child: Image.asset(
          'assets/logo-512.png',
          width: fs * 1.6,
          height: fs * 1.6,
          excludeFromSemantics: true,
        ),
      ),
    );
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(alignment: PlaceholderAlignment.middle, child: icon),
          TextSpan(text: text.substring(2).trimLeft()),
        ],
      ),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
