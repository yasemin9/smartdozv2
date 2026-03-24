/// SmartDoz - Hatırlatıcı Tercihleri Ekranı
///
/// Kullanıcı uyanma ve uyuma saatlerini belirler.
/// Bu değerler ZAMANDILIMIHESAPLA algoritmasının girdilerini oluşturur
/// (EK1_revize.pdf, Sayfa 37).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_preference.dart';
import '../services/api_service.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  bool _loading = true;
  bool _saving = false;
  TimeOfDay _wakeTime  = const TimeOfDay(hour: 8,  minute: 0);
  TimeOfDay _sleepTime = const TimeOfDay(hour: 22, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final pref = await context.read<ApiService>().getPreferences();
      if (mounted) {
        setState(() {
          _wakeTime  = _parseTime(pref.wakeTime);
          _sleepTime = _parseTime(pref.sleepTime);
          _loading   = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour:   int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _timeToString(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime(bool isWake) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isWake ? _wakeTime : _sleepTime,
      helpText: isWake ? 'Uyanma Saati' : 'Uyku Saati',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isWake) _wakeTime = picked;
      else _sleepTime = picked;
    });
  }

  Future<void> _save() async {
    // Basit doğrulama
    final wakeMinutes  = _wakeTime.hour  * 60 + _wakeTime.minute;
    final sleepMinutes = _sleepTime.hour * 60 + _sleepTime.minute;
    final window = sleepMinutes > wakeMinutes
        ? sleepMinutes - wakeMinutes
        : (sleepMinutes + 1440) - wakeMinutes;

    if (window < 240) {
      _showSnack('Uyanma ve uyku saati arasında en az 4 saat olmalıdır.', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final pref = UserPreference(
        wakeTime:  _timeToString(_wakeTime),
        sleepTime: _timeToString(_sleepTime),
      );
      await context.read<ApiService>().updatePreferences(pref);
      _showSnack('Tercihler kaydedildi. İlaç zamanları yeniden hesaplanacak.');
    } on ApiException catch (e) {
      _showSnack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, size: 22),
            SizedBox(width: 8),
            Text('Hatırlatıcı Ayarları',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Bilgi kartı
                  _InfoCard(),
                  const SizedBox(height: 24),

                  // ── Saat seçiciler
                  _SectionTitle(title: 'Günlük Program'),
                  const SizedBox(height: 12),
                  _TimePicker(
                    label: 'Uyanma Saati',
                    icon: Icons.wb_sunny_rounded,
                    iconColor: const Color(0xFFF9A825),
                    time: _wakeTime,
                    onTap: () => _pickTime(true),
                  ),
                  const SizedBox(height: 12),
                  _TimePicker(
                    label: 'Uyku Saati',
                    icon: Icons.bedtime_rounded,
                    iconColor: const Color(0xFF1565C0),
                    time: _sleepTime,
                    onTap: () => _pickTime(false),
                  ),

                  const SizedBox(height: 32),

                  // ── Önizleme
                  _SchedulePreview(
                    wakeTime: _wakeTime,
                    sleepTime: _sleepTime,
                  ),

                  const SizedBox(height: 32),

                  // ── Kaydet butonu
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ────────────────────────────────────────────────────
// Bilgi Kartı
// ────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'SmartDoz, uyanma ve uyku saatlerinize göre ilaç alma zamanlarınızı '
                'otomatik olarak hesaplar (ZAMANDILIMIHESAPLA algoritması).',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      );
}

// ────────────────────────────────────────────────────
// Bölüm başlığı
// ────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF546E7A)),
      );
}

// ────────────────────────────────────────────────────
// Saat Seçici Kartı
// ────────────────────────────────────────────────────
class _TimePicker extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimePicker({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: iconColor.withOpacity(0.15),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      );
}

// ────────────────────────────────────────────────────
// Zamanlama Önizlemesi (1, 2 ve 3 dozluk örnekler)
// ────────────────────────────────────────────────────
class _SchedulePreview extends StatelessWidget {
  final TimeOfDay wakeTime;
  final TimeOfDay sleepTime;
  const _SchedulePreview({required this.wakeTime, required this.sleepTime});

  String _calcDoseTime(int doseIndex, int total) {
    final wakeMin  = wakeTime.hour  * 60 + wakeTime.minute;
    final sleepMin = sleepTime.hour * 60 + sleepTime.minute;
    final window   = sleepMin > wakeMin
        ? sleepMin - wakeMin
        : (sleepMin + 1440) - wakeMin;
    if (total == 1) {
      final m = wakeMin + 60;
      return '${(m ~/ 60) % 24}:${(m % 60).toString().padLeft(2, '0')}';
    }
    final interval  = window / (total + 1);
    final latestMin = sleepMin > wakeMin ? sleepMin - 30 : (sleepMin + 1440) - 30;
    int doseMin = wakeMin + (interval * doseIndex).round();
    if (doseMin > latestMin) doseMin = latestMin;
    return '${(doseMin ~/ 60) % 24}:${(doseMin % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final examples = [
      ('Günde 1 kez', 1),
      ('Günde 2 kez', 2),
      ('Günde 3 kez', 3),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hesaplanan Doz Zamanları (Önizleme)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF546E7A)),
          ),
          const SizedBox(height: 12),
          ...examples.map((ex) {
            final times = List.generate(
              ex.$2,
              (i) => _calcDoseTime(i + 1, ex.$2),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      ex.$1,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF546E7A)),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: times
                          .map(
                            (t) => Chip(
                              label: Text(t,
                                  style: const TextStyle(fontSize: 12)),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
