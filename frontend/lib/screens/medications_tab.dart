/// SmartDoz - İlaçlarım Sekmesi
///
/// Kullanıcının kayıtlı ilaçlarını modern kartlarla listeler.
/// FAB ile hızlı ilaç ekleme sağlar.
/// Son kullanma tarihi geçmiş ilaçlara uyarı gösterilir.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/medication.dart';
import '../screens/medication_info_screen.dart';
import '../services/api_service.dart';
import 'add_medication_screen.dart';
import 'ocr_scan_screen.dart';
import 'voice_assistant_screen.dart';

// ── Renk sabitleri (Dashboard ile aynı paletit)
const _kPrimary  = Color(0xFF1565C0);
const _kDanger   = Color(0xFFC62828);
const _kWarning  = Color(0xFFE65100);
const _kSuccess  = Color(0xFF2E7D32);
const _kBg       = Color(0xFFF0F4FF);
const _kTextDark = Color(0xFF0D1B2A);
const _kTextMid  = Color(0xFF455A64);

class MedicationsTab extends StatefulWidget {
  const MedicationsTab({super.key, this.onGoHome});

  /// İlaç başarıyla eklenince HomeScreen'i tab 0'a almak için
  final VoidCallback? onGoHome;

  @override
  State<MedicationsTab> createState() => _MedicationsTabState();
}

class _MedicationsTabState extends State<MedicationsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late Future<List<Medication>> _medsFuture;

  @override
  void initState() {
    super.initState();
    _loadMeds();
  }

  void _loadMeds() {
    _medsFuture = context.read<ApiService>().getMedications();
  }

  Future<void> _onDelete(int id) async {
    final confirmed = await _confirmDelete();
    if (!confirmed || !mounted) return;
    try {
      await context.read<ApiService>().deleteMedication(id);
      if (mounted) {
        setState(_loadMeds);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('İlaç silindi.'),
            backgroundColor: _kSuccess,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } on ApiException catch (e) {
      _showError(e.message);
    }
  }

  Future<bool> _confirmDelete() async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('İlacı Sil',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text(
            'Bu ilacı listenizden kalıcı olarak silmek\n'
            'istediğinizden emin misiniz?',
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: _kDanger,
              ),
              child: const Text('Evet, Sil'),
            ),
          ],
        ),
      ) ??
      false;

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _kDanger,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _navigateToAdd() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicationScreen()),
    );
    if (added == true && mounted) {
      setState(_loadMeds);
      // İlaç eklendi → Ana Sayfa (Bugünün Çizelgesi) tabına dön
      widget.onGoHome?.call();
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.medication_rounded, size: 22),
            SizedBox(width: 8),
            Text('İlaçlarım',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: () => setState(_loadMeds),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Modül 6: Sesli Asistan
          FloatingActionButton(
            heroTag: 'voice_fab',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const VoiceAssistantScreen()),
            ),
            backgroundColor: const Color(0xFF1565C0),
            foregroundColor: Colors.white,
            tooltip: 'Sesli Asistan',
            child: const Icon(Icons.mic_rounded, size: 26),
          ),
          const SizedBox(height: 12),
          // Modül 4: OCR ile kutu tara
          FloatingActionButton(
            heroTag: 'ocr_scan_fab',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OcrScanScreen()),
            ),
            backgroundColor: const Color(0xFF00897B),
            foregroundColor: Colors.white,
            tooltip: 'Kutu ile Tara (OCR)',
            child: const Icon(Icons.document_scanner_rounded),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'add_med_fab',
            onPressed: _navigateToAdd,
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('İlaç Ekle',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _kPrimary,
        onRefresh: () async => setState(_loadMeds),
        child: FutureBuilder<List<Medication>>(
          future: _medsFuture,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _kPrimary),
              );
            }
            if (snap.hasError) {
              return _MedsErrorView(
                message: snap.error.toString(),
                onRetry: () => setState(_loadMeds),
              );
            }

            final meds = snap.data ?? [];
            if (meds.isEmpty) {
              return _EmptyMedsView(onAdd: _navigateToAdd);
            }

            // Grupla: aktif vs süresi dolmuş
            final active  = meds.where((m) => !m.isExpired).toList();
            final expired = meds.where((m) =>  m.isExpired).toList();

            return ListView(
              padding: const EdgeInsets.only(
                  top: 12, left: 16, right: 16, bottom: 100),
              children: [
                // Toplam sayı
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${meds.length} ilaç kayıtlı',
                    style: const TextStyle(
                        fontSize: 13, color: _kTextMid),
                  ),
                ),

                // Aktif ilaçlar
                ...active.map(
                  (m) => _MedicationCard(
                    medication: m,
                    onDelete: () => _onDelete(m.id!),
                  ),
                ),

                // Süresi dolmuşlar (varsa)
                if (expired.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: _kWarning),
                        const SizedBox(width: 6),
                        Text(
                          'Son Kullanma Tarihi Geçmiş (${expired.length})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kWarning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...expired.map(
                    (m) => _MedicationCard(
                      medication: m,
                      onDelete: () => _onDelete(m.id!),
                      isExpired: true,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── İlaç Kartı ─────────────────────────────────────────────────────

class _MedicationCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback onDelete;
  final bool isExpired;

  const _MedicationCard({
    required this.medication,
    required this.onDelete,
    this.isExpired = false,
  });

  @override
  Widget build(BuildContext context) {
    final expiry =
        DateFormat('d MMM yyyy', 'tr_TR').format(medication.expiryDate);
    final borderColor =
        isExpired ? _kDanger.withValues(alpha: 0.4) : Colors.transparent;

    return Dismissible(
      key: ValueKey('med_${medication.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: _kDanger,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 28),
            Text('Sil',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isExpired
              ? const Color(0xFFFFF3F3)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Üst satır: ikon + ilaç bilgisi + sil ──────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // İkon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isExpired
                          ? _kDanger.withValues(alpha: 0.1)
                          : _kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.medication_rounded,
                      color: isExpired ? _kDanger : _kPrimary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Bilgi
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medication.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _kTextDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _InfoChip(
                                label: medication.dosageForm,
                                color: _kPrimary),
                            const SizedBox(width: 6),
                            _InfoChip(
                                label: medication.usageFrequency,
                                color: _kTextMid),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              isExpired
                                  ? Icons.warning_amber_rounded
                                  : Icons.calendar_today_rounded,
                              size: 13,
                              color: isExpired ? _kDanger : _kTextMid,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'SKT: $expiry',
                              style: TextStyle(
                                fontSize: 12,
                                color: isExpired ? _kDanger : _kTextMid,
                                fontWeight: isExpired
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Sil butonu
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        color: Colors.grey.shade400),
                    onPressed: onDelete,
                    tooltip: 'Sil',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Tam genişlik AI özet butonu ─────────────────────
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF1A237E)],
                    ),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => MedicationInfoScreen.showSheet(
                      context,
                      medicationId: medication.id,
                      medicationName: medication.name,
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text('SmartDoz Yapay Zeka Özeti'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600),
        ),
      );
}

// ── Boş Durum ────────────────────────────────────────────────────────

class _EmptyMedsView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyMedsView({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.medication_outlined,
                  size: 80, color: Colors.grey[300]),
              const SizedBox(height: 20),
              const Text(
                'Henüz ilaç eklemediniz',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Düzenli takip için ilaçlarınızı ekleyin.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _kTextMid),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('İlk İlacı Ekle',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Hata Durumu ────────────────────────────────────────────────────

class _MedsErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _MedsErrorView(
      {required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 60, color: _kDanger),
              const SizedBox(height: 16),
              const Text('İlaçlar yüklenemedi',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: _kTextMid)),
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
