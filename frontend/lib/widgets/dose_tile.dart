/// SmartDoz - Doz Tile Widget
///
/// Renk kodlaması:
///   Alındı    → yeşil
///   Atlandı   → kırmızı
///   Ertelendi → turuncu
///   Bekliyor + zamanı geçmiş → kırmızı kenarlık + uyarı ikonu
///   Bekliyor + yaklaşıyor   → mavi kenarlık
///   Bekliyor + normal       → gri
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/dose_log.dart';

class DoseTile extends StatelessWidget {
  final DoseLog log;
  final VoidCallback? onTaken;
  final VoidCallback? onMissed;
  /// Erteleme callback'i: seçilen dakika sayısıyla (5/10/15) çağrılır.
  /// Hem 'Bekliyor' hem 'Ertelendi' durumunda sunulur.
  final Function(int minutes)? onSnooze;

  const DoseTile({
    super.key,
    required this.log,
    this.onTaken,
    this.onMissed,
    this.onSnooze,
  });

  // ────────────────────────────────────────────────────
  // Renk & İkon yardımcıları
  // ────────────────────────────────────────────────────

  Color get _statusColor {
    if (log.isTaken)     return const Color(0xFF2E7D32);
    if (log.isMissed)    return const Color(0xFFC62828);
    if (log.isPostponed) return const Color(0xFFE65100);
    if (log.isPlanned)   return const Color(0xFF1565C0);
    if (log.isOverdue)   return const Color(0xFFB71C1C);
    if (log.isUpcoming)  return const Color(0xFF1565C0);
    return const Color(0xFF546E7A);
  }

  Color get _bgColor {
    if (log.isTaken)     return const Color(0xFFE8F5E9);
    if (log.isMissed)    return const Color(0xFFFFEBEE);
    if (log.isPostponed) return const Color(0xFFFFF3E0);
    if (log.isPlanned)   return const Color(0xFFE3F2FD);
    if (log.isOverdue)   return const Color(0xFFFFF8F8);
    if (log.isUpcoming)  return const Color(0xFFE3F2FD);
    return const Color(0xFFF5F5F5);
  }

  IconData get _statusIcon {
    if (log.isTaken)     return Icons.check_circle_rounded;
    if (log.isMissed)    return Icons.cancel_rounded;
    if (log.isPostponed) return Icons.schedule_rounded;
    if (log.isPlanned)   return Icons.event_note_rounded;
    if (log.isOverdue)   return Icons.warning_amber_rounded;
    if (log.isUpcoming)  return Icons.notifications_active_rounded;
    return Icons.radio_button_unchecked_rounded;
  }

  String get _statusLabel {
    if (log.isTaken)     return 'Alındı';
    if (log.isMissed)    return 'Atlandı';
    if (log.isPostponed) return 'Ertelendi';
    if (log.isPlanned)   return 'Planlandı';
    if (log.isOverdue)   return 'Gecikmiş';
    if (log.isUpcoming)  return 'Yaklaşıyor';
    return 'Bekliyor';
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(log.scheduledTime);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: log.isOverdue || log.isUpcoming ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _statusColor.withOpacity(0.4), width: 1.2),
      ),
      color: _bgColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Üst satır: ikon + ilaç adı + durum rozeti
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _statusColor.withOpacity(0.15),
                  child: Icon(_statusIcon, color: _statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.medicationName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        log.dosageForm,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Durum rozeti
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: _statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Planlanan saat
            Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Planlanan: $timeStr',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                if (log.actualTime != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.done_all_rounded,
                      size: 14, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Alındı: ${DateFormat('HH:mm').format(log.actualTime!)}',
                    style:
                        TextStyle(fontSize: 13, color: Colors.green[700]),
                  ),
                ],
              ],
            ),

            // ── Not
            if (log.notes != null && log.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '📝 ${log.notes}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],

            // ── Gelecek günlerdeki sanal plan
            if (log.isPlanned) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_clock_rounded,
                        size: 16, color: Color(0xFF1565C0)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Henüz Vakti Gelmedi',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Aldım'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Atladım'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: null,
                    icon: const Icon(Icons.snooze_rounded, size: 18),
                    tooltip: 'Ertele',
                  ),
                ],
              ),
            ],

            // ── Eylem butonları: Bekliyor durumunda tam set
            if (log.isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onTaken,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Aldım'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMissed,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Atladım'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                        side: const BorderSide(color: Color(0xFFC62828)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: onSnooze != null
                        ? () => _showSnoozeSheet(context)
                        : null,
                    icon: const Icon(Icons.snooze_rounded, size: 18),
                    tooltip: 'Ertele',
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFFE65100),
                      side: const BorderSide(color: Color(0xFFE65100)),
                    ),
                  ),
                ],
              ),
            ],

            // ── Ertelendi: "Şimdi Al" + "Tekrar Ertele" + "Atla"
            if (log.isPostponed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onTaken,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Şimdi Al'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMissed,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Atla'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                        side: const BorderSide(color: Color(0xFFC62828)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: onSnooze != null
                        ? () => _showSnoozeSheet(context)
                        : null,
                    icon: const Icon(Icons.snooze_rounded, size: 18),
                    tooltip: 'Tekrar Ertele',
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFFE65100),
                      side: const BorderSide(color: Color(0xFFE65100)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 5 / 10 / 15 dk seçeneklerini sunan snooze Bottom Sheet.
  void _showSnoozeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SnoozeBottomSheet(
        medicationName: log.medicationName,
        onSelected: (minutes) {
          Navigator.of(ctx).pop();
          onSnooze?.call(minutes);
        },
      ),
    );
  }
}

// ── Snooze Bottom Sheet widget (paylaşımlı) ───────────────────────────
class _SnoozeBottomSheet extends StatelessWidget {
  final String medicationName;
  final void Function(int minutes) onSelected;

  const _SnoozeBottomSheet({
    required this.medicationName,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kavrama çubuğu
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Başlık
            Row(
              children: [
                const Icon(Icons.snooze_rounded,
                    color: Color(0xFFE65100), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ne kadar erteleyelim?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D1B2A),
                        ),
                      ),
                      Text(
                        medicationName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF455A64),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Seçenek butonları
            Row(
              children: [5, 10, 15].map((m) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _SnoozeOption(
                      minutes: m,
                      onTap: () => onSelected(m),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnoozeOption extends StatelessWidget {
  final int minutes;
  final VoidCallback onTap;

  const _SnoozeOption({required this.minutes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFE65100).withOpacity(0.4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time_rounded,
                color: Color(0xFFE65100), size: 22),
            const SizedBox(height: 6),
            Text(
              '$minutes dk',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFFE65100),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
