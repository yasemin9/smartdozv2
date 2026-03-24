// SmartDoz - Günlük Doz Takip Ekranı
//
// Seçilen güne ait doz loglarını listeler.
// Her doz için Aldım / Atladım / Ertele aksiyonları sunulur.
// Bildirimler dashboard_tab.dart tarafından merkezi olarak yönetilir.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/dose_log.dart';
import '../services/api_service.dart';
import '../widgets/dose_tile.dart';

class DailyDosesScreen extends StatefulWidget {
  final DateTime date;

  const DailyDosesScreen({super.key, required this.date});

  @override
  State<DailyDosesScreen> createState() => _DailyDosesScreenState();
}

class _DailyDosesScreenState extends State<DailyDosesScreen> {
  late Future<List<DoseLog>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadLogs() {
    _logsFuture = context
        .read<ApiService>()
        .getDailyDoseLogs(widget.date);
  }

  Future<void> _updateStatus(DoseLog log, String newStatus) async {
    try {
      await context.read<ApiService>().updateDoseStatus(log.id, newStatus);
      if (mounted) setState(_loadLogs);
    } on ApiException catch (e) {
      _showError(e.message);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(widget.date);
    final isToday = _isSameDay(widget.date, DateTime.now());
    // Gelecek tarihler için aksiyonlar kapatılır
    final today = DateTime.now();
    final isFuture = widget.date.isAfter(DateTime(today.year, today.month, today.day));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isToday ? 'Bugünün Dozları' : 'Doz Programı',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              dateLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: () => setState(_loadLogs),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_loadLogs),
        child: FutureBuilder<List<DoseLog>>(
          future: _logsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorPlaceholder(
                message: snapshot.error.toString(),
                onRetry: () => setState(_loadLogs),
              );
            }

            final logs = snapshot.data ?? [];
            if (logs.isEmpty) {
              return _EmptyDayView(date: widget.date);
            }

            // Özetle beraber listele
            return Column(
              children: [
                if (isFuture)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFFFF3E0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFFE65100), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Gelecek tarihler için işaretleme yapılamaz.',
                            style: TextStyle(
                              color: Color(0xFFE65100),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                _DaySummaryBar(logs: logs),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 32),
                    itemCount: logs.length,
                    itemBuilder: (ctx, i) {
                      final log = logs[i];
                      return DoseTile(
                        log: log,
                        // Gelecek tarihse tüm aksiyonlar null → butonlar pasif
                        // Bekliyor: tam set; Ertelendi: Alındı + Atlandı
                        onTaken: (!isFuture && (log.isPending || log.isPostponed))
                            ? () => _updateStatus(log, 'Alındı')
                            : null,
                        onMissed: (!isFuture && (log.isPending || log.isPostponed))
                            ? () => _updateStatus(log, 'Atlandı')
                            : null,
                        onPostponed: (!isFuture && log.isPending)
                            ? () => _updateStatus(log, 'Ertelendi')
                            : null,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ────────────────────────────────────────────────────
// Özet Bar
// ────────────────────────────────────────────────────
class _DaySummaryBar extends StatelessWidget {
  final List<DoseLog> logs;
  const _DaySummaryBar({required this.logs});

  @override
  Widget build(BuildContext context) {
    final taken = logs.where((l) => l.isTaken).length;
    final missed = logs.where((l) => l.isMissed).length;
    final pending = logs.where((l) => l.isPending).length;
    final total = logs.length;
    final rate = total > 0 ? (taken / total * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(label: 'Alındı', count: taken, color: const Color(0xFF2E7D32)),
          _StatChip(label: 'Atlandı', count: missed, color: const Color(0xFFC62828)),
          _StatChip(label: 'Bekliyor', count: pending, color: const Color(0xFF1565C0)),
          _StatChip(
            label: 'Uyum',
            count: rate,
            suffix: '%',
            color: rate >= 80
                ? const Color(0xFF2E7D32)
                : rate >= 50
                    ? const Color(0xFFE65100)
                    : const Color(0xFFC62828),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final String suffix;
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            '$count$suffix',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      );
}

// ────────────────────────────────────────────────────
// Boş gün placeholder
// ────────────────────────────────────────────────────
class _EmptyDayView extends StatelessWidget {
  final DateTime date;
  const _EmptyDayView({required this.date});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_rounded, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              DateFormat('d MMMM', 'tr_TR').format(date),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu gün için planlanmış doz bulunmuyor.',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
}

// ────────────────────────────────────────────────────
// Hata placeholder
// ────────────────────────────────────────────────────
class _ErrorPlaceholder extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorPlaceholder({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
}
