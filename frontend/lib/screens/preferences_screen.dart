/// SmartDoz - Hatırlatıcı Tercihleri Ekranı
///
/// Kullanıcı uyanma ve uyuma saatlerini belirler.
/// Bu değerler Zaman Dilimi Hesapla algoritmasının girdilerini oluşturur
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
  TimeOfDay _wakeTime      = const TimeOfDay(hour: 8,  minute: 0);
  TimeOfDay _sleepTime     = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay? _breakfastTime;
  TimeOfDay? _lunchTime;
  TimeOfDay? _dinnerTime;
  TimeOfDay? _bedtime;

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
          _wakeTime      = _parseTime(pref.wakeTime);
          _sleepTime     = _parseTime(pref.sleepTime);
          _breakfastTime = pref.breakfastTime != null ? _parseTime(pref.breakfastTime!) : null;
          _lunchTime     = pref.lunchTime     != null ? _parseTime(pref.lunchTime!)     : null;
          _dinnerTime    = pref.dinnerTime    != null ? _parseTime(pref.dinnerTime!)    : null;
          _bedtime       = pref.bedtime       != null ? _parseTime(pref.bedtime!)       : null;
          _loading       = false;
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

  String? _optionalTimeToString(TimeOfDay? t) =>
      t == null ? null : _timeToString(t);

  Future<void> _pickTime(String field) async {
    TimeOfDay initial;
    String helpText;
    switch (field) {
      case 'wake':
        initial  = _wakeTime;
        helpText = 'Uyanma Saati';
      case 'sleep':
        initial  = _sleepTime;
        helpText = 'Uyku Saati';
      case 'breakfast':
        initial  = _breakfastTime ?? const TimeOfDay(hour: 8, minute: 0);
        helpText = 'Kahvaltı Saati';
      case 'lunch':
        initial  = _lunchTime ?? const TimeOfDay(hour: 13, minute: 0);
        helpText = 'Öğle Yemeği Saati';
      case 'dinner':
        initial  = _dinnerTime ?? const TimeOfDay(hour: 19, minute: 0);
        helpText = 'Akşam Yemeği Saati';
      case 'bedtime':
        initial  = _bedtime ?? const TimeOfDay(hour: 22, minute: 0);
        helpText = 'Yatış Saati';
      default:
        return;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: helpText,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      switch (field) {
        case 'wake':      _wakeTime      = picked;
        case 'sleep':     _sleepTime     = picked;
        case 'breakfast': _breakfastTime = picked;
        case 'lunch':     _lunchTime     = picked;
        case 'dinner':    _dinnerTime    = picked;
        case 'bedtime':   _bedtime       = picked;
      }
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
        wakeTime:      _timeToString(_wakeTime),
        sleepTime:     _timeToString(_sleepTime),
        breakfastTime: _optionalTimeToString(_breakfastTime),
        lunchTime:     _optionalTimeToString(_lunchTime),
        dinnerTime:    _optionalTimeToString(_dinnerTime),
        bedtime:       _optionalTimeToString(_bedtime),
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
                  const SizedBox(height: 16),

                  // ── Uyku / Uyanma saatleri
                  _SectionTitle(title: 'Günlük Program'),
                  const SizedBox(height: 16),
                  _TimePicker(
                    label: 'Uyanma Saati',
                    icon: Icons.wb_sunny_rounded,
                    iconColor: const Color(0xFFF9A825),
                    time: _wakeTime,
                    onTap: () => _pickTime('wake'),
                  ),
                  const SizedBox(height: 16),
                  _TimePicker(
                    label: 'Uyku Saati',
                    icon: Icons.bedtime_rounded,
                    iconColor: const Color(0xFF1565C0),
                    time: _sleepTime,
                    onTap: () => _pickTime('sleep'),
                  ),
                  const SizedBox(height: 24),

                  // ── Günlük Rutin Saatler
                  _SectionTitle(title: 'Günlük Rutin (İlaç Saatleri İçin)'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFCC02), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFF57F17)),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '"Yemekten önce/sonra", "Sabah", "Yatmadan önce" gibi seçenekler '
                            'bu saatler kullanılarak hesaplanır. Tanımlamadığınız saatler için '
                            'sistem varsayılan değerlere döner.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF795548), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _OptionalTimePicker(
                    label: 'Kahvaltı Saati',
                    icon: Icons.free_breakfast_rounded,
                    iconColor: const Color(0xFFFF8F00),
                    time: _breakfastTime,
                    placeholder: 'Tanımlanmadı (varsayılan: 08:00)',
                    onTap: () => _pickTime('breakfast'),
                    onClear: () => setState(() => _breakfastTime = null),
                  ),
                  const SizedBox(height: 12),
                  _OptionalTimePicker(
                    label: 'Öğle Yemeği Saati',
                    icon: Icons.lunch_dining_rounded,
                    iconColor: const Color(0xFF43A047),
                    time: _lunchTime,
                    placeholder: 'Tanımlanmadı (varsayılan: 13:00)',
                    onTap: () => _pickTime('lunch'),
                    onClear: () => setState(() => _lunchTime = null),
                  ),
                  const SizedBox(height: 12),
                  _OptionalTimePicker(
                    label: 'Akşam Yemeği Saati',
                    icon: Icons.dinner_dining_rounded,
                    iconColor: const Color(0xFFE53935),
                    time: _dinnerTime,
                    placeholder: 'Tanımlanmadı (varsayılan: 19:00)',
                    onTap: () => _pickTime('dinner'),
                    onClear: () => setState(() => _dinnerTime = null),
                  ),
                  const SizedBox(height: 12),
                  _OptionalTimePicker(
                    label: 'Yatış Saati',
                    icon: Icons.hotel_rounded,
                    iconColor: const Color(0xFF5E35B1),
                    time: _bedtime,
                    placeholder: 'Tanımlanmadı (varsayılan: 22:00)',
                    onTap: () => _pickTime('bedtime'),
                    onClear: () => setState(() => _bedtime = null),
                  ),
                  const SizedBox(height: 16),

                  // ── Önizleme
                  _SchedulePreview(
                    wakeTime: _wakeTime,
                    sleepTime: _sleepTime,
                  ),

                  const SizedBox(height: 16),

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
                'otomatik olarak hesaplar (Zaman Dilimi Hesapla algoritması).',
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
// Opsiyonel Saat Seçici (Rutin Saatler)
// ────────────────────────────────────────────────────
class _OptionalTimePicker extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final TimeOfDay? time;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _OptionalTimePicker({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.time,
    required this.placeholder,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: time != null
                  ? iconColor.withOpacity(0.4)
                  : Colors.grey.shade200,
              width: time != null ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: iconColor.withOpacity(0.12),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF546E7A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time != null
                          ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
                          : placeholder,
                      style: TextStyle(
                        fontSize: time != null ? 20 : 12,
                        fontWeight: time != null ? FontWeight.w800 : FontWeight.normal,
                        color: time != null ? iconColor : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (time != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: Colors.grey,
                  tooltip: 'Temizle',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else
                Icon(Icons.add_circle_outline_rounded, color: iconColor.withOpacity(0.6), size: 20),
            ],
          ),
        ),
      );
}

// ────────────────────────────────────────────────────
// Zamanlama Önizlemesi (1, 2 ve 3 dozluk örnekler)
// ────────────────────────────────────────────────────
class _SchedulePreview extends StatefulWidget {
  final TimeOfDay wakeTime;
  final TimeOfDay sleepTime;
  const _SchedulePreview({required this.wakeTime, required this.sleepTime});

  @override
  State<_SchedulePreview> createState() => _SchedulePreviewState();
}

class _SchedulePreviewState extends State<_SchedulePreview> {
  // (exampleIndex, doseIndex) → kullanıcının manuel seçtiği saat
  final Map<(int, int), String> _overrides = {};

  String _calcDoseTime(int doseIndex, int total) {
    final wakeMin  = widget.wakeTime.hour  * 60 + widget.wakeTime.minute;
    final sleepMin = widget.sleepTime.hour * 60 + widget.sleepTime.minute;
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

  Future<void> _pickDoseTime(int exIdx, int doseIdx, int total) async {
    final current = _overrides[(exIdx, doseIdx)] ?? _calcDoseTime(doseIdx + 1, total);
    final parts   = current.split(':');
    final initial = TimeOfDay(
      hour:   int.tryParse(parts.isNotEmpty ? parts[0] : '8') ?? 8,
      minute: int.tryParse(parts.length > 1  ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Doz Saatini Seç',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _overrides[(exIdx, doseIdx)] =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final examples = [
      ('Günde 1 kez', 1),
      ('Günde 2 kez', 2),
      ('Günde 3 kez', 3),
    ];
    final primaryColor = Theme.of(context).colorScheme.primary;
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
          const SizedBox(height: 4),
          const Text(
            'Kutucuklara dokunarak saati manuel olarak ayarlayabilirsiniz.',
            style: TextStyle(fontSize: 11, color: Color(0xFF90A4AE)),
          ),
          const SizedBox(height: 12),
          ...examples.asMap().entries.map((entry) {
            final exIdx = entry.key;
            final ex    = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      ex.$1,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A)),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: List.generate(ex.$2, (doseIdx) {
                        final timeStr    = _overrides[(exIdx, doseIdx)] ?? _calcDoseTime(doseIdx + 1, ex.$2);
                        final isOverridden = _overrides.containsKey((exIdx, doseIdx));
                        return InkWell(
                          onTap: () => _pickDoseTime(exIdx, doseIdx, ex.$2),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isOverridden
                                  ? primaryColor.withOpacity(0.15)
                                  : primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isOverridden ? primaryColor : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  timeStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isOverridden ? FontWeight.w700 : FontWeight.w500,
                                    color: isOverridden ? primaryColor : const Color(0xFF546E7A),
                                  ),
                                ),
                                if (isOverridden) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.edit_rounded, size: 10, color: primaryColor),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
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
