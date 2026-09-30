# 누룽지도 디자인 시스템 → 웹 저장소로

**원본은 하나다: 웹 저장소 [`docs/design-system.md`](https://github.com/nulloongzi/null_oongzi-do/blob/main/docs/design-system.md).**
이 파일은 안내만 둔다. 앱 코드·문서가 `docs/design-system.md §N` 을 가리키면 그 원본의 같은 절이다.

- 여기에 규칙을 적지 않는다. 두 벌로 두었더니 7-2·7-4 가 서로 달라졌다(2026-09).
- 색·그림자·모서리 숫자는 웹 저장소 `tokens/design-tokens.json` 이 원본이고, 이 저장소
  `lib/design_tokens.g.dart` 는 거기서 생성한 파일이다(손으로 고치지 않는다, `theme.dart` 가 export).
  다시 만들기: 웹 저장소에서 `npm run tokens -- --dart ../null_oongzi-do-app/lib/design_tokens.g.dart`.
  어긋나면 `.github/workflows/design-tokens.yml` 이 실패한다. 자세한 순서는 원본 §0.

| 절 | 내용 |
|---|---|
| §0 | 토큰 파일과 생성·검사 |
| §1 | 컬러 팔레트 |
| §2 | 타이포그래피 (Pretendard 하나, 앱은 `assets/fonts/PretendardVariable.ttf` 번들) |
| §3 · §3-1 | 형태 규칙 · 지도 화면 부품(시트·핸들·딤·FAB·탭) 공통 값 |
| §4 | 보이스 & 톤 |
| §5 · §6 | 마케팅 에셋 규격 · 제작 원칙 |
| §7 | 공유 카드 (7-1 규격 · 7-2 탄력 배치 · 7-3 토큰 · 7-4 내 카드 · 7-5 합석 단계) |
