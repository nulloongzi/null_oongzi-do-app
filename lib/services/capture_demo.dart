// capture_demo.dart — 마케팅 캡처 시연(kCaptureMode) 공용 도우미.
//
// 시연은 시스템 사진 선택기를 조종할 수 없다(앱 밖 UI). 홍보 영상에 넣을 화면도
// 아니라 번들 이미지를 대신 쓴다 — 업로드와 요청 문서 생성은 실제 그대로다.
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show TextEditingController, VoidCallback;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 번들 이미지를 임시 파일로 꺼내 사진 선택 결과처럼 돌려준다. 실패하면 null.
Future<XFile?> captureDemoPhoto(String name) async {
  try {
    const asset = 'assets/markers/marker_yellow.png';
    final data = await rootBundle.load(asset);
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return XFile(f.path, name: name);
  } catch (_) {
    return null;
  }
}

/// 칸에 글자를 한 자씩 쳐 넣는다 — 영상에서 '입력하는' 모습이 보이게.
/// 다 치면 [onDone]. 돌려받은 타이머를 cancel 하면 중간에 멈춘다.
Timer demoType(
  TextEditingController c,
  String text, {
  VoidCallback? onChanged,
  VoidCallback? onDone,
  Duration every = const Duration(milliseconds: 70),
}) {
  c.text = '';
  var i = 0;
  return Timer.periodic(every, (t) {
    i++;
    c.text = text.substring(0, i);
    onChanged?.call();
    if (i >= text.length) {
      t.cancel();
      onDone?.call();
    }
  });
}
