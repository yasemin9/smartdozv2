/// SmartDoz - Ana Dashboard Ekranı
///
/// Kullanıcının ilaçlarını listeler; yenile ve sil işlemlerini
/// destekler; Add Medication ekranına yönlendirme sağlar.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medication.dart';
import '../services/api_service.dart';
import '../widgets/medication_card.dart';
import 'add_medication_screen.dart';
import 'calendar_screen.dart';
import 'login_screen.dart';
import 'preferences_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Medication>> _medicationsFuture;

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  void _loadMedications() {
    _medicationsFuture =
        context.read<ApiService>().getMedications();
  }

  Future<void> _onDelete(int id) async {
    final confirmed = await _showDeleteDialog();
    if (!confirmed) return;

    try {
      await context.read<ApiService>().deleteMedication(id);
      if (mounted) {
        setState(_loadMedications);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İlaç silindi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ApiException catch (e) {
      _showError(e.message);
    }
  }

  Future<bool> _showDeleteDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('İlacı Sil'),
            content: const Text(
              'Bu ilacı listenizden silmek istediğinize emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sil'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _logout() async {
    await context.read<ApiService>().logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<ApiService>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.medication_rounded, size: 26),
            const SizedBox(width: 8),
            const Text(
              'SmartDoz',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  'Merhaba, ${user.firstName}',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          // ── Takvim (Modül 2)
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Doz Takvimi',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CalendarScreen()),
            ),
          ),
          // ── Tercihler (Modül 2)
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Hatırlatıcı Ayarları',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PreferencesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Çıkış Yap',
            onPressed: _logout,
          ),
        ],
      ),

      // ── İlaç Listesi
      body: RefreshIndicator(
        onRefresh: () async => setState(_loadMedications),
        child: FutureBuilder<List<Medication>>(
          future: _medicationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _ErrorView(
                message: snapshot.error.toString(),
                onRetry: () => setState(_loadMedications),
              );
            }

            final medications = snapshot.data ?? [];

            if (medications.isEmpty) {
              return _EmptyView(
                onAdd: () => _navigateToAdd(),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Özet başlık
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    '${medications.length} İlaç Kaydı',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[700],
                        ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: medications.length,
                    padding: const EdgeInsets.only(bottom: 100),
                    itemBuilder: (context, index) => MedicationCard(
                      medication: medications[index],
                      onDelete: () => _onDelete(medications[index].id!),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),

      // ── Yeni İlaç Butonu
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'İlaç Ekle',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _navigateToAdd() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicationScreen()),
    );
    if (added == true && mounted) setState(_loadMedications);
  }
}

// ────────────────────────────────────────────────────
// Yardımcı Widget'lar
// ────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz ilaç eklemediniz.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('İlk İlacınızı Ekleyin'),
            ),
          ],
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
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
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
