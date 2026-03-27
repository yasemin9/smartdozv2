/// SmartDoz - Dashboard Sekmesi (Modül 2 Entegrasyonlu)
///
/// ─── Tasarım İlkeleri (EK1_revize.pdf s.27 — Evrensel Tasarım) ───────────
/// • Yüksek kontrast: WCAG AA (≥4.5:1) — yaşlı kullanıcı dostu
/// • Minimum dokunma hedefi: 48 × 48 dp
/// • Büyük ve okunaklı font boyutları
/// • Renk + ikon + metin: renk TEK gösterge değil
/// ─────────────────────────────────────────────────────────────────────────
///
/// Bölümler:
///   1. AppBar  — selamlama + bugünün tarihi
///   2. Hero Kart  — sıradaki ilaç (büyük, gradient)
///   3. Özet Şerit — Bekliyor / Alındı / Atlandı sayıları
///   4. Çizelge   — bugünün tüm dozları, kronolojik timeline

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/dose_log.dart';
import '../models/medication.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

// ── Yaşlı dostu renk paleti (WCAG AA uyumlu) ──────────────────────────
const _kBg         = Color(0xFFF0F4FF);
const _kPrimary    = Color(0xFF1565C0);   // 4.77:1 beyazda
const _kSuccess    = Color(0xFF2E7D32);   // 5.74:1 beyazda
const _kWarning    = Color(0xFFE65100);   // 4.65:1 beyazda
const _kDanger     = Color(0xFFC62828);   // 5.54:1 beyazda
const _kTextDark   = Color(0xFF0D1B2A);
const _kTextMid    = Color(0xFF455A64);

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => DashboardTabState();
}

/// Public: HomeScreen'den GlobalKey aracılığıyla refresh() çağrılabilir
class DashboardTabState extends State<DashboardTab>
    with AutomaticKeepAliveClientMixin {
  // keepAlive: IndexedStack içinde sekme değişince state korunur
  @override
  bool get wantKeepAlive => true;

  /// İlaç eklenince HomeScreen tarafından çağrılır
  void refresh() => setState(_loadDoses);

  late Future<List<DoseLog>> _dosesFuture;
  List<DoseLog> _cachedLogs = [];
  List<CriticalInteractionWarning> _criticalWarnings = const [];
  Timer? _notifTimer;

  @override
  void initState() {
    super.initState();
    _loadDoses();
    _loadCriticalWarnings();
    _startNotificationPolling();
    NotificationService.requestPermission();
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    super.dispose();
  }

  void _loadDoses() {
    _dosesFuture = context
        .read<ApiService>()
        .getDailyDoseLogs(DateTime.now())
        .then((list) {
      _cachedLogs = list;
      return list;
    });
  }

  Future<void> _loadCriticalWarnings() async {
    try {
      final warnings = await context.read<ApiService>().getCriticalInteractionWarnings();
      if (!mounted) return;
      setState(() => _criticalWarnings = warnings);
    } catch (_) {
      // Kritik uyarı endpoint'i başarısız olursa ana ekran akışını bozma.
    }
  }

  // ── Her 60 saniyede backend'den yaklaşan dozları polling ile bildir
  void _startNotificationPolling() {
    _notifTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      try {
        final pending = await context
            .read<ApiService>()
            .getPendingNotifications();
        for (final log in pending) {
          final t = DateFormat('HH:mm').format(log.scheduledTime);
          NotificationService.showDoseNotification(
            doseLogId: log.id,
            medicationName: log.medicationName,
            scheduledTime: t,
          );
        }
      } catch (_) {
        // Bildirim polling kritik değil, sessizce geç
      }
    });
  }

  // ── Sıradaki doz: gecikmiş olmayan en yakın Bekliyor/Ertelendi
  // Gecikmiş (>30dk) dozlar Hero'yu işgal etmez; _OverdueAlertBar'a taşınır (EK1_revize Mod. 8)
  DoseLog? _nextDose(List<DoseLog> logs) {
    final upcoming = logs
        .where((l) => l.isPending && !l.isOverdue)
        .toList()
          ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    if (upcoming.isNotEmpty) return upcoming.first;
    // Bekliyor/gelecek yoksa Ertelendi'yi göster (Kapalı Döngü)
    final postponed = logs
        .where((l) => l.isPostponed)
        .toList()
          ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return postponed.isEmpty ? null : postponed.first;
  }

  // ── Timeline öncelik sıralaması: yaklaşan → ertelendi → gecikmiş → alındı/atlandı
  List<DoseLog> _sortedTimeline(List<DoseLog> logs) {
    int priority(DoseLog l) {
      if (l.isPending && !l.isOverdue) return 0; // yakında/gelecek
      if (l.isPostponed)              return 1; // ertelendi
      if (l.isOverdue)                return 2; // gecikmiş
      if (l.isTaken)                  return 3; // alındı
      return 4;                                 // atlandı
    }
    return [...logs]
      ..sort((a, b) {
        final pc = priority(a).compareTo(priority(b));
        if (pc != 0) return pc;
        return a.scheduledTime.compareTo(b.scheduledTime);
      });
  }

  Future<void> _updateStatus(DoseLog log, String newStatus) async {
    try {
      await context.read<ApiService>().updateDoseStatus(log.id, newStatus);
      // Ertelendi: backend scheduled_time'i ileri taşıdı, _shownIds'ten temizleyerek
      // polling bu dozu tekrar bildirebilsin.
      if (newStatus == 'Ertelendi') {
        NotificationService.clearId(log.id);
      }
      if (mounted) setState(_loadDoses);
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    }
  }

  Future<void> _snooze(DoseLog log, int minutes) async {
    try {
      await context.read<ApiService>().snoozeDose(log.id, minutes);
      // Erteleme sonrası aynı doz için yeniden bildirim gönderilmelidir.
      NotificationService.clearId(log.id);
      if (mounted) setState(_loadDoses);
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 15)),
        backgroundColor: isError ? _kDanger : _kSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Modül 8: Sistematik Davranışsal Sapma diyaloğu (EK1_revize s.46)
  // 1 saatten uzun gecikmelerde _OverdueRow'daki "Neden?" butonu tetikler.
  void _showBehavioralDeviationDialog(BuildContext ctx, DoseLog log) {
    final delay = DateTime.now().difference(log.scheduledTime);
    final delayStr = delay.inMinutes >= 60
        ? '${delay.inHours} saat ${delay.inMinutes % 60} dk'
        : '${delay.inMinutes} dk';

    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology_rounded,
                    color: _kDanger, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Davranışsal Sapma Analizi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _kTextDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '• ${log.medicationName} — $delayStr gecikmeli',
              style: const TextStyle(fontSize: 13, color: _kTextMid),
            ),
            const SizedBox(height: 14),
            const Text(
              'Bu ilacı neden almadınız?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ReasonChip(
                  label: '🤔 Unuttum',
                  onTap: () => _handleReason(log, 'Unuttum'),
                ),
                _ReasonChip(
                  label: '⚠️ Yan etki korkusu',
                  onTap: () => _handleReason(log, 'Yan etki korkusu'),
                ),
                _ReasonChip(
                  label: '📦 İlaç bitti',
                  onTap: () => _handleReason(log, 'İlaç bitti'),
                ),
                _ReasonChip(
                  label: '🚗 Yanımda yoktu',
                  onTap: () => _handleReason(log, 'Yanımda yoktu'),
                ),
                _ReasonChip(
                  label: '😴 Uyuyordum',
                  onTap: () => _handleReason(log, 'Uyuyordum'),
                ),
                _ReasonChip(
                  label: '💬 Diğer',
                  onTap: () => _handleReason(log, 'Diğer'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _updateStatus(log, 'Alındı');
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Şimdi Aldım'),
                style: FilledButton.styleFrom(backgroundColor: _kSuccess),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReason(DoseLog log, String reason) {
    Navigator.pop(context);
    context
        .read<ApiService>()
        .updateDoseStatus(log.id, 'Atlandı', notes: reason)
        .then((_) {
      if (mounted) setState(_loadDoses);
    }).catchError((_) {});
  }

  // ══════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = context.watch<ApiService>().currentUser;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(user?.firstName ?? ''),
      body: RefreshIndicator(
        color: _kPrimary,
        onRefresh: () async {
          setState(_loadDoses);
          await _loadCriticalWarnings();
        },
        child: FutureBuilder<List<DoseLog>>(
          future: _dosesFuture,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                _cachedLogs.isEmpty) {
              return const _LoadingSkeleton();
            }
            if (snap.hasError && _cachedLogs.isEmpty) {
              return _ErrorView(
                message: snap.error.toString(),
                onRetry: () => setState(_loadDoses),
              );
            }

            final logs = snap.data ?? _cachedLogs;
            // Gecikmiş ilaçlar Hero'dan ayrılır → _OverdueAlertBar
            final overdueLogs = logs.where((l) => l.isOverdue).toList()
              ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
            final next = _nextDose(logs);
            final sortedLogs = _sortedTimeline(logs);

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (_criticalWarnings.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _CriticalInteractionBanner(
                      warning: _criticalWarnings.first,
                    ),
                  ),

                // ── Gecikmiş İlaç Kritik Uyarı Barı (Modül 8 — Davranışsal Sapma)
                if (overdueLogs.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _OverdueAlertBar(
                      overdueLogs: overdueLogs,
                      onTaken: (log) => _updateStatus(log, 'Alındı'),
                      onAskReason: (log) =>
                          _showBehavioralDeviationDialog(context, log),
                    ),
                  ),

                // ── Hero Kart
                SliverToBoxAdapter(
                  child: _HeroNextDoseCard(
                    nextDose: next,
                    logs: logs,
                    hasOverdue: overdueLogs.isNotEmpty,
                    onTaken: next != null
                        ? () => _updateStatus(next, 'Alındı')
                        : null,
                    onMissed: (next != null && next.isPostponed)
                        ? () => _updateStatus(next, 'Atlandı')
                        : null,
                    onSnooze: (next != null && (next.isPending || next.isPostponed))
                        ? (minutes) => _snooze(next, minutes)
                        : null,
                  ),
                ),

                // ── Özet şeridi
                SliverToBoxAdapter(
                  child: _SummaryStrip(logs: logs),
                ),

                // ── Çizelge başlığı
                if (logs.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: _ScheduleHeader(),
                  ),

                // ── Çizelge listesi (timeline)
                if (sortedLogs.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.only(
                        left: 16, right: 16, bottom: 32),
                    sliver: SliverList.separated(
                      itemCount: sortedLogs.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 0),
                      itemBuilder: (ctx, i) => _TimelineDoseCard(
                        log: sortedLogs[i],
                        isLast: i == sortedLogs.length - 1,
                        // Bekliyor: tam set; Ertelendi: Alındı + Atlandı + Tekrar Ertele
                        onTaken: (sortedLogs[i].isPending || sortedLogs[i].isPostponed)
                            ? () => _updateStatus(sortedLogs[i], 'Alındı')
                            : null,
                        onMissed: (sortedLogs[i].isPending || sortedLogs[i].isPostponed)
                            ? () => _updateStatus(sortedLogs[i], 'Atlandı')
                            : null,
                        onSnooze: (sortedLogs[i].isPending || sortedLogs[i].isPostponed)
                            ? (minutes) => _snooze(sortedLogs[i], minutes)
                            : null,
                      ),
                    ),
                  ),

                if (logs.isEmpty)
                  const SliverToBoxAdapter(child: _EmptyDayCard()),
              ],
            );
          },
        ),
      ),
    );
  }

  AppBar _buildAppBar(String name) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Günaydın'
        : now.hour < 18
            ? 'İyi Günler'
            : 'İyi Akşamlar';

    final dateLabel =
        DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(now);

    return AppBar(
      backgroundColor: _kPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting${name.isNotEmpty ? ", $name" : ""}! 👋',
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700),
          ),
          Text(
            dateLabel,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Yenile',
          onPressed: () {
            setState(_loadDoses);
            _loadCriticalWarnings();
          },
        ),
      ],
    );
  }
}

class _CriticalInteractionBanner extends StatelessWidget {
  const _CriticalInteractionBanner({required this.warning});

  final CriticalInteractionWarning warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC62828), width: 1.6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22C62828),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: _kDanger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  warning.message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8E0000),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${warning.title} • ${warning.riskLevel}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB71C1C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            warning.description,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6D1B1B),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// HERO — Sıradaki İlaç Kartı
// ══════════════════════════════════════════════════════════════════════

class _HeroNextDoseCard extends StatelessWidget {
  final DoseLog? nextDose;
  final List<DoseLog> logs;
  final bool hasOverdue;
  final VoidCallback? onTaken;
  final VoidCallback? onMissed;
  /// Snooze callback — seçilen dakika sayısıyla çağrılır (5/10/15).
  final Function(int minutes)? onSnooze;

  const _HeroNextDoseCard({
    required this.nextDose,
    required this.logs,
    required this.hasOverdue,
    this.onTaken,
    this.onMissed,
    this.onSnooze,
  });

  bool get _allTaken =>
      logs.isNotEmpty && logs.every((l) => l.isTaken || l.isMissed);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, hasOverdue ? 8 : 20, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // Ertelendi → turuncu, Bekliyor → mavi
          colors: nextDose?.isPostponed == true
              ? [const Color(0xFFE65100), const Color(0xFFBF360C)]
              : [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x401565C0),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _allTaken
            ? _buildAllDoneContent()
            : nextDose == null
                ? (hasOverdue
                    ? _buildOverdueReminder()
                    : _buildNoDoseContent())
                : _buildNextDoseContent(context),
      ),
    );
  }

  Widget _buildOverdueReminder() => const Column(
        children: [
          Text('⚠️', style: TextStyle(fontSize: 44)),
          SizedBox(height: 10),
          Text(
            'Gecikmiş İlaçlarınız Var',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Yukarıdaki kırmızı uyarı barından\nilacınızı işaretleyin.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _buildNextDoseContent(BuildContext context) {
    final log = nextDose!;
    final timeStr = DateFormat('HH:mm').format(log.scheduledTime);
    final minutesLeft = log.scheduledTime
        .difference(DateTime.now())
        .inMinutes;
    final isOverdue = minutesLeft < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık satırı
        Row(
          children: [
            const Icon(Icons.medication_rounded,
                color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(
              log.isPostponed ? 'Ertelenen İlacınız' : 'Sıradaki İlacınız',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            // Geri sayım rozeti
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOverdue
                    ? const Color(0xFFB71C1C)
                    : Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isOverdue
                    ? '${minutesLeft.abs()} dk gecikmiş'
                    : minutesLeft == 0
                        ? 'Şimdi!'
                        : '$minutesLeft dk sonra',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // İlaç adı
        Text(
          log.medicationName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),

        const SizedBox(height: 6),

        // Form + saat
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                log.dosageForm,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.access_time_rounded,
                color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Aksiyon butonları — Ertelendi ise "Şimdi Al + Atla + Tekrar Ertele", değilse "Aldım + Ertele"
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onTaken,
                icon: const Icon(Icons.check_circle_outline_rounded,
                    size: 18),
                label: const Text(
                  'Şimdi Aldım',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _kSuccess,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            if (log.isPostponed) ...[
              OutlinedButton(
                onPressed: onMissed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded, size: 20),
                    Text('Atla', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            OutlinedButton(
              onPressed: onSnooze != null
                  ? () => _showHeroSnoozeSheet(context, log)  // context from _buildNextDoseContent param
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(
                    color: Colors.white54, width: 1.5),
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.snooze_rounded, size: 20),
                  Text(
                    log.isPostponed ? 'Tekrar Ertele' : 'Ertele',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAllDoneContent() => Column(
        children: const [
          Text('🎉', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text(
            'Harika!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Bugünün tüm ilaçlarını aldınız.',
            style: TextStyle(color: Colors.white70, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            'Sağlıklı günler! 💊',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      );

  /// Hero kart için snooze bottom sheet — DoseLog importları burada mevcut.
  void _showHeroSnoozeSheet(BuildContext context, DoseLog log) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _HeroSnoozeSheet(
        medicationName: log.medicationName,
        onSelected: (minutes) {
          Navigator.of(ctx).pop();
          onSnooze?.call(minutes);
        },
      ),
    );
  }


  Widget _buildNoDoseContent() => const Column(
        children: [
          Text('💊', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text(
            'Bekleyen İlaç Yok',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Bugün için tüm dozlar tamamlandı\nveya ilaç eklenmedi.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      );
}

// ── Hero kart için snooze sheet (inline, DoseLog bağımlılığı yok) ────
class _HeroSnoozeSheet extends StatelessWidget {
  final String medicationName;
  final void Function(int minutes) onSelected;

  const _HeroSnoozeSheet({
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
            Row(
              children: [
                const Icon(Icons.snooze_rounded,
                    color: _kWarning, size: 24),
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
                          color: _kTextDark,
                        ),
                      ),
                      Text(
                        medicationName,
                        style: const TextStyle(
                            fontSize: 13, color: _kTextMid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [5, 10, 15].map((m) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _SnoozeChip(
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

class _SnoozeChip extends StatelessWidget {
  final int minutes;
  final VoidCallback onTap;

  const _SnoozeChip({required this.minutes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: _kWarning.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kWarning.withOpacity(0.40)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time_rounded,
                color: _kWarning, size: 22),
            const SizedBox(height: 6),
            Text(
              '$minutes dk',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _kWarning,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// ÖZET ŞERİDİ — 3 istatistik chip
// ══════════════════════════════════════════════════════════════════════

class _SummaryStrip extends StatelessWidget {
  final List<DoseLog> logs;
  const _SummaryStrip({required this.logs});

  @override
  Widget build(BuildContext context) {
    final taken     = logs.where((l) => l.isTaken).length;
    final pending   = logs.where((l) => l.isPending).length;
    final missed    = logs.where((l) => l.isMissed).length;
    final postponed = logs.where((l) => l.isPostponed).length;
    final total     = logs.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _StatCard(
            value: '$taken',
            label: 'Alındı',
            icon: Icons.check_circle_rounded,
            color: _kSuccess,
          ),
          const SizedBox(width: 10),
          _StatCard(
            value: '$pending',
            label: 'Bekliyor',
            icon: Icons.radio_button_unchecked_rounded,
            color: _kPrimary,
          ),
          const SizedBox(width: 10),
          _StatCard(
            value: '$missed',
            label: 'Atlandı',
            icon: Icons.cancel_rounded,
            color: _kDanger,
          ),
          if (postponed > 0) ...[
            const SizedBox(width: 10),
            _StatCard(
              value: '$postponed',
              label: 'Ertelendi',
              icon: Icons.schedule_rounded,
              color: _kWarning,
            ),
          ],
          const Spacer(),
          // Uyum oranı
          if (total > 0)
            _ComplianceRing(
              rate: taken / total,
              total: total,
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style:
                  TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
            ),
          ],
        ),
      );
}

class _ComplianceRing extends StatelessWidget {
  final double rate; // 0.0 – 1.0
  final int total;
  const _ComplianceRing({required this.rate, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct  = (rate * 100).round();
    final color = rate >= 0.8
        ? _kSuccess
        : rate >= 0.5
            ? _kWarning
            : _kDanger;

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: rate,
            strokeWidth: 5,
            backgroundColor: Colors.grey.shade200,
            color: color,
          ),
          Text(
            '$pct%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// ÇIZELGE BAŞLIĞI
// ══════════════════════════════════════════════════════════════════════

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Row(
          children: [
            const Icon(Icons.format_list_bulleted_rounded,
                size: 18, color: _kTextMid),
            const SizedBox(width: 8),
            const Text(
              'Bugünün Çizelgesi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _kTextDark,
              ),
            ),
            const Spacer(),
            Text(
              DateFormat('d MMMM', 'tr_TR').format(DateTime.now()),
              style: const TextStyle(fontSize: 13, color: _kTextMid),
            ),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════
// TIMELINE DOZ KARTI
// ══════════════════════════════════════════════════════════════════════

class _TimelineDoseCard extends StatelessWidget {
  final DoseLog log;
  final bool isLast;
  final VoidCallback? onTaken;
  final VoidCallback? onMissed;
  final Function(int minutes)? onSnooze;

  const _TimelineDoseCard({
    required this.log,
    required this.isLast,
    this.onTaken,
    this.onMissed,
    this.onSnooze,
  });

  Color get _dotColor {
    if (log.isTaken)     return _kSuccess;
    if (log.isMissed)    return _kDanger;
    if (log.isPostponed) return _kWarning;
    if (log.isOverdue)   return _kDanger;
    if (log.isUpcoming)  return _kPrimary;
    return Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(log.scheduledTime);

    return Dismissible(
      // Swipe sağa → Alındı; sadece Bekliyor durumunda aktif
      key: ValueKey('dose_${log.id}'),
      direction: log.isPending
          ? DismissDirection.startToEnd
          : DismissDirection.none,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: _kSuccess,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Text(
              'Alındı!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onTaken?.call();
        return false; // Dismiss animasyonu bitmeden API günceller
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Timeline şeridi (sol)
            SizedBox(
              width: 52,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _dotColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Nokta
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _dotColor,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _dotColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  // Dikey çizgi (son eleman değilse)
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: Colors.grey.shade200,
                        margin:
                            const EdgeInsets.symmetric(vertical: 4),
                      ),
                    )
                  else
                    const SizedBox(height: 24),
                ],
              ),
            ),

            // ── Doz içerik kartı (sağ)
            Expanded(
              child: _DoseContentCard(
                log: log,
                onTaken: onTaken,
                onMissed: onMissed,
                onSnooze: onSnooze,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoseContentCard extends StatelessWidget {
  final DoseLog log;
  final VoidCallback? onTaken;
  final VoidCallback? onMissed;
  final Function(int minutes)? onSnooze;

  const _DoseContentCard({
    required this.log,
    this.onTaken,
    this.onMissed,
    this.onSnooze,
  });

  Color get _cardBg {
    if (log.isTaken)     return const Color(0xFFE8F5E9);
    if (log.isMissed)    return const Color(0xFFFFEBEE);
    if (log.isPostponed) return const Color(0xFFFFF3E0);
    if (log.isOverdue)   return const Color(0xFFFFF0F0);
    return Colors.white;
  }

  Color get _accentColor {
    if (log.isTaken)     return _kSuccess;
    if (log.isMissed)    return _kDanger;
    if (log.isPostponed) return _kWarning;
    if (log.isOverdue)   return _kDanger;
    return _kPrimary;
  }

  String get _statusLabel {
    if (log.isTaken)     return '✓ Alındı';
    if (log.isMissed)    return '✗ Atlandı';
    if (log.isPostponed) return '⏸ Ertelendi';
    if (log.isOverdue)   return '⚠ Gecikmiş';
    if (log.isUpcoming)  return '🔔 Yaklaşıyor';
    return '○ Bekliyor';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: _accentColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İlaç adı + durum
            Row(
              children: [
                Expanded(
                  child: Text(
                    log.medicationName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kTextDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: _accentColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Dozaj formu
            Text(
              log.dosageForm,
              style: const TextStyle(
                  fontSize: 13, color: _kTextMid),
            ),

            // Gerçekleşen alım saati (alındıysa)
            if (log.actualTime != null) ...[
              const SizedBox(height: 4),
              Text(
                'Alındı: ${DateFormat('HH:mm').format(log.actualTime!)}',
                style: const TextStyle(
                    fontSize: 12, color: _kSuccess),
              ),
            ],

            // Not
            if (log.notes != null && log.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '📝 ${log.notes}',
                style: const TextStyle(
                    fontSize: 12, color: _kTextMid),
              ),
            ],

            // ── Bekliyor aksiyon butonları
            if (log.isPending) ...[
              const SizedBox(height: 12),
              // Swipe ipucu (sadece mobilde görünür, ama gösterim önemli)
              const Text(
                '← Sola sürerek de işaretleyebilirsiniz',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF90A4AE),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                      onPressed: onTaken,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text(
                        'Aldım',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kSuccess,
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      onPressed: onMissed,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text(
                        'Atladım',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kDanger,
                        side: const BorderSide(color: _kDanger),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Ertele mini butonu — snooze sheet açar
                  Tooltip(
                    message: 'Ertele',
                    child: IconButton.outlined(
                      onPressed: onSnooze != null
                          ? () => _showSnoozeSheet(context)
                          : null,
                      icon: const Icon(Icons.snooze_rounded, size: 20),
                      style: IconButton.styleFrom(
                        foregroundColor: _kWarning,
                        side: const BorderSide(color: _kWarning),
                        minimumSize: const Size(44, 44),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // ── Ertelendi: "Şimdi Al" + "Tekrar Ertele" + "Atla" (Kapalı Döngü)
            if (log.isPostponed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                      onPressed: onTaken,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text(
                        'Şimdi Al',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kSuccess,
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      onPressed: onMissed,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text(
                        'Atla',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kDanger,
                        side: const BorderSide(color: _kDanger),
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Tekrar Ertele',
                    child: IconButton.outlined(
                      onPressed: onSnooze != null
                          ? () => _showSnoozeSheet(context)
                          : null,
                      icon: const Icon(Icons.snooze_rounded, size: 20),
                      style: IconButton.styleFrom(
                        foregroundColor: _kWarning,
                        side: const BorderSide(color: _kWarning),
                        minimumSize: const Size(44, 44),
                      ),
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

  void _showSnoozeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _HeroSnoozeSheet(
        medicationName: log.medicationName,
        onSelected: (minutes) {
          Navigator.of(ctx).pop();
          onSnooze?.call(minutes);
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// YARDIMCI WİDGETLAR
// ══════════════════════════════════════════════════════════════════════

class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_available_rounded,
                  size: 80, color: Colors.grey[300]),
              const SizedBox(height: 20),
              const Text(
                'Bugün için\nilaç programı yok',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _kTextMid,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'İlaçlarım sekmesinden ilaç ekleyebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _kPrimary),
              SizedBox(height: 20),
              Text(
                'Doz programı yükleniyor...',
                style: TextStyle(fontSize: 15, color: _kTextMid),
              ),
            ],
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 64, color: _kDanger),
              const SizedBox(height: 16),
              const Text(
                'Bağlantı Hatası',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: _kTextMid),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tekrar Dene'),
                style: FilledButton.styleFrom(
                    backgroundColor: _kPrimary),
              ),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════
// GECİKMİŞ İLAÇ UYARI BARI (Modül 2 + Modül 8)
// ══════════════════════════════════════════════════════════════════════

class _OverdueAlertBar extends StatelessWidget {
  final List<DoseLog> overdueLogs;
  final void Function(DoseLog log) onTaken;
  final void Function(DoseLog log) onAskReason;

  const _OverdueAlertBar({
    required this.overdueLogs,
    required this.onTaken,
    required this.onAskReason,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFC62828).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC62828).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Başlık
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFC62828), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gecikmiş İlaç (${overdueLogs.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC62828),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFFFCDD2)),
          // ── Her gecikmiş ilaç satırı
          ...overdueLogs.map((log) => _OverdueRow(
                log: log,
                onTaken: () => onTaken(log),
                onAskReason: () => onAskReason(log),
              )),
        ],
      ),
    );
  }
}

class _OverdueRow extends StatelessWidget {
  final DoseLog log;
  final VoidCallback onTaken;
  final VoidCallback onAskReason;

  const _OverdueRow({
    required this.log,
    required this.onTaken,
    required this.onAskReason,
  });

  @override
  Widget build(BuildContext context) {
    final delay = DateTime.now().difference(log.scheduledTime);
    final isLongOverdue = delay.inMinutes >= 60;
    final delayStr = delay.inMinutes >= 60
        ? '${delay.inHours} sa ${delay.inMinutes % 60} dk gecikmiş'
        : '${delay.inMinutes} dk gecikmiş';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // İlaç bilgisi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.medicationName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '🕐 ${DateFormat('HH:mm').format(log.scheduledTime)}  •  $delayStr',
                  style: TextStyle(
                    fontSize: 11,
                    color: isLongOverdue
                        ? const Color(0xFFC62828)
                        : const Color(0xFFE65100),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Şimdi Al butonu
          SizedBox(
            height: 36,
            child: FilledButton(
              onPressed: onTaken,
              style: FilledButton.styleFrom(
                backgroundColor: _kSuccess,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('✓ Al', style: TextStyle(fontSize: 13)),
            ),
          ),
          // 1 saat+ gecikmiş → "Neden almadınız?" (Modül 8)
          if (isLongOverdue) ...[
            const SizedBox(width: 6),
            SizedBox(
              height: 36,
              child: OutlinedButton(
                onPressed: onAskReason,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC62828),
                  side: const BorderSide(
                      color: Color(0xFFC62828), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'Neden?',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// SEBEP CHİP — Davranışsal Sapma Analizi diyaloğu için
// ══════════════════════════════════════════════════════════════════════

class _ReasonChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ReasonChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ActionChip(
        label: Text(
          label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600),
        ),
        onPressed: onTap,
        backgroundColor: const Color(0xFFFFF3E0),
        side: const BorderSide(color: Color(0xFFE65100), width: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      );
}

