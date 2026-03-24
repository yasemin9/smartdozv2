/// SmartDoz - İlaç Kartı Widget'ı
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medication.dart';

class MedicationCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback? onDelete;

  const MedicationCard({
    super.key,
    required this.medication,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpired = medication.isExpired;
    final expiryColor = isExpired ? Colors.red.shade700 : Colors.green.shade700;
    final expiryBg =
        isExpired ? Colors.red.shade50 : Colors.green.shade50;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isExpired
            ? BorderSide(color: Colors.red.shade200)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── İkon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _dosageIcon(medication.dosageForm),
                color: colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),

            // ── Bilgiler
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // İlaç adı
                  Text(
                    medication.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Dozaj formu chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      medication.dosageForm,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Kullanım bilgileri
                  _InfoRow(
                    icon: Icons.schedule_rounded,
                    text: medication.usageFrequency,
                  ),
                  const SizedBox(height: 4),
                  _InfoRow(
                    icon: Icons.access_time_rounded,
                    text: medication.usageTime,
                  ),
                  const SizedBox(height: 8),

                  // Son kullanma tarihi
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: expiryBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isExpired
                              ? Icons.warning_amber_rounded
                              : Icons.event_available_rounded,
                          size: 14,
                          color: expiryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'SKT: ${DateFormat('dd.MM.yyyy').format(medication.expiryDate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: expiryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isExpired) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(Süresi dolmuş)',
                            style:
                                TextStyle(fontSize: 11, color: expiryColor),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Sil butonu
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              color: Colors.red.shade400,
              tooltip: 'İlacı Sil',
            ),
          ],
        ),
      ),
    );
  }

  IconData _dosageIcon(String form) {
    final lower = form.toLowerCase();
    if (lower.contains('tablet') || lower.contains('hap')) {
      return Icons.circle_outlined;
    }
    if (lower.contains('şurup') || lower.contains('sıvı')) {
      return Icons.local_drink_outlined;
    }
    if (lower.contains('kapsül')) return Icons.medication_rounded;
    if (lower.contains('enjeksiyon')) return Icons.vaccines_rounded;
    if (lower.contains('damla')) return Icons.water_drop_outlined;
    if (lower.contains('krem') || lower.contains('merhem')) {
      return Icons.sanitizer_outlined;
    }
    return Icons.medication_rounded;
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}
