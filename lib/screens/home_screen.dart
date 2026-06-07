// home_screen.dart — P1 임시 홈(로그인 확인용). P2~에서 지도/상세/등록으로 대체.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('누룽지도 (네이티브 WIP)'),
        backgroundColor: const Color(0xFFFAC710),
        foregroundColor: const Color(0xFF4E342E),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅ 로그인 성공',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(user?.email ?? user?.displayName ?? user?.uid ?? '-'),
            const SizedBox(height: 28),
            ElevatedButton(onPressed: _signOut, child: const Text('로그아웃')),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                '다음 단계(P2~): 카카오 지도 · 동호회/픽업 상세 · 등록을 네이티브로 이식',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
