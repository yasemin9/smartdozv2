// SmartDoz - Modül 8: YZ Akıllı Profil Ekranı
//
// F-M8.1: Kullanıcının davranış profilini (profil tipi, lokal pencere skorları,
//          genel uyum skoru) gösterir.
// F-M8.2: Bekleyen adaptif zamanlama önerilerini listeler.
// F-M8.3: Alarm tonu adaptasyon önerilerini listeler.
// F-M8.4: XAI açıklamaları ile her kararın nedenini şeffaf biçimde sunar.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_decision.dart';
import '../models/smart_tip.dart';
import '../services/api_service.dart';
import '../widgets/decision_notification_card.dart';
import '../widgets/smart_tip_card.dart';

class AIProfileScreen extends StatefulWidget {
  const AIProfileScreen({super.key});

  @override
  State<AIProfileScreen> createState() => _AIProfileScreenState();
}

class _AIProfileScreenState extends State<AIProfileScreen> {
  late Future<AIProfile> _profileFuture;
  late Future<List<SmartTip>> _tipsFuture;
  bool _generatingDecisions = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _profileFuture = context.read<ApiService>().getAIProfile();
    _tipsFuture    = context.read<ApiService>().getSmartTips();
  }

  Future<void> _generateDecisions() async {
    setState(() => _generatingDecisions = true);
    try {
      await context.read<ApiService>().generateAIDecisions();
    } on ApiException catch (e) {
      if (mounted) _showError('API Hatası: ${e.message}');
    } catch (e) {
      // Ağ hatası, JSON parse hatası veya beklenmedik istisna
      if (mounted) _showError('Bağlantı hatası: $e');
    } finally {
      if (mounted) {
        _load();
        setState(() => _generatingDecisions = false);
      }
    }
  }

  Future<void> _dismiss(int decisionId) async {
    try {
      await context.read<ApiService>().resolveAIDecision(
            decisionId: decisionId,
            status: 'REJECTED',
          );
      if (mounted) setState(_load);
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Akıllı Profil'),
        centerTitle: true,
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Analizi Yenile',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(_load),
          ),
        ],
      ),
      body: FutureBuilder<AIProfile>(
        future: _profileFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorView(
              message: snap.error.toString(),
              onRetry: () => setState(_load),
            );
          }
          final profile = snap.data!;
          return _ProfileBody(
            profile: profile,
            tipsFuture: _tipsFuture,
            generatingDecisions: _generatingDecisions,
            onGenerate: _generateDecisions,
            onDismiss: _dismiss,
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Ana Gövde
// ──────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  final AIProfile profile;
  final Future<List<SmartTip>> tipsFuture;
  final bool generatingDecisions;
  final VoidCallback onGenerate;
  final Future<void> Function(int) onDismiss;

  const _ProfileBody({
    required this.profile,
    required this.tipsFuture,
    required this.generatingDecisions,
    required this.onGenerate,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bp = profile.behaviorProfile;
    final pendingDecisions = profile.pendingDecisions
        .where((d) => d.decisionType != 'GAMIFICATION')
        .toList();
    final recentDecisions = profile.recentDecisions
        .where((d) => d.decisionType != 'GAMIFICATION')
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Profil Kartı ──────────────────────────────
        _ProfileCard(profile: bp),
        const SizedBox(height: 16),

        // ── Pencere Skorları ──────────────────────────
        _WindowScoreSection(windowScores: bp.windowScores),
        const SizedBox(height: 16),

        // ── Analiz Başlat Butonu ─────────────────────
        _AnalyzeButton(
          loading: generatingDecisions,
          onPressed: onGenerate,
        ),
        const SizedBox(height: 20),

        // ── Akıllı İpuçları ───────────────────────────
        _SmartTipsSection(tipsFuture: tipsFuture),
        const SizedBox(height: 20),

        // ── Bekleyen Kararlar ─────────────────────────
        if (pendingDecisions.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.pending_actions_rounded,
            title: 'Bekleyen Öneriler',
            badge: pendingDecisions.length,
            color: const Color(0xFF1976D2),
          ),
          const SizedBox(height: 8),
          ...pendingDecisions.map(
            (d) => DecisionNotificationCard(
              key: ValueKey(d.id),
              decision: d,
              onDismiss: () => onDismiss(d.id),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Geçmiş Kararlar ───────────────────────────
        if (recentDecisions.isNotEmpty) ...[
          const _SectionHeader(
            icon: Icons.history_rounded,
            title: 'Son Kararlar',
            color: Colors.black54,
          ),
          const SizedBox(height: 8),
          ...recentDecisions.map(
            (d) => DecisionHistoryCard(key: ValueKey('h${d.id}'), decision: d),
          ),
          const SizedBox(height: 20),
        ],

        // Veri yoksa boş durum
        if (pendingDecisions.isEmpty && recentDecisions.isEmpty)
          const _EmptyDecisionsView(),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────
// Profil Kartı
// ──────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final BehaviorProfile profile;

  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final pct = profile.overallPercent;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                // İkon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      profile.profileIcon,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.profileType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Genel skor
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Genel Uyum Skoru',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: profile.overallScore,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.25),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            pct >= 85
                                ? Colors.greenAccent.shade400
                                : pct >= 60
                                    ? Colors.orangeAccent
                                    : Colors.redAccent,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '%${pct.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Pencere Skorları Bölümü (Sabah / Öğle / Akşam)
// ──────────────────────────────────────────────────────

class _WindowScoreSection extends StatelessWidget {
  final List<TimeWindowScore> windowScores;

  const _WindowScoreSection({required this.windowScores});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Zaman Penceresi Analizleri',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
        ),
        Row(
          children: windowScores
              .map((w) => Expanded(child: _WindowTile(score: w)))
              .toList(),
        ),
      ],
    );
  }
}

class _WindowTile extends StatelessWidget {
  final TimeWindowScore score;

  const _WindowTile({required this.score});

  static const _windowIcons = {
    'morning': Icons.wb_sunny_rounded,
    'noon':    Icons.wb_cloudy_rounded,
    'evening': Icons.nights_stay_rounded,
  };

  static const _windowColors = {
    'morning': Color(0xFFFF8F00),
    'noon':    Color(0xFF0288D1),
    'evening': Color(0xFF512DA8),
  };

  @override
  Widget build(BuildContext context) {
    final color  = _windowColors[score.window] ?? Colors.grey;
    final icon   = _windowIcons[score.window] ?? Icons.access_time_rounded;
    final pct    = score.scorePercent;
    final noData = !score.hasData;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              score.label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            if (noData)
              const Text(
                'Veri yok',
                style: TextStyle(fontSize: 10, color: Colors.black38),
              )
            else ...[
              Text(
                '%${pct.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: pct >= 80
                      ? Colors.green.shade600
                      : pct >= 50
                          ? Colors.orange.shade700
                          : Colors.red.shade600,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score.localScore,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${score.taken}/${score.planned} doz',
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.black45,
                ),
              ),
              if (score.consecutiveSkips >= 3) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '⚠ ${score.consecutiveSkips} ardışık atlama',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Analiz Başlat Butonu
// ──────────────────────────────────────────────────────

class _AnalyzeButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _AnalyzeButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.psychology_rounded, size: 18),
        label: Text(loading ? 'Analiz ediliyor…' : 'Yeni Öneriler Üret'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 3,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Bölüm Başlığı
// ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final int? badge;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: color,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$badge',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ──────────────────────────────────────────────────────
// Boş Durum
// ──────────────────────────────────────────────────────

class _EmptyDecisionsView extends StatelessWidget {
  const _EmptyDecisionsView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 56, color: Colors.green.shade400),
            const SizedBox(height: 12),
            const Text(
              'Şu an bekleyen öneri yok',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '"Yeni Öneriler Üret" ile analizi başlatın.',
              style: TextStyle(fontSize: 12, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// Akıllı İpuçları Bölümü
// ──────────────────────────────────────────────────────

class _SmartTipsSection extends StatelessWidget {
  final Future<List<SmartTip>> tipsFuture;

  const _SmartTipsSection({required this.tipsFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SmartTip>>(
      future: tipsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final tips = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.lightbulb_outline_rounded,
              title: 'Akıllı İpuçları',
              badge: tips.length,
              color: const Color(0xFFF57F17),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'Sistem sizi gözlemliyor ve öneriyor — tüm kararlar size ait.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            ...tips.map((t) => SmartTipCard(key: ValueKey(t.tipId), tip: t)),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────
// Hata Görünümü
// ──────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Yeniden Dene'),
            ),
          ],
        ),
      ),
    );
  }
}
