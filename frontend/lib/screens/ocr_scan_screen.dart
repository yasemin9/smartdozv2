// SmartDoz — Modül 4: Barkod Destekli Otomatik İlaç Tanıma Ekranı
//
// Pipeline (UI tarafı):
//   1. Kullanıcı "Kamera ile Tara" veya "Galeriden Seç" butonuna basar.
//   2. image_picker ile görüntü alınır ve önizleme gösterilir.
//   3. "Analiz Et" butonuna basılınca görüntü backend'e yüklenir.
//   4. Backend barkodu okur ve veritabanında kesin eşleştirme yapar.
//   5. Başarılı: İlaç adıyla AddMedicationScreen'e git.
//   6. Başarısız: Hata mesajı göster, elle ilaç ekleme seçeneği sun.
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/barcode_result.dart';
import '../models/global_medication.dart';
import '../services/api_service.dart';
import 'add_medication_screen.dart';

// ── Renk sabitleri (uygulama genelindeki palet)
const _kPrimary = Color(0xFF1565C0);
const _kSuccess = Color(0xFF2E7D32);
const _kWarning = Color(0xFFE65100);
const _kDanger = Color(0xFFC62828);
const _kBg = Color(0xFFF0F4FF);
const _kTextDark = Color(0xFF0D1B2A);
const _kTextMid = Color(0xFF455A64);

class OcrScanScreen extends StatefulWidget {
  const OcrScanScreen({super.key});

  @override
  State<OcrScanScreen> createState() => _OcrScanScreenState();
}

class _OcrScanScreenState extends State<OcrScanScreen> {
  final _picker = ImagePicker();

  Uint8List? _imageBytes;
  String? _imageFileName;
  String? _imageMimeType;

  bool _isLoading = false;
  BarcodeMatchResult? _result;

  // ── Görüntü seçimi ─────────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    // Flutter Web'de kamera doğrudan desteklenmez (yalnızca mobil tarayıcılarda çalışır)
    if (kIsWeb && source == ImageSource.camera) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Kamera erişimi yalnızca mobil cihazlarda desteklenir. '
            'Lütfen "Galeri" ile fotoğraf seçin.',
          ),
          backgroundColor: _kWarning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() {
      _result = null;
    });

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final name = picked.name;
      final mime = picked.mimeType ?? _mimeFromName(name);

      setState(() {
        _imageBytes = bytes;
        _imageFileName = name;
        _imageMimeType = mime;
      });
    } catch (e) {
      _showError('Görüntü seçilemedi: $e');
    }
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  // ── Barkod analizi ─────────────────────────────────────────────────────────

  Future<void> _analyzeImage() async {
    if (_imageBytes == null) return;

    setState(() => _isLoading = true);

    try {
      final api = context.read<ApiService>();
      final result = await api.scanMedication(
        imageBytes: _imageBytes!,
        fileName: _imageFileName ?? 'scan.jpg',
        mimeType: _imageMimeType ?? 'image/jpeg',
      );

      setState(() => _result = result);

      if (result.found && result.medicationName != null) {
        // ✅ Başarılı — ilaç bulundu
        if (mounted) {
          _showSuccess('✅ ${result.message}');
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            GlobalMedication? matchedMedication;
            if (result.medicationId != null) {
              try {
                matchedMedication = await api.getGlobalMedicationById(result.medicationId!);
              } catch (_) {
                // Barkod eşleşmesi başarılı olsa da detay çekimi başarısız olabilir.
                // Bu durumda isim ile devam ediyoruz.
              }
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AddMedicationScreen(
                  prefillName: result.medicationName!,
                  prefillGlobalMedication: matchedMedication,
                ),
              ),
            );
          }
        }
      } else {
        // ❌ Başarısız — ilaç bulunamadı
        _showErrorDialog(
          title: 'Barkod Okunamadı',
          message: result.message,
          onAddManually: () {
            Navigator.pop(context);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const AddMedicationScreen(),
              ),
            );
          },
        );
      }
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Analiz sırasında hata: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _kSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _kDanger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorDialog({
    required String title,
    required String message,
    required VoidCallback onAddManually,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(color: _kDanger, fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Geri'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              onAddManually();
            },
            icon: const Icon(Icons.add),
            label: const Text('Elle Ekle'),
          ),
        ],
      ),
    );
  }

  // ── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.document_scanner_rounded, size: 22),
            SizedBox(width: 8),
            Text(
              'OCR İlaç Tanıma',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Açıklama kartı ────────────────────────────────────────────
            _InfoCard(),
            const SizedBox(height: 20),

            // ── Görüntü önizleme alanı ────────────────────────────────────
            _ImagePreview(imageBytes: _imageBytes),
            const SizedBox(height: 20),

            // ── Kaynak seçim butonları ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _PickerButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Kamera',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Galeri',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Analiz butonu ─────────────────────────────────────────────
            FilledButton.icon(
              onPressed: (_imageBytes != null && !_isLoading)
                  ? _analyzeImage
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: _kSuccess,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.analytics_rounded),
              label: Text(
                _isLoading ? 'Analiz ediliyor...' : 'Analiz Et',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Alt bileşenler
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.25)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _kPrimary, size: 20),
              SizedBox(width: 8),
              Text(
                'Nasıl çalışır?',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _kPrimary,
                    fontSize: 15),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            '1. İlaç kutusunun fotoğrafını çekin veya galeriden seçin.\n'
            '2. "Analiz Et" butonuna basın.\n'
            '3. Sistem Levenshtein algoritmasıyla en yakın ilaç adını bulur.\n'
            '4. Önerilen eşleşmeyi onaylayın — ilaç kaydı otomatik dolar.',
            style: TextStyle(
                fontSize: 13, color: _kTextMid, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final Uint8List? imageBytes;
  const _ImagePreview({required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageBytes != null
          ? Image.memory(imageBytes!, fit: BoxFit.contain)
          : const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.medication_liquid_rounded,
                      size: 52, color: Color(0xFFB0BEC5)),
                  SizedBox(height: 10),
                  Text(
                    'Görüntü seçilmedi',
                    style: TextStyle(color: Color(0xFF90A4AE), fontSize: 14),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _kPrimary,
        side: const BorderSide(color: _kPrimary),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _OcrRawTextCard extends StatelessWidget {
  final String text;
  const _OcrRawTextCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OCR Ham Metin',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: _kTextMid,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 13, color: _kTextDark),
          ),
        ],
      ),
    );
  }
}
