// SmartDoz - Modül 8: YZ Karar Bildirim Kartı
//
// Kullanıcıya bir YZ müdahale önerisini gösterir.
// XAI açıklaması, karar tipine özel ikon/renk ve Kapat düğmesi içerir.
//
// Kullanım:
//   DecisionNotificationCard(
//     decision: aiDecision,
//     onDismiss: () async { ... },
//   )

import 'package:flutter/material.dart';

import '../models/ai_decision.dart';

/// Karar tipine göre renk / ikon / başlık rengi meta verisi.
class _DecisionMeta {
  final Color cardColor;
  final Color accentColor;
  final IconData icon;

  const _DecisionMeta({
    required this.cardColor,
    required this.accentColor,
    required this.icon,
  });
}

_DecisionMeta _metaFor(String decisionType, {Map<String, dynamic>? payload}) {
  // TONE_ADAPT + alarm_boost modu → farklı renk/ikon
  if (decisionType == 'TONE_ADAPT' && payload?['mode'] == 'alarm_boost') {
    return const _DecisionMeta(
      cardColor:   Color(0xFFFCE4EC),
      accentColor: Color(0xFFAD1457),
      icon:        Icons.notifications_active_rounded,
    );
  }
  switch (decisionType) {
    case 'SCHEDULE_SHIFT':
      return const _DecisionMeta(
        cardColor:   Color(0xFFE8F4FD),
        accentColor: Color(0xFF1976D2),
        icon:        Icons.schedule_rounded,
      );
    case 'TONE_ADAPT':
      return const _DecisionMeta(
        cardColor:   Color(0xFFF3E5F5),
        accentColor: Color(0xFF7B1FA2),
        icon:        Icons.volume_up_rounded,
      );
    case 'DOCTOR_REFERRAL':
      return const _DecisionMeta(
        cardColor:   Color(0xFFFFEBEE),
        accentColor: Color(0xFFC62828),
        icon:        Icons.local_hospital_rounded,
      );
    case 'GAMIFICATION':
      return const _DecisionMeta(
        cardColor:   Color(0xFFFFF8E1),
        accentColor: Color(0xFFF57F17),
        icon:        Icons.emoji_events_rounded,
      );
    case 'LOGISTIC_REMINDER':
      return const _DecisionMeta(
        cardColor:   Color(0xFFE8F5E9),
        accentColor: Color(0xFF2E7D32),
        icon:        Icons.inventory_2_rounded,
      );
    default:
      return const _DecisionMeta(
        cardColor:   Color(0xFFEEF2FF),
        accentColor: Color(0xFF3949AB),
        icon:        Icons.smart_toy_rounded,
      );
  }
}

/// PENDING kararlar için salt okunur bilgi kartı.
/// Sistem yalnızca öneri sunar; tüm kararlar kullanıcıya aittir.
/// [onDismiss] çağrıldığında karar arşive (REJECTED) taşınır.
class DecisionNotificationCard extends StatefulWidget {
  final AIDecision decision;
  final Future<void> Function() onDismiss;

  const DecisionNotificationCard({
    super.key,
    required this.decision,
    required this.onDismiss,
  });

  @override
  State<DecisionNotificationCard> createState() =>
      _DecisionNotificationCardState();
}

class _DecisionNotificationCardState
    extends State<DecisionNotificationCard> {
  bool _dismissing = false;

  Future<void> _handleDismiss() async {
    if (_dismissing) return;
    setState(() => _dismissing = true);
    try {
      await widget.onDismiss();
    } finally {
      if (mounted) setState(() => _dismissing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d    = widget.decision;
    final meta = _metaFor(d.decisionType, payload: d.payload);
    final bool isClinical = d.decisionType == 'DOCTOR_REFERRAL';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: meta.cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Başlık satırı ──────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: meta.accentColor.withValues(alpha: 0.15),
                  child: Icon(meta.icon, color: meta.accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.typeLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: meta.accentColor,
                        ),
                      ),
                      if (d.medicationName != null)
                        Text(
                          '${d.medicationName} · ${d.windowLabel}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                // YZ rozeti + Kapat butonu
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: meta.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smart_toy_rounded,
                              size: 10, color: meta.accentColor),
                          const SizedBox(width: 3),
                          Text(
                            'SmartDoz AI',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: meta.accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: _dismissing
                          ? Padding(
                              padding: const EdgeInsets.all(6),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black38),
                            )
                          : IconButton(
                              padding: EdgeInsets.zero,
                              tooltip: 'Kapat',
                              icon: const Icon(Icons.close_rounded,
                                  size: 18, color: Colors.black38),
                              onPressed: _handleDismiss,
                            ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── XAI Açıklaması ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                d.explanation,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),

            // SCHEDULE_SHIFT için delta bilgisi
            if (d.decisionType == 'SCHEDULE_SHIFT' &&
                d.payload != null &&
                d.payload!['delta_minutes'] != null) ...[
              const SizedBox(height: 8),
              _InfoChip(
                icon: Icons.update_rounded,
                label:
                    'Önerilen kaydırma: +${d.payload!['delta_minutes']} dakika',
                color: meta.accentColor,
              ),
            ],

            // DOCTOR_REFERRAL — ek uyarı
            if (isClinical) ...[
              const SizedBox(height: 8),
              const _InfoChip(
                icon: Icons.warning_amber_rounded,
                label: 'Klinik risk: saat değişikliği yapılmıyor',
                color: Color(0xFFC62828),
              ),
            ],

            // ── Sadece Öneri Etiketi ──────────────────────────
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 13, color: Colors.black38),
                const SizedBox(width: 4),
                const Text(
                  'Bu bir öneridir — tüm kararlar size aittir.',
                  style: TextStyle(fontSize: 11, color: Colors.black38),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Çözümlenmiş (APPROVED/REJECTED/EXPIRED) kararlar için salt okunur kart.
class DecisionHistoryCard extends StatelessWidget {
  final AIDecision decision;

  const DecisionHistoryCard({super.key, required this.decision});

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(decision.decisionType, payload: decision.payload);

    final (statusLabel, statusColor, statusIcon) = switch (decision.status) {
      'APPROVED' => ('Onaylandı', Colors.green.shade700, Icons.check_circle_rounded),
      'REJECTED' => ('Reddedildi', Colors.grey.shade600, Icons.cancel_rounded),
      'EXPIRED'  => ('Süresi Doldu', Colors.orange.shade700, Icons.timer_off_rounded),
      _          => ('Bilinmiyor', Colors.grey, Icons.help_outline_rounded),
    };

    final (outcomeLabel, outcomeColor) = switch (decision.outcome) {
      'SUCCESS' => ('✅ Başarılı Strateji', Colors.green.shade700),
      'FAILURE' => ('❌ Yeniden Değerlendiriliyor', Colors.orange.shade700),
      _         => (null, Colors.transparent),
    };

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey.shade50,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: meta.accentColor.withValues(alpha: 0.1),
          child: Icon(meta.icon, color: meta.accentColor, size: 18),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                decision.typeLabel,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            Icon(statusIcon, size: 14, color: statusColor),
            const SizedBox(width: 4),
            Text(
              statusLabel,
              style: TextStyle(
                fontSize: 11,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              decision.explanation,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            if (outcomeLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                outcomeLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: outcomeColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Yardımcı widget
// ──────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
}
