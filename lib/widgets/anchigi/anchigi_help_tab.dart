// anchigi_help_tab.dart — 설명 탭. 원본 HELP_HTML을 위젯으로 옮김.
import 'package:flutter/material.dart';

import '../../services/i18n.dart';
import '../../theme.dart';
import 'anchigi_common.dart';

class AnchigiHelpTab extends StatelessWidget {
  const AnchigiHelpTab({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
    children: [
      AgCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _h(t('ag_help_h1')),
            _li(t('ag_help_1a')),
            _li(t('ag_help_1b')),
            _li(t('ag_help_1c')),
            _li(t('ag_help_1d')),
            _li(t('ag_help_1e')),
          ],
        ),
      ),
      AgCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _h(t('ag_help_h2')),
            _p(t('ag_help_2intro')),
            const SizedBox(height: 8),
            _li(t('ag_help_2a')),
            _li(t('ag_help_2b')),
            _li(t('ag_help_2c')),
            _li(t('ag_help_2d')),
            _li(t('ag_help_2e')),
          ],
        ),
      ),
      AgCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _h(t('ag_help_h3')),
            _qa(t('ag_help_q1'), t('ag_help_a1')),
            _qa(t('ag_help_q2'), t('ag_help_a2')),
            _qa(t('ag_help_q3'), t('ag_help_a3')),
            _qa(t('ag_help_q4'), t('ag_help_a4')),
          ],
        ),
      ),
    ],
  );

  Widget _h(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      s,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: NurungjiColors.dark,
      ),
    ),
  );

  Widget _p(String s) => Text(
    s,
    style: const TextStyle(
      fontSize: 13,
      height: 1.6,
      fontWeight: FontWeight.w600,
      color: NurungjiColors.chipFg,
    ),
  );

  Widget _li(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6, right: 8),
          child: Icon(Icons.circle, size: 5, color: NurungjiColors.brown),
        ),
        Expanded(child: _p(s)),
      ],
    ),
  );

  Widget _qa(String q, String a) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          q,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.w800,
            color: NurungjiColors.dark,
          ),
        ),
        const SizedBox(height: 4),
        _p(a),
      ],
    ),
  );
}
