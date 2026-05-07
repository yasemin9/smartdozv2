/// SmartDoz - İlaç Hatırlatma Diyalogu
///
/// Kullanıcı ilaç zamanı bildirimine tıkladığında açılan dialog.
/// Alındı, Alınmadı, Ertele seçeneklerini gösterir.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/dose_log.dart';
import '../services/api_service.dart';

const _kPrimary = Color(0xFF1976D2);
const _kSuccess = Color(0xFF2E7D32);
const _kWarning = Color(0xFFF57F17);
const _kDanger = Color(0xFFC62828);
const _kBg = Color(0xFFF5F5F5);

class MedicationReminderDialog extends StatefulWidget {
  final int doseLogId;
  final String medicationName;
  final String dosageForm;
  final DateTime scheduledTime;
  final VoidCallback? onClose;

  const MedicationReminderDialog({
    super.key,
    required this.doseLogId,
    required this.medicationName,
    required this.dosageForm,
    required this.scheduledTime,
    this.onClose,
  });

  @override
  State<MedicationReminderDialog> createState() =>
      _MedicationReminderDialogState();
}

class _MedicationReminderDialogState extends State<MedicationReminderDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleAction(String status, {int? snoozeMins}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = context.read<ApiService>();

      if (snoozeMins != null) {
        // Erteleme işlemi
        await apiService.snoozeDose(widget.doseLogId, snoozeMins);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$snoozeMins dakika sonra hatırlanacaksınız.'),
              backgroundColor: _kWarning,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
          widget.onClose?.call();
        }
      } else {
        // Alındı/Alınmadı işlemi
        await apiService.updateDoseStatus(widget.doseLogId, status);
        if (mounted) {
          final message = status == 'Alındı'
              ? '${widget.medicationName} alındı olarak işaretlendi.'
              : '${widget.medicationName} alınmadı olarak işaretlendi.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor:
                  status == 'Alındı' ? _kSuccess : _kDanger,
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop();
          widget.onClose?.call();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'İşlem başarısız: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduledTimeStr = DateFormat('HH:mm').format(widget.scheduledTime);
    final now = DateTime.now();
    final isOverdue =
        widget.scheduledTime.isBefore(now) &&
        now.difference(widget.scheduledTime).inMinutes > 5;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Başlık
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOverdue
                        ? _kDanger.withOpacity(0.1)
                        : _kPrimary.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.medication,
                    size: 32,
                    color: isOverdue ? _kDanger : _kPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '💊 İlaç Zamanı',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF455A64),
                      ),
                ),
                const SizedBox(height: 8),

                // İlaç adı
                Text(
                  widget.medicationName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D1B2A),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Uyarı: Gecikmeli doz
                if (isOverdue)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kDanger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _kDanger.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: _kDanger, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bu ilaç zamanını geçmiş!',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: _kDanger,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Bilgi: Doz formu ve saat
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Doz Formu:',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: const Color(0xFF455A64),
                                ),
                          ),
                          Text(
                            widget.dosageForm,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0D1B2A),
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Planlanan Saat:',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: const Color(0xFF455A64),
                                ),
                          ),
                          Text(
                            scheduledTimeStr,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: _kPrimary,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Hata mesajı
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kDanger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _kDanger.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _kDanger,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Butonlar
                Column(
                  children: [
                    // Alındı - Yeşil
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isLoading ? null : () => _handleAction('Alındı'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kSuccess,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              _kSuccess.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle, size: 20),
                        label: Text(
                          _isLoading ? 'İşleniyor...' : '✓ Aldım',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Alınmadı - Kırmızı
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _isLoading ? null : () => _handleAction('Atlandı'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kDanger,
                          disabledForegroundColor: _kDanger.withOpacity(0.5),
                          side: BorderSide(
                            color: _kDanger.withOpacity(0.5),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.close_circle, size: 20),
                        label: const Text(
                          '✗ Almadım',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Ertele - Çok seçenekli
                    _SnoozeOptions(
                      isLoading: _isLoading,
                      onSnooze: _handleAction,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Ertele Seçenekleri ────────────────────────────────────

class _SnoozeOptions extends StatefulWidget {
  final bool isLoading;
  final Function(String, {int? snoozeMins}) onSnooze;

  const _SnoozeOptions({
    required this.isLoading,
    required this.onSnooze,
  });

  @override
  State<_SnoozeOptions> createState() => _SnoozeOptionsState();
}

class _SnoozeOptionsState extends State<_SnoozeOptions> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.isLoading
                ? null
                : () {
                    setState(() => _expanded = !_expanded);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kWarning,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _kWarning.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
            ),
            label: Text(
              _expanded ? '⏲ Erteleme Seçenekleri' : '⏲ Ertele',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                _SnoozeButton(
                  minutes: 5,
                  isLoading: widget.isLoading,
                  onPressed: () => widget.onSnooze('', snoozeMins: 5),
                ),
                const SizedBox(height: 6),
                _SnoozeButton(
                  minutes: 10,
                  isLoading: widget.isLoading,
                  onPressed: () => widget.onSnooze('', snoozeMins: 10),
                ),
                const SizedBox(height: 6),
                _SnoozeButton(
                  minutes: 15,
                  isLoading: widget.isLoading,
                  onPressed: () => widget.onSnooze('', snoozeMins: 15),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SnoozeButton extends StatelessWidget {
  final int minutes;
  final bool isLoading;
  final VoidCallback onPressed;

  const _SnoozeButton({
    required this.minutes,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _kWarning,
          disabledForegroundColor: _kWarning.withOpacity(0.5),
          side: BorderSide(
            color: _kWarning.withOpacity(0.5),
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          '$minutes dakika sonra hatırla',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
