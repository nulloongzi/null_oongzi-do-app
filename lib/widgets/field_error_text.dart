// field_error_text.dart — 칸이 아닌 묶음(칩·릴스 목록·사진)의 입력 오류를 묶음 아래에 한 줄로.
// TextField 는 InputDecoration.errorText 가 같은 모양(theme.dart fieldErrorStyle)으로 그린다.
// 웹 js/field-error.js(.field-error)와 같은 규칙: 무엇이 + 어떻게, 화면 낭독기가 바로 읽는다.
import 'package:flutter/material.dart';
import '../theme.dart';

class FieldErrorText extends StatelessWidget {
  final String message;
  const FieldErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Semantics(
        liveRegion: true,
        child: Text(message, style: fieldErrorStyle),
      ),
    );
  }
}
