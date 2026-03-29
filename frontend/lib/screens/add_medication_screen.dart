/// SmartDoz - İlaç Ekleme Formu
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/global_medication.dart';
import '../models/medication.dart';
import '../models/user_preference.dart';
import '../screens/preferences_screen.dart';
import '../services/api_service.dart';

/// Dozaj formu seçenekleri (EK1_revize.pdf Modül 1)
const List<String> kDosageForms = [
  'Tablet',
  'Şurup',
  'Kapsül',
  'Enjeksiyon',
  'Damla',
  'Krem / Merhem',
  'Toz',
  'Diğer',
];

/// Kullanım sıklığı önerileri
const List<String> kFrequencies = [
  'Günde 1 kez',
  'Günde 2 kez',
  'Günde 3 kez',
  'Her 8 saatte bir',
  'Her 12 saatte bir',
  'Haftada 1 kez',
  'Gerektiğinde',
];

/// Kullanım zamanı önerileri (sadece kategorik sıklıklar için)
const List<String> kUsageTimes = [
  'Sabah',
  'Öğle',
  'Akşam',
  'Yatmadan önce',
  'Yemekten önce',
  'Yemekten sonra',
  'Aç karnına',
];

/// Saatlik aralık tabanlı sıklıklar (İlk Doz Saati modunu tetikler)
const Set<String> kIntervalFrequencies = {
  'Her 8 saatte bir',
  'Her 12 saatte bir',
};

/// Sıklığın saatlik aralık tabanlı olup olmadığını kontrol eder
bool _isIntervalBased(String? freq) =>
    freq != null && kIntervalFrequencies.contains(freq);

/// Sıklık metninden saat aralığını çıkarır: 'Her 8 saatte bir' → 8
int? _extractIntervalHours(String freq) {
  final match = RegExp(r'\b(\d+)\b').firstMatch(freq);
  if (match == null) return null;
  final h = int.tryParse(match.group(1)!);
  return (h != null && h > 0 && 24 % h == 0) ? h : null;
}

/// Sıklıktan kaç doz gerektiğini çıkarır (kategorik mod için)
int _doseCountFromFrequency(String? freq) {
  if (freq == null) return 1;
  if (freq.contains('Günde 2')) return 2;
  if (freq.contains('Günde 3')) return 3;
  if (freq.contains('Haftada') || freq.contains('Gerektiğinde')) return 1;
  return 1;
}

/// Her etiket için varsayılan saat ve anlam dilimi kısıtları
const Map<String, ({TimeOfDay defaultTime, int minHour, int maxHour, String? note})>
    kLabelPresets = {
  'Sabah':          (defaultTime: TimeOfDay(hour: 9,  minute: 0), minHour: 5,  maxHour: 12, note: null),
  'Öğle':           (defaultTime: TimeOfDay(hour: 13, minute: 0), minHour: 11, maxHour: 15, note: null),
  'Akşam':          (defaultTime: TimeOfDay(hour: 20, minute: 0), minHour: 17, maxHour: 23, note: null),
  'Yatmadan önce':  (defaultTime: TimeOfDay(hour: 22, minute: 0), minHour: 20, maxHour: 24, note: null),
  'Yemekten önce':  (defaultTime: TimeOfDay(hour: 12, minute: 30), minHour: 5, maxHour: 24, note: 'Yemekten önce'),
  'Yemekten sonra': (defaultTime: TimeOfDay(hour: 13, minute: 0),  minHour: 5, maxHour: 24, note: 'Yemekten sonra'),
  'Aç karnına':     (defaultTime: TimeOfDay(hour: 8,  minute: 0),  minHour: 5, maxHour: 11, note: 'Aç karnına'),
};

/// Önerilen çiftli / üçlü kombinasyonlar (Kullanıcıya hızlı seçim için)
const Map<int, List<List<String>>> kSuggestedCombos = {
  2: [
    ['Sabah', 'Akşam'],
    ['Sabah', 'Yatmadan önce'],
    ['Öğle', 'Akşam'],
  ],
  3: [
    ['Sabah', 'Öğle', 'Akşam'],
    ['Sabah', 'Öğle', 'Yatmadan önce'],
  ],
};

/// Seçilen kullanım zamanının hangi profil rutinine bağlı olduğunu döner.
String? _requiredRoutineField(String usageTime) {
  const map = {
    'Sabah':              'breakfastTime',
    'Aç karnına':         'breakfastTime',
    'Öğle':               'lunchTime',
    'Akşam':              'dinnerTime',
    'Yemekten önce':      'dinnerTime',
    'Yemekten sonra':     'dinnerTime',
    'Yatmadan önce':      'bedtime',
  };
  return map[usageTime];
}

/// Tek bir doz slotu — label + kullanıcının üzerine yazdığı saat
class _DoseSlot {
  String label;          // 'Sabah', 'Öğle', vb.
  TimeOfDay? overrideTime; // null → preset varsayılanı kullan

  _DoseSlot(this.label, [this.overrideTime]);

  TimeOfDay get effectiveTime =>
      overrideTime ?? kLabelPresets[label]?.defaultTime ?? const TimeOfDay(hour: 8, minute: 0);

  /// Geçerli saatin anlam dilimi içinde olup olmadığını kontrol eder
  bool get isSemanticValid {
    final preset = kLabelPresets[label];
    if (preset == null) return true;
    final h = effectiveTime.hour;
    // maxHour 24 olabilir (“yatmadan önce” gece yarısı dahil)
    return h >= preset.minHour && (preset.maxHour == 24 || h < preset.maxHour);
  }

  String get note => kLabelPresets[label]?.note ?? '';

  /// DB'ye yazılacak string: 'Sabah|09:00' veya 'Yemekten sonra|13:00|Yemekten sonra'
  String toStorageString() {
    final hh = effectiveTime.hour.toString().padLeft(2, '0');
    final mm = effectiveTime.minute.toString().padLeft(2, '0');
    final n = note.isNotEmpty ? '|$note' : '';
    return '$label|$hh:$mm$n';
  }
}

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key, this.prefillName});

  /// OCR ekranından gelen önceden dolu ilaç adı (Modül 4).
  final String? prefillName;

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _suggScrollCtrl = ScrollController();

  // Modül 1 TypeAhead durumu
  List<GlobalMedication> _suggestions = [];
  bool _showSuggestions = false;
  bool _isSearching = false;
  bool _hasMore = true;
  int _searchOffset = 0;
  String _lastQuery = '';
  Timer? _debounceTimer;

  // Modül 3 için gizli alanlar — seçilen ilaç metadata
  GlobalMedication? _selectedGlobalMed;

  String? _selectedDosageForm;
  String? _selectedFrequency;
  // Kategorik dozlar: sıklığa göre kaç doz gerekiyorsa o kadar slot
  List<_DoseSlot> _doseSlots = [];
  // Aralıklı sıklık (Her 8/12 saatte bir) için ilk doz saati
  TimeOfDay? _firstDoseTime;
  String? _firstDoseTimeStr; // DB'ye yazılacak HH:MM
  DateTime? _expiryDate;
  bool _isLoading = false;
  List<InteractionWarning> _interactionWarnings = const [];
  Medication? _pendingMedication;

  // Modül 2: Kullanıcının kayıtlı rutin saatleri
  UserPreference? _userPref;

  @override
  void initState() {
    super.initState();
    // Modül 4: OCR ekranından gelen prefilled ilaç adını uygula
    if (widget.prefillName != null && widget.prefillName!.isNotEmpty) {
      _nameController.text = widget.prefillName!;
    }
    // Modül 2: Kullanıcının rutin saatlerini yükle
    _loadUserPreferences();
    // Sonsuz kaydırma: listenin altına yakınılacakta daha fazla yükle
    _suggScrollCtrl.addListener(() {
      final pos = _suggScrollCtrl.position;
      if (pos.pixels >= pos.maxScrollExtent - 80 &&
          !_isSearching &&
          _hasMore) {
        _fetchSuggestions(_lastQuery);
      }
    });
    // Alan odakı kaybedince 200ms sonra listeyi gizle
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _suggScrollCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ── Kullanıcı Tercih Yükleme ──────────────────────────

  Future<void> _loadUserPreferences() async {
    try {
      final pref = await context.read<ApiService>().getPreferences();
      if (mounted) setState(() => _userPref = pref);
    } catch (_) {
      // Tercihler yüklenemezse sessizce devam et; rutin kontrol uyarısı gösterilir
    }
  }

  // ── TypeAhead logic ──────────────────────────────────

  void _onNameChanged(String value) {
    // Seçili ilaçtan farklı bir şey yazılırsa seçimi sıfırla
    if (_selectedGlobalMed != null &&
        value.trim() != _selectedGlobalMed!.productName) {
      _selectedGlobalMed = null;
    }
    _debounceTimer?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _showSuggestions = false;
        _suggestions = [];
      });
      return;
    }
    _debounceTimer = Timer(
      const Duration(milliseconds: 350),
      () => _fetchSuggestions(value.trim(), reset: true),
    );
  }

  Future<void> _fetchSuggestions(String query, {bool reset = false}) async {
    if (reset) {
      _searchOffset = 0;
      _lastQuery = query;
      _suggestions = [];
      _hasMore = true;
    }
    if (!_hasMore || query.length < 2) return;

    setState(() => _isSearching = true);
    try {
      final results = await context.read<ApiService>().searchGlobalMedications(
            query: query,
            offset: _searchOffset,
          );
      if (!mounted) return;
      setState(() {
        _suggestions.addAll(results);
        _searchOffset += results.length;
        _hasMore = results.length == 20;
        _showSuggestions = _suggestions.isNotEmpty;
        _isSearching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSuggestionSelected(GlobalMedication med) {
    setState(() {
      _nameController.text = med.productName;
      _selectedGlobalMed = med;
      _showSuggestions = false;
      _suggestions = [];
      _interactionWarnings = const [];
    });
    _nameFocusNode.unfocus();
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      helpText: 'Son Kullanma Tarihi Seçin',
      confirmText: 'Seç',
      cancelText: 'İptal',
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expiryDate == null) {
      _showError('Lütfen son kullanma tarihini seçin.');
      return;
    }
    if (_isIntervalBased(_selectedFrequency) && _firstDoseTime == null) {
      _showError('Lütfen ilk doz saatini seçin.');
      return;
    }
    if (!_isIntervalBased(_selectedFrequency)) {
      final needed = _doseCountFromFrequency(_selectedFrequency);
      if (_doseSlots.length < needed) {
        _showError('Lütfen $needed doz zamanı seçin.');
        return;
      }
      // Anlamsal saat kontrolü
      for (final slot in _doseSlots) {
        if (!slot.isSemanticValid) {
          final preset = kLabelPresets[slot.label]!;
          _showError(
            '"${slot.label}" için seçilen saat geçersiz. '
            '${preset.minHour}:00 – ${preset.maxHour == 24 ? "23:59" : "${preset.maxHour}:00"} '
            'aralığında olmalıdır.',
          );
          return;
        }
      }
    }

    setState(() => _isLoading = true);

    // Kayıt için usage_time string'ini oluştur
    final usageTimeStr = _isIntervalBased(_selectedFrequency)
        ? _firstDoseTimeStr!
        : _doseSlots.map((s) => s.toStorageString()).join(';');

    try {
      final medication = Medication(
        name: _nameController.text.trim(),
        dosageForm: _selectedDosageForm!,
        usageFrequency: _selectedFrequency!,
        usageTime: usageTimeStr,
        expiryDate: _expiryDate!,
        activeIngredient: _selectedGlobalMed?.activeIngredient,
        atcCode: _selectedGlobalMed?.atcCode,
        barcode: _selectedGlobalMed?.barcode,
      );

      final api = context.read<ApiService>();
      final warnings = await api.previewMedicationInteractions(medication);

      if (warnings.isNotEmpty) {
        if (mounted) {
          setState(() {
            _pendingMedication = medication;
            _interactionWarnings = warnings;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Etkileşim riski bulundu. Lütfen onay verin.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      await api.createMedication(medication);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İlaç başarıyla eklendi!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // true: yenile sinyali
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('İlaç eklenemedi. Bağlantıyı kontrol edin.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmSaveDespiteWarnings() async {
    final pending = _pendingMedication;
    if (pending == null) return;

    setState(() => _isLoading = true);
    try {
      await context.read<ApiService>().createMedication(pending);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İlaç etkileşim uyarısı onayı ile kaydedildi.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('İlaç kaydedilemedi. Bağlantıyı kontrol edin.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _cancelSaveDueToWarnings() {
    setState(() {
      _interactionWarnings = const [];
      _pendingMedication = null;
    });
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'İlaç Ekle',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('İlaç Bilgileri'),
                      const SizedBox(height: 16),

                      // ── İlaç Adı — TypeAhead arama alanı
                      TextFormField(
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        onChanged: _onNameChanged,
                        decoration: _inputDecoration(
                          label: 'İlaç Adı',
                          hint: 'ör. Aspirin, Augmentin... (aramak için yazın)',
                          icon: Icons.medication_rounded,
                        ).copyWith(
                          suffixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : (_selectedGlobalMed != null
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.green,
                                    )
                                  : null),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'İlaç adı gereklidir.';
                          }
                          return null;
                        },
                      ),

                      // ── Öneri listesi (TypeAhead dropdown)
                      if (_showSuggestions)
                        _SuggestionDropdown(
                          suggestions: _suggestions,
                          isSearching: _isSearching,
                          scrollCtrl: _suggScrollCtrl,
                          onSelected: _onSuggestionSelected,
                        ),

                      // ── Seçili ilaç bilgi çipi (Modül 3 metadata göstergesi)
                      if (_selectedGlobalMed != null)
                        _SelectedMedChip(med: _selectedGlobalMed!),

                      // ── Modül 3: UYARIOLUSTUR kırmızı kartı
                      if (_interactionWarnings.isNotEmpty)
                        _InteractionWarningCard(
                          warnings: _interactionWarnings,
                          onConfirm: _confirmSaveDespiteWarnings,
                          onCancel: _cancelSaveDueToWarnings,
                          isBusy: _isLoading,
                        ),

                      const SizedBox(height: 16),

                      // ── Dozaj Formu
                      _buildDropdown<String>(
                        label: 'Dozaj Formu',
                        hint: 'Seçin',
                        icon: Icons.science_outlined,
                        value: _selectedDosageForm,
                        items: kDosageForms,
                        onChanged: (v) =>
                            setState(() => _selectedDosageForm = v),
                        validator: (v) =>
                            v == null ? 'Dozaj formu seçiniz.' : null,
                      ),
                      const SizedBox(height: 24),

                      _sectionTitle('Kullanım Bilgileri'),
                      const SizedBox(height: 16),

                      // ── Kullanım Sıklığı
                      _buildDropdown<String>(
                        label: 'Kullanım Sıklığı',
                        hint: 'Seçin',
                        icon: Icons.repeat_rounded,
                        value: _selectedFrequency,
                        items: kFrequencies,
                        onChanged: (v) {
                          final wasInterval = _isIntervalBased(_selectedFrequency);
                          final willBeInterval = _isIntervalBased(v);
                          setState(() {
                            _selectedFrequency = v;
                            // Sıklık türü değiştiğinde zaman seçimini sıfırla
                            if (wasInterval != willBeInterval) {
                              _doseSlots = [];
                              _firstDoseTime = null;
                              _firstDoseTimeStr = null;
                            } else if (!willBeInterval) {
                              // Kategorik kaldı ama doz sayısı değişti ise sıfırla
                              _doseSlots = [];
                            }
                          });
                        },
                        validator: (v) =>
                            v == null ? 'Kullanım sıklığı seçiniz.' : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Kullanım Zamanı / İlk Doz Saati (bağımlı alan)
                      if (_isIntervalBased(_selectedFrequency))
                        _buildFirstDoseTimePicker()
                      else if (_selectedFrequency != null &&
                          _selectedFrequency != 'Haftada 1 kez' &&
                          _selectedFrequency != 'Gerektiğinde')
                        _DoseSlotEditor(
                          frequency: _selectedFrequency!,
                          slots: _doseSlots,
                          userPref: _userPref,
                          onSlotsChanged: (slots) => setState(() => _doseSlots = slots),
                          onNavigateToPrefs: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PreferencesScreen()),
                            );
                            await _loadUserPreferences();
                          },
                        ),
                      const SizedBox(height: 24),

                      _sectionTitle('Son Kullanma Tarihi'),
                      const SizedBox(height: 12),

                      // ── SKT Seçici
                      InkWell(
                        onTap: _pickExpiryDate,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _expiryDate == null
                                  ? Colors.grey.shade300
                                  : colorScheme.primary,
                              width: _expiryDate == null ? 1 : 2,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.grey.shade50,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                color: _expiryDate == null
                                    ? Colors.grey
                                    : colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _expiryDate == null
                                    ? 'Tarih seçmek için dokunun'
                                    : DateFormat('dd MMMM yyyy', 'tr_TR')
                                        .format(_expiryDate!),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _expiryDate == null
                                      ? Colors.grey[600]
                                      : colorScheme.onSurface,
                                  fontWeight: _expiryDate != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // ── Kaydet Butonu
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _onSubmit,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: const Text(
                            'İlacı Kaydet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      );

  /// Saatlik aralıklı sıklık için İlk Doz Saati seçici widget'ı.
  Widget _buildFirstDoseTimePicker() {    final colorScheme = Theme.of(context).colorScheme;
    final intervalHours = _extractIntervalHours(_selectedFrequency ?? '');
    final doseCount = intervalHours != null ? 24 ~/ intervalHours : 0;

    // Önizleme: 08:00 → 16:00 → 00:00
    String preview = '';
    if (_firstDoseTime != null && intervalHours != null) {
      final times = List.generate(doseCount, (i) {
        final totalMin =
            _firstDoseTime!.hour * 60 + _firstDoseTime!.minute + i * intervalHours * 60;
        final hh = (totalMin ~/ 60) % 24;
        final mm = totalMin % 60;
        return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
      });
      preview = times.join(' → ');
    }

    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _firstDoseTime ?? const TimeOfDay(hour: 8, minute: 0),
          helpText: 'İlk Doz Saatini Seçin',
          confirmText: 'Seç',
          cancelText: 'İptal',
        );
        if (picked != null) {
          final hh = picked.hour.toString().padLeft(2, '0');
          final mm = picked.minute.toString().padLeft(2, '0');
          setState(() {
            _firstDoseTime = picked;
            _firstDoseTimeStr = '$hh:$mm'; // DB'ye HH:MM olarak kaydedilir
          });
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: _firstDoseTime == null
                ? Colors.grey.shade300
                : colorScheme.primary,
            width: _firstDoseTime == null ? 1 : 2,
          ),
          borderRadius: BorderRadius.circular(14),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              color: _firstDoseTime == null ? Colors.grey : colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'İlk Doz Saati',
                    style: TextStyle(
                      fontSize: 12,
                      color: _firstDoseTime == null
                          ? Colors.grey[600]
                          : colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _firstDoseTime == null
                        ? 'Saat seçmek için dokunun'
                        : _firstDoseTimeStr!,
                    style: TextStyle(
                      fontSize: 15,
                      color: _firstDoseTime == null
                          ? Colors.grey[600]
                          : colorScheme.onSurface,
                      fontWeight: _firstDoseTime != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Dozlar: $preview',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.primary.withAlpha(180),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.edit_rounded,
              size: 18,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required String hint,
    required IconData icon,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String? Function(T?)? validator,
  }) =>
      DropdownButtonFormField<T>(
        value: value,
        decoration: _inputDecoration(label: label, icon: icon),
        hint: Text(hint),
        items: items
            .map((e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(e.toString()),
                ))
            .toList(),
        onChanged: onChanged,
        validator: validator,
        borderRadius: BorderRadius.circular(14),
      );

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// _DoseSlotEditor — Doz Sayısına Göre Zaman Seçim Alanları
// ──────────────────────────────────────────────────────────────────────────────

class _DoseSlotEditor extends StatefulWidget {
  const _DoseSlotEditor({
    required this.frequency,
    required this.slots,
    required this.userPref,
    required this.onSlotsChanged,
    required this.onNavigateToPrefs,
  });

  final String frequency;
  final List<_DoseSlot> slots;
  final UserPreference? userPref;
  final ValueChanged<List<_DoseSlot>> onSlotsChanged;
  final VoidCallback onNavigateToPrefs;

  @override
  State<_DoseSlotEditor> createState() => _DoseSlotEditorState();
}

class _DoseSlotEditorState extends State<_DoseSlotEditor> {
  late List<_DoseSlot> _slots;
  int get _needed => _doseCountFromFrequency(widget.frequency);

  @override
  void initState() {
    super.initState();
    _slots = List.of(widget.slots);
  }

  @override
  void didUpdateWidget(_DoseSlotEditor old) {
    super.didUpdateWidget(old);
    if (old.frequency != widget.frequency) {
      _slots = [];
      // Build aşamasında üst widget'ın setState'ini tetiklemekten kaçın
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onSlotsChanged([]);
      });
    }
  }

  void _notify() => widget.onSlotsChanged(List.of(_slots));

  Future<void> _pickSlot(int index) async {
    final slot = _slots[index];
    final preset = kLabelPresets[slot.label];

    final picked = await showTimePicker(
      context: context,
      initialTime: slot.effectiveTime,
      helpText: '${slot.label} Saatini Seçin',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    // Anlamsal kontrol
    if (preset != null) {
      final h = picked.hour;
      final valid = h >= preset.minHour && (preset.maxHour == 24 || h < preset.maxHour);
      if (!valid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${slot.label}" için geçersiz saat. '
              '${preset.minHour}:00 – ${preset.maxHour == 24 ? "23:59" : "${preset.maxHour}:00"} '
              'aralığında olmalıdır.',
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _slots[index].overrideTime = picked);
    _notify();
  }

  Future<void> _selectLabel(int index, String label) async {
    // Rutin kontrol
    final requiredField = _requiredRoutineField(label);
    if (requiredField != null) {
      final pref = widget.userPref;
      final fieldValue = pref == null
          ? null
          : switch (requiredField) {
              'breakfastTime' => pref.breakfastTime,
              'lunchTime'     => pref.lunchTime,
              'dinnerTime'    => pref.dinnerTime,
              'bedtime'       => pref.bedtime,
              _               => null,
            };
      if (fieldValue == null && mounted) {
        final fieldLabel = switch (requiredField) {
          'breakfastTime' => 'Kahvaltı Saati',
          'lunchTime'     => 'Öğle Yemeği Saati',
          'dinnerTime'    => 'Akşam Yemeği Saati',
          'bedtime'       => 'Yatış Saati',
          _               => 'Rutin Saat',
        };
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.schedule_rounded, color: Color(0xFFFF8F00), size: 36),
            title: const Text('Rutin Saat Tanımlanmamış'),
            content: Text(
              '"$label" için $fieldLabel profil ayarlarında tanımlanmamış.\n\n'
              'Profil ayarlarına giderek tanımlayabilir ya da varsayılan saat kullanılır.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Varsayılanla Devam Et'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Profil Ayarlarına Git'),
              ),
            ],
          ),
        );
        if (go == true && mounted) {
          widget.onNavigateToPrefs();
          return;
        }
      }
    }
    setState(() => _slots[index] = _DoseSlot(label));
    _notify();
  }

  void _applyCombo(List<String> combo) {
    setState(() {
      _slots = combo.map((l) => _DoseSlot(l)).toList();
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final combos = kSuggestedCombos[_needed];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Başlık
        Text(
          'Doz Zamanları ($_needed doz seçilecek)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),

        // ── Hızlı kombinasyon önerileri
        if (combos != null && _needed > 1) ...[
          Text(
            'Hızlı seçim:',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: combos.map((combo) {
              final label = combo.join(' + ');
              return ActionChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                avatar: const Icon(Icons.auto_awesome_rounded, size: 14),
                onPressed: () => _applyCombo(combo),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // ── Doz slot'ları
        ...List.generate(_needed, (i) {
          final hasSlot = i < _slots.length;
          final slot = hasSlot ? _slots[i] : null;
          final doseLabel = _needed == 1 ? 'Doz' : '${i + 1}. Doz';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doseLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF546E7A),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Etiket seçimi
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: slot?.label,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.label_outline_rounded),
                          labelText: 'Zaman Etiketi',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: slot != null && !slot.isSemanticValid
                                  ? Colors.red
                                  : Colors.grey.shade300,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        hint: const Text('Seçin', style: TextStyle(fontSize: 13)),
                        items: kUsageTimes
                            // Aynı etiket iki kez seçilemesin
                            .where((t) => t == slot?.label || !_slots.any((s) => s.label == t))
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t, style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          if (i < _slots.length) {
                            _selectLabel(i, v);
                          } else {
                            // Yeni slot ekle
                            setState(() => _slots.add(_DoseSlot(v)));
                            _notify();
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Saat seçimi / değiştirme düğmesi
                    if (slot != null)
                      InkWell(
                        onTap: () => _pickSlot(i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: slot.isSemanticValid
                                ? colorScheme.primaryContainer
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: slot.isSemanticValid
                                  ? colorScheme.primary.withAlpha(120)
                                  : Colors.red,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${slot.effectiveTime.hour.toString().padLeft(2, '0')}:'
                                '${slot.effectiveTime.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: slot.isSemanticValid
                                      ? colorScheme.onPrimaryContainer
                                      : Colors.red.shade700,
                                ),
                              ),
                              if (slot.overrideTime != null)
                                Text(
                                  'özelleştirildi',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                // Not etiketi (Yemekten sonra, Aç karnına, vb.)
                if (slot?.note.isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 13, color: colorScheme.secondary),
                      const SizedBox(width: 4),
                      Text(
                        'Not: ${slot!.note}',
                        style: TextStyle(fontSize: 11, color: colorScheme.secondary),
                      ),
                    ],
                  ),
                ],
                // Anlam dışı saat uyarısı
                if (slot != null && !slot.isSemanticValid) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 13, color: Colors.red),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '"${slot.label}" için seçilen saat '
                          '${slot.effectiveTime.hour.toString().padLeft(2, '0')}:${slot.effectiveTime.minute.toString().padLeft(2, '0')} '
                          'mantıksal aralık dışında kalıyor.',
                          style: const TextStyle(fontSize: 11, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),

        // Genel ilerleme göstergesi
        if (_slots.length < _needed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${_slots.length}/$_needed doz zamanı seçildi',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
            ),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Öneri Dropdown — TypeAhead + Infinite Scroll
// ──────────────────────────────────────────────────────────────────────────────

class _SuggestionDropdown extends StatelessWidget {
  const _SuggestionDropdown({
    required this.suggestions,
    required this.isSearching,
    required this.scrollCtrl,
    required this.onSelected,
  });

  final List<GlobalMedication> suggestions;
  final bool isSearching;
  final ScrollController scrollCtrl;
  final ValueChanged<GlobalMedication> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: colorScheme.primary.withAlpha(120)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView.separated(
              controller: scrollCtrl,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: suggestions.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final med = suggestions[index];
                return InkWell(
                  onTap: () => onSelected(med),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.medication_liquid_rounded,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                med.productName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (med.activeIngredient != null)
                                Text(
                                  med.activeIngredient!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (med.atcCode != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              med.atcCode!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Sonsuz kaydırma yükleme göstergesi
          if (isSearching && suggestions.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Seçili İlaç Bilgi Çipi — Modül 3 metadata göstergesi
// ──────────────────────────────────────────────────────────────────────────────

class _SelectedMedChip extends StatelessWidget {
  const _SelectedMedChip({required this.med});
  final GlobalMedication med;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(180),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.primary.withAlpha(80),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (med.activeIngredient != null)
                  _InfoBadge(
                    label: 'Etkin Madde',
                    value: med.activeIngredient!,
                    color: colorScheme,
                  ),
                if (med.atcCode != null)
                  _InfoBadge(
                    label: 'ATC',
                    value: med.atcCode!,
                    color: colorScheme,
                  ),
                if (med.barcode != null)
                  _InfoBadge(
                    label: 'Barkod',
                    value: med.barcode!,
                    color: colorScheme,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final ColorScheme color;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 11, color: color.onSurface),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionWarningCard extends StatelessWidget {
  const _InteractionWarningCard({
    required this.warnings,
    required this.onConfirm,
    required this.onCancel,
    required this.isBusy,
  });

  final List<InteractionWarning> warnings;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD32F2F), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F)),
              const SizedBox(width: 8),
              const Text(
                'Etkileşim Uyarısı',
                style: TextStyle(
                  color: Color(0xFFB71C1C),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '• ${warning.withMedicationName} ile etkileşim tespit edildi: Mevcut tedavinizle birlikte kullanımı risk oluşturabilir. Lütfen doktorunuza danışın.',
                style: const TextStyle(
                  color: Color(0xFF7F0000),
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: isBusy ? null : onCancel,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Vazgeç'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: isBusy ? null : onConfirm,
                icon: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: const Text(
                  'Yine de Kaydet',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
