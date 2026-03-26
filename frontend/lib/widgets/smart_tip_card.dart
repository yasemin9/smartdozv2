// SmartDoz - Modül 8: Akıllı İpucu Kartı Widget'ı
//
// Kullanıcıya metin tabanlı bir öneri gösterir.
// Sistem hiçbir otomatik eylem yapmaz; tüm kontrol kullanıcıdadır.
//
// Kullanım:
//   SmartTipCard(tip: smartTip)

import 'package:flutter/material.dart';

import '../models/smart_tip.dart';

/// Kart rengini ve aksanını [SmartTip.tipId]'e göre belirler.
class _TipTheme {
  final Color cardColor;
  final Color accentColor;
  final Color iconBgColor;

  const _TipTheme({
    required this.cardColor,
    required this.accentColor,
    required this.iconBgColor,
  });
}

_TipTheme _themeFor(SmartTip tip) {
  if (tip.isPositive) {
    return const _TipTheme(
      cardColor:   Color(0xFFF1F8E9),
      accentColor: Color(0xFF388E3C),
      iconBgColor: Color(0xFFC8E6C9),
    );
  }
  if (tip.isUrgent) {
    return const _TipTheme(
      cardColor:   Color(0xFFFFEBEE),
      accentColor: Color(0xFFC62828),
      iconBgColor: Color(0xFFFFCDD2),
    );
  }
  switch (tip.tipId) {
    case 'UYKU':
      return const _TipTheme(
        cardColor:   Color(0xFFEDE7F6),
        accentColor: Color(0xFF5E35B1),
        iconBgColor: Color(0xFFD1C4E9),
      );
    case 'UNUTMA':
      return const _TipTheme(
        cardColor:   Color(0xFFE3F2FD),
        accentColor: Color(0xFF1565C0),
        iconBgColor: Color(0xFFBBDEFB),
      );
    case 'LOJISTIK':
      return const _TipTheme(
        cardColor:   Color(0xFFFFF8E1),
        accentColor: Color(0xFFF57F17),
        iconBgColor: Color(0xFFFFECB3),
      );
    case 'STOK':
      return const _TipTheme(
        cardColor:   Color(0xFFE8F5E9),
        accentColor: Color(0xFF2E7D32),
        iconBgColor: Color(0xFFC8E6C9),
      );
    case 'DUSUK_UYUM':
      return const _TipTheme(
        cardColor:   Color(0xFFFCE4EC),
        accentColor: Color(0xFFAD1457),
        iconBgColor: Color(0xFFF8BBD0),
      );
    default: // ISTEKSIZLIK ve bilinmeyenler
      return const _TipTheme(
        cardColor:   Color(0xFFF3E5F5),
        accentColor: Color(0xFF7B1FA2),
        iconBgColor: Color(0xFFE1BEE7),
      );
  }
}

/// Metin tabanlı akıllı ipucu kartı.
///
/// Sistem yalnızca bir "Akıl Hocası" gibi davranır;
/// hiçbir otomatik eylem tetiklemez.
class SmartTipCard extends StatefulWidget {
  final SmartTip tip;

  const SmartTipCard({super.key, required this.tip});

  @override
  State<SmartTipCard> createState() => _SmartTipCardState();
}

class _SmartTipCardState extends State<SmartTipCard> {
  bool _showXai = false;

  @override
  Widget build(BuildContext context) {
    final t = _themeFor(widget.tip);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: t.accentColor.withValues(alpha: 0.3), width: 1),
      ),
      color: t.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Başlık satırı ─────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // İkon balonu
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: t.iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      widget.tip.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tip.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: t.accentColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Tip türü etiketi
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: t.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.tip.isReasonBased
                              ? 'Sebep Bazlı Öneri'
                              : 'Uyum Bazlı Öneri',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: t.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Öneri metni ──────────────────────────
            Text(
              widget.tip.message,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),

            // ── XAI aç/kapat ─────────────────────────
            GestureDetector(
              onTap: () => setState(() => _showXai = !_showXai),
              child: Row(
                children: [
                  Icon(
                    _showXai
                        ? Icons.expand_less_rounded
                        : Icons.info_outline_rounded,
                    size: 16,
                    color: t.accentColor.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showXai ? 'Gerekçeyi gizle' : 'Neden bu öneri?',
                    style: TextStyle(
                      fontSize: 12,
                      color: t.accentColor.withValues(alpha: 0.85),
                      decoration: TextDecoration.underline,
                      decorationColor: t.accentColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (_showXai) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: t.accentColor.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.psychology_outlined,
                        size: 14, color: t.accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.tip.xaiReason,
                        style: TextStyle(
                          fontSize: 12,
                          color: t.accentColor.withValues(alpha: 0.9),
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
