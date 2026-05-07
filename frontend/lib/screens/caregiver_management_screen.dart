/// SmartDoz - Bakıcı Yönetimi Ekranı
///
/// Kullanıcının bakıcılarını eklemek, görmek, güncellemek ve silmek
/// için tam bir yönetim arayüzü.
library;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/caregiver.dart';
import '../services/api_service.dart';

const _kPrimary = Color(0xFF1565C0);
const _kSuccess = Color(0xFF2E7D32);
const _kDanger = Color(0xFFC62828);
const _kBg = Color(0xFFF0F4FF);
const _kTextDark = Color(0xFF0D1B2A);
const _kTextMid = Color(0xFF455A64);

class CaregiverManagementScreen extends StatefulWidget {
  const CaregiverManagementScreen({super.key});

  @override
  State<CaregiverManagementScreen> createState() =>
      _CaregiverManagementScreenState();
}

class _CaregiverManagementScreenState extends State<CaregiverManagementScreen> {
  List<Caregiver> _caregivers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCaregivers();
  }

  Future<void> _loadCaregivers() async {
    setState(() => _isLoading = true);
    try {
      final caregivers = await context.read<ApiService>().getCaregivers();
      if (mounted) {
        setState(() => _caregivers = caregivers);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: _kDanger,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _addCaregiverDialog() async {
    final emailController = TextEditingController();
    final relationshipController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Bakıcı Ekle',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Bakıcı Email',
                  hintText: 'Örn: bakici@example.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: relationshipController.text.isEmpty
                    ? 'caregiver'
                    : relationshipController.text,
                items: const [
                  DropdownMenuItem(value: 'caregiver', child: Text('Bakıcı')),
                  DropdownMenuItem(value: 'parent', child: Text('Ebeveyn')),
                  DropdownMenuItem(value: 'child', child: Text('Çocuk')),
                  DropdownMenuItem(value: 'spouse', child: Text('Eş')),
                  DropdownMenuItem(value: 'doctor', child: Text('Doktor')),
                ]
                    .map((item) => DropdownMenuItem(
                          value: item.value,
                          child: item.child,
                        ))
                    .toList(),
                onChanged: (value) {
                  relationshipController.text = value ?? 'caregiver';
                },
                decoration: InputDecoration(
                  labelText: 'İlişki Tipi',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _kSuccess),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (result == true && emailController.text.isNotEmpty) {
      try {
        await context.read<ApiService>().addCaregiver(
              caregiverEmail: emailController.text.trim(),
              relationshipType:
                  relationshipController.text.isEmpty
                      ? 'caregiver'
                      : relationshipController.text,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Bakıcı eklendi'),
              backgroundColor: _kSuccess,
            ),
          );
          _loadCaregivers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: _kDanger,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeCaregiver(int caregiverId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Bakıcıyı Sil',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Bu bakıcıyı silmek istediğinize emin misiniz?',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _kDanger),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<ApiService>().removeCaregiver(caregiverId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Bakıcı silindi'),
              backgroundColor: _kSuccess,
            ),
          );
          _loadCaregivers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: _kDanger,
            ),
          );
        }
      }
    }
  }

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
            Icon(Icons.people_rounded, size: 22),
            SizedBox(width: 8),
            Text(
              'Bakıcı Yönetimi',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addCaregiverDialog,
              tooltip: 'Bakıcı Ekle',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _caregivers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: _kTextMid.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Henüz bakıcı eklememişsiniz',
                        style: TextStyle(
                          fontSize: 16,
                          color: _kTextMid,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _addCaregiverDialog,
                        style: FilledButton.styleFrom(
                          backgroundColor: _kPrimary,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Bakıcı Ekle'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _caregivers.length,
                  itemBuilder: (context, index) {
                    final caregiver = _caregivers[index];
                    return _CaregiverCard(
                      caregiver: caregiver,
                      onRemove: () => _removeCaregiver(caregiver.id),
                    );
                  },
                ),
    );
  }
}

/// Bakıcı kartı widget'ı
class _CaregiverCard extends StatelessWidget {
  final Caregiver caregiver;
  final VoidCallback onRemove;

  const _CaregiverCard({
    required this.caregiver,
    required this.onRemove,
  });

  String _getRelationshipLabel(String type) {
    const labels = {
      'caregiver': '👨‍⚕️ Bakıcı',
      'parent': '👨‍👩‍👧 Ebeveyn',
      'child': '👧 Çocuk',
      'spouse': '💑 Eş',
      'doctor': '👨‍⚕️ Doktor',
    };
    return labels[type] ?? type;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caregiver.caregiverName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _kTextDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        caregiver.caregiverEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kTextMid,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: caregiver.isActive
                        ? _kSuccess.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    caregiver.isActive ? '🟢 Aktif' : '🔴 Pasif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: caregiver.isActive ? _kSuccess : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getRelationshipLabel(caregiver.relationshipType),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _kPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onRemove,
                  style: TextButton.styleFrom(
                    foregroundColor: _kDanger,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Sil'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
