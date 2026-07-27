// auth_loading_layer.dart — 로그인 진행 안내 레이어. 웹 auth-loading.js/css 포팅.
//
// 화면 전환이 아니라 현재 화면 위에 끼는 반투명 레이어로 진행 상태를 보여준다.
// 제공자별 효과: 카카오=노랑 틴트+번개 섬광, 네이버=초록 물결(회전 라운드 사각형),
// 구글=안개(블러 블롭 드리프트), 누룽지도(이메일)=노란 습기 피어오름(이스터에그).
// 하단에 컴팩트 상태 필(스피너+문구), 12초 이상 지연 시 안내+닫기 버튼(탈출구).
// 접근성: MediaQuery.disableAnimations면 애니메이션 없이 정적 틴트만.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/i18n.dart';

enum AuthLoadingTheme { kakao, naver, google, rice }

class AuthLoadingLayer extends StatefulWidget {
  const AuthLoadingLayer({
    super.key,
    required this.theme,
    this.title,
    this.desc,
    this.onCancel,
  });

  final AuthLoadingTheme theme;
  final String? title;
  final String? desc;

  /// 12초 지연 후 노출되는 닫기 버튼 콜백 — 로딩에 갇히지 않게 하는 탈출구.
  final VoidCallback? onCancel;

  @override
  State<AuthLoadingLayer> createState() => _AuthLoadingLayerState();
}

class _AuthLoadingLayerState extends State<AuthLoadingLayer>
    with SingleTickerProviderStateMixin {
  // 공용 시계: 0→60초 반복. 각 painter가 자신의 주기로 나눠 쓴다.
  static const double _clockSeconds = 60;
  late final AnimationController _clock;
  Timer? _slowTimer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _slowTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Positioned.fill(
      child: Stack(
        children: [
          // 효과 레이어 — 반투명이라 뒤 화면이 계속 비쳐 보인다
          Positioned.fill(
            child: reduceMotion
                ? ColoredBox(color: _staticTint(widget.theme))
                : AnimatedBuilder(
                    animation: _clock,
                    builder: (_, _) => CustomPaint(
                      painter: _fxPainter(
                        widget.theme,
                        _clock.value * _clockSeconds,
                      ),
                    ),
                  ),
          ),
          // 상태 필 (하단 중앙)
          Positioned(
            left: 0,
            right: 0,
            bottom: 96 + MediaQuery.of(context).padding.bottom,
            child: Center(child: _pill(context)),
          ),
        ],
      ),
    );
  }

  static Color _staticTint(AuthLoadingTheme t) => switch (t) {
    AuthLoadingTheme.kakao => const Color(0x29FAC710),
    AuthLoadingTheme.naver => const Color(0x2603C75A),
    AuthLoadingTheme.google => const Color(0x249E9EA8),
    AuthLoadingTheme.rice => const Color(0x1FFAC710),
  };

  static CustomPainter _fxPainter(AuthLoadingTheme t, double sec) =>
      switch (t) {
        AuthLoadingTheme.kakao => _KakaoLightningPainter(sec),
        AuthLoadingTheme.naver => _NaverWavePainter(sec),
        AuthLoadingTheme.google => _GoogleFogPainter(sec),
        AuthLoadingTheme.rice => _RiceSteamPainter(sec),
      };

  Widget _pill(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xD1FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xB3FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E5D4037),
            blurRadius: 30,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFFFAC710),
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  widget.title ?? t('auth_signing_in'),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4E342E),
                  ),
                ),
              ),
            ],
          ),
          Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.desc ?? t('auth_signing_in_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Color(0xFF8D6E63),
                ),
              ),
            ),
          if (_slow) ...[
            const SizedBox(height: 10),
            Text(
              t('auth_slow_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: Color(0xFFB26A3F),
              ),
            ),
            if (widget.onCancel != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4E342E),
                    side: const BorderSide(color: Color(0x598D6E63)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                  ),
                  child: Text(t('auth_close')),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── 카카오: 노랑 반투명 틴트 + 간헐적 번개 섬광 (웹 alLightning 키프레임 포팅) ──
class _KakaoLightningPainter extends CustomPainter {
  _KakaoLightningPainter(this.sec);
  final double sec;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0x29FAC710));

    // 3.2초 주기: 번쩍(3%) → 소등(6%) → 잔광 번쩍(9%) → 소등(13%) → 휴지
    final p = (sec % 3.2) / 3.2;
    final streak = _keyframe(p, const [
      (0.0, 0.0),
      (0.03, 1.0),
      (0.06, 0.0),
      (0.09, 0.7),
      (0.13, 0.0),
      (1.0, 0.0),
    ]);
    final glow = _keyframe(p, const [
      (0.0, 0.0),
      (0.03, 0.9),
      (0.16, 0.0),
      (1.0, 0.0),
    ]);

    if (glow > 0) {
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0xFFFFEA80).withValues(alpha: 0.5 * glow),
      );
    }
    if (streak > 0) {
      // 사선 빛줄기: 115도 그라데이션 밴드 (웹 linear-gradient 포팅)
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.2, 0),
          Offset(size.width * 0.8, size.height),
          [
            const Color(0x00FFF4B3),
            const Color(0xFFFFF4B3).withValues(alpha: 0.85 * streak),
            Colors.white.withValues(alpha: 0.95 * streak),
            const Color(0xFFFFF4B3).withValues(alpha: 0.85 * streak),
            const Color(0x00FFF4B3),
          ],
          const [0.42, 0.47, 0.5, 0.53, 0.58],
        );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_KakaoLightningPainter old) => old.sec != sec;
}

// ── 네이버: 초록 물결 — 큰 라운드 사각형 2개가 하단 아래 중심으로 천천히 회전 ──
class _NaverWavePainter extends CustomPainter {
  _NaverWavePainter(this.sec);
  final double sec;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x1A03C75A),
    );
    final side = math.max(size.width, size.height) * 2.2;
    _wave(canvas, size, side, 9, false, const Color(0x2E03C75A), 0.43);
    _wave(canvas, size, side, 13, true, const Color(0x2103C75A), 0.46);
  }

  void _wave(
    Canvas canvas,
    Size size,
    double side,
    double period,
    bool reverse,
    Color color,
    double radiusRatio,
  ) {
    final angle = 2 * math.pi * ((sec % period) / period) * (reverse ? -1 : 1);
    final center = Offset(size.width / 2, size.height * 0.82 + side / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: side, height: side),
        Radius.circular(side * radiusRatio),
      ),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NaverWavePainter old) => old.sec != sec;
}

// ── 구글: 안개 — 회색 틴트 + 블러 블롭이 느리게 떠다님 ──
class _GoogleFogPainter extends CustomPainter {
  _GoogleFogPainter(this.sec);
  final double sec;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x249E9EA8),
    );
    final r = math.max(size.width, size.height) * 0.7;
    _blob(canvas, size, r, 16, 0.0, const Offset(0.25, 0.3), Colors.white54);
    _blob(
      canvas,
      size,
      r * 0.85,
      21,
      0.5,
      const Offset(0.75, 0.7),
      const Color(0x73C8C8D2),
    );
  }

  void _blob(
    Canvas canvas,
    Size size,
    double r,
    double period,
    double phase,
    Offset anchor,
    Color color,
  ) {
    // 왕복 드리프트 (웹 alternate 애니메이션 대응)
    final t = ((sec / period) + phase) % 1.0;
    final wave = math.sin(t * 2 * math.pi);
    final c = Offset(
      size.width * anchor.dx + wave * size.width * 0.12,
      size.height * anchor.dy + wave * size.height * 0.06,
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );
  }

  @override
  bool shouldRepaint(_GoogleFogPainter old) => old.sec != sec;
}

// ── 누룽지도(이메일) 이스터에그: 노란 습기가 아래서 피어오름 ──
class _RiceSteamPainter extends CustomPainter {
  _RiceSteamPainter(this.sec);
  final double sec;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x14FAC710),
    );
    _steam(canvas, size, 7.0, 0.0, 0.25, 0.30);
    _steam(canvas, size, 8.5, 0.47, 0.78, 0.24);
    _steam(canvas, size, 7.8, 0.72, 0.5, 0.34);
  }

  void _steam(
    Canvas canvas,
    Size size,
    double period,
    double phase,
    double xRatio,
    double rRatio,
  ) {
    final p = ((sec / period) + phase) % 1.0;
    // 아래(화면 밖)에서 위로: 0→1 동안 y가 화면을 관통해 올라가며 페이드
    final opacity = p < 0.25 ? (p / 0.25) : (1 - (p - 0.25) / 0.75);
    final r = size.width * rRatio * (0.9 + 0.45 * p);
    final y = size.height + r - p * (size.height + r * 2) * 1.15;
    canvas.drawCircle(
      Offset(size.width * xRatio, y),
      r,
      Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: 0.5 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45),
    );
  }

  @override
  bool shouldRepaint(_RiceSteamPainter old) => old.sec != sec;
}

// 키프레임 보간: [(t, value)] 리스트에서 선형 보간 (CSS keyframes 대응)
double _keyframe(double t, List<(double, double)> frames) {
  for (var i = 0; i < frames.length - 1; i++) {
    final (t0, v0) = frames[i];
    final (t1, v1) = frames[i + 1];
    if (t >= t0 && t <= t1) {
      if (t1 == t0) return v1;
      return v0 + (v1 - v0) * ((t - t0) / (t1 - t0));
    }
  }
  return frames.last.$2;
}
