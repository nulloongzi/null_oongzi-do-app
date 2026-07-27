// provider_stamp.dart — 네임카드 로그인 수단 스탬프 이스터에그. 웹 pc-provider-mark 포팅.
//
// 카드 왼쪽 상단, 밥 이름 워터마크 옆에 로그인 제공자를 단색 저채도(opacity 0.42)
// 아이콘으로 눌러 찍는다 — 원색 로고가 아니라 카드 소재에 찍힌 스탬프 느낌.
// 카카오=초기 카카오톡 앱 아이콘 오마주(TALK 말풍선), 네이버=옛 로고 오마주(날개 모자),
// 구글=옛 세리프 로고 오마주(G+그림자), 누룽지도(이메일)=로고 단순화(그릇에 얹어진 밥).
// provider가 빈 문자열(판별 불가)이면 아무것도 그리지 않는다.
import 'package:flutter/material.dart';

class ProviderStamp extends StatelessWidget {
  const ProviderStamp({super.key, required this.provider, this.size = 20});

  /// 'kakao' | 'naver' | 'google' | 'rice' | ''(미표시)
  final String provider;
  final double size;

  static const _kakaoColor = Color(0xFFA97C00);
  static const _naverColor = Color(0xFF0A7A43);
  static const _googleColor = Color(0xFF795548);
  static const _riceColor = Color(0xFFA8842C);

  @override
  Widget build(BuildContext context) {
    final Widget? mark = switch (provider) {
      'kakao' => CustomPaint(painter: _KakaoTalkBubblePainter(_kakaoColor)),
      'naver' => CustomPaint(painter: _NaverWingedHatPainter(_naverColor)),
      'google' => const _SerifG(color: _googleColor),
      'rice' => CustomPaint(painter: _RiceBowlPainter(_riceColor)),
      _ => null,
    };
    if (mark == null) return const SizedBox.shrink();
    return Opacity(
      opacity: 0.42,
      child: SizedBox(width: size, height: size, child: mark),
    );
  }
}

// 구글: 옛 로고(1998~2015, Catull 세리프 + 입체 그림자) 오마주
class _SerifG extends StatelessWidget {
  const _SerifG({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'G',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          fontFamily: 'Georgia',
          fontFamilyFallback: const ['Times New Roman', 'serif'],
          color: color,
          height: 1,
          shadows: const [
            Shadow(offset: Offset(1, 1), color: Color(0x484E342E)),
          ],
        ),
      ),
    );
  }
}

// 카카오: 초기 카카오톡 앱 아이콘 오마주 — 말풍선 + TALK 각인 (웹 SVG 포팅, 24 viewBox 기준)
class _KakaoTalkBubblePainter extends CustomPainter {
  _KakaoTalkBubblePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.scale(s, s);

    final bubble = Path()
      ..moveTo(12, 4)
      ..cubicTo(7, 4, 3, 7.2, 3, 11.2)
      ..cubicTo(3, 13.8, 4.7, 16.1, 7.3, 17.4)
      // 꼬리: 왼쪽 아래로 삐죽
      ..lineTo(6.5, 20.4)
      ..cubicTo(6.4, 20.8, 6.8, 21.1, 7.1, 20.9)
      ..lineTo(10.6, 18.6)
      ..cubicTo(11.1, 18.7, 11.5, 18.7, 12, 18.7)
      ..cubicTo(17, 18.7, 21, 15.2, 21, 11.2)
      ..cubicTo(21, 7.2, 17, 4, 12, 4)
      ..close();
    canvas.drawPath(bubble, Paint()..color = color);

    // TALK 각인 — 밝은 반투명 텍스트 (웹과 동일: knockout 대체)
    final tp = TextPainter(
      text: const TextSpan(
        text: 'TALK',
        style: TextStyle(
          fontSize: 4.6,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: Color(0xEBFFFFFF),
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(12 - tp.width / 2, 11.3 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_KakaoTalkBubblePainter old) => old.color != color;
}

// 네이버: 옛 로고 오마주 — 날개 달린 모자 (웹 SVG 포팅, 24 viewBox 기준)
class _NaverWingedHatPainter extends CustomPainter {
  _NaverWingedHatPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.scale(s, s);
    final paint = Paint()..color = color;

    // 모자 꼭지
    canvas.drawCircle(const Offset(12, 5.2), 1.1, paint);
    // 모자 돔 (반타원)
    final dome = Path()
      ..moveTo(6, 11)
      ..cubicTo(6.2, 8.4, 8.8, 6.4, 12, 6.4)
      ..cubicTo(15.2, 6.4, 17.8, 8.4, 18, 11)
      ..close();
    canvas.drawPath(dome, paint);
    // 챙 (라운드 바)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3.6, 11.8, 16.8, 2),
        const Radius.circular(1),
      ),
      paint,
    );
    // 왼쪽 날개
    final leftWing = Path()
      ..moveTo(6.3, 10.2)
      ..cubicTo(5, 8.4, 3, 7.5, 1.2, 7.7)
      ..cubicTo(1.6, 9.6, 3.1, 11, 5, 11.3)
      ..close();
    canvas.drawPath(leftWing, paint);
    // 오른쪽 날개 (대칭)
    final rightWing = Path()
      ..moveTo(17.7, 10.2)
      ..cubicTo(19, 8.4, 21, 7.5, 22.8, 7.7)
      ..cubicTo(22.4, 9.6, 20.9, 11, 19, 11.3)
      ..close();
    canvas.drawPath(rightWing, paint);
  }

  @override
  bool shouldRepaint(_NaverWingedHatPainter old) => old.color != color;
}

// 누룽지도: 로고 단순화 — 그릇에 얹어진 밥 (웹 SVG 포팅, 24 viewBox 기준)
class _RiceBowlPainter extends CustomPainter {
  _RiceBowlPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.scale(s, s);
    final paint = Paint()..color = color;

    // 밥 (뭉게진 봉우리)
    final rice = Path()
      ..moveTo(12, 4.6)
      ..cubicTo(10.1, 4.6, 8.8, 5.6, 8.1, 6.8)
      ..cubicTo(7.1, 6.4, 5.7, 7.1, 5.7, 8.5)
      ..cubicTo(5.7, 9.4, 6.4, 10, 7.1, 10)
      ..lineTo(16.9, 10)
      ..cubicTo(17.6, 10, 18.3, 9.4, 18.3, 8.5)
      ..cubicTo(18.3, 7.1, 16.9, 6.4, 15.9, 6.8)
      ..cubicTo(15.2, 5.6, 13.9, 4.6, 12, 4.6)
      ..close();
    canvas.drawPath(rice, paint);

    // 그릇 (반구 + 굽)
    final bowl = Path()
      ..moveTo(4.2, 11.6)
      ..lineTo(19.8, 11.6)
      ..cubicTo(19.8, 14.7, 17.3, 17.2, 14, 17.8)
      ..lineTo(14, 18.7)
      ..cubicTo(14, 19.1, 13.7, 19.4, 13.3, 19.4)
      ..lineTo(10.7, 19.4)
      ..cubicTo(10.3, 19.4, 10, 19.1, 10, 18.7)
      ..lineTo(10, 17.8)
      ..cubicTo(6.7, 17.2, 4.2, 14.7, 4.2, 11.6)
      ..close();
    canvas.drawPath(bowl, paint);
  }

  @override
  bool shouldRepaint(_RiceBowlPainter old) => old.color != color;
}
