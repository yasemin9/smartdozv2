/// SmartDoz - İlaç Ekleme Formu
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/global_medication.dart';
import '../models/medication.dart';
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

/// Kullanım zamanı önerileri
const List<String> kUsageTimes = [
  'Sabah',
  'Öğle',
  'Akşam',
  'Yatmadan önce',
  'Yemekten önce',
  'Yemekten sonra',
  'Aç karnına',
];

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

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
  String? _selectedUsageTime;
  DateTime? _expiryDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
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

    setState(() => _isLoading = true);

    try {
      final medication = Medication(
        name: _nameController.text.trim(),
        dosageForm: _selectedDosageForm!,
        usageFrequency: _selectedFrequency!,
        usageTime: _selectedUsageTime!,
        expiryDate: _expiryDate!,
      );

      await context.read<ApiService>().createMedication(medication);

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
                        onChanged: (v) =>
                            setState(() => _selectedFrequency = v),
                        validator: (v) =>
                            v == null ? 'Kullanım sıklığı seçiniz.' : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Kullanım Zamanı
                      _buildDropdown<String>(
                        label: 'Kullanım Zamanı',
                        hint: 'Seçin',
                        icon: Icons.access_time_rounded,
                        value: _selectedUsageTime,
                        items: kUsageTimes,
                        onChanged: (v) =>
                            setState(() => _selectedUsageTime = v),
                        validator: (v) =>
                            v == null ? 'Kullanım zamanı seçiniz.' : null,
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
