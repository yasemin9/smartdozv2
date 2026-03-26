/// SmartDoz - Profil Sekmesi
///
/// Kullanıcı bilgileri + ZAMANDILIMIHESAPLA tercihleri + çıkış.
/// EK1_revize.pdf s.27 — Evrensel Tasarım: büyük butonlar, net etiketler.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import 'adherence_screen.dart';
import 'login_screen.dart';
import 'preferences_screen.dart';

// ── Renk sabitleri
const _kPrimary  = Color(0xFF1565C0);
const _kDanger   = Color(0xFFC62828);
const _kBg       = Color(0xFFF0F4FF);
const _kTextDark = Color(0xFF0D1B2A);
const _kTextMid  = Color(0xFF455A64);

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Çıkış Yap',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Hesabınızdan çıkmak istediğinize emin misiniz?',
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
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<ApiService>().logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<ApiService>().currentUser;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.person_rounded, size: 22),
            SizedBox(width: 8),
            Text('Profilim',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Kullanıcı Bilgi Kartı ─────────────────────────────
          _UserInfoCard(
            firstName: user?.firstName ?? '',
            lastName: user?.lastName ?? '',
            email: user?.email ?? '',
          ),

          const SizedBox(height: 24),

          // ── Ayarlar Bölümü ────────────────────────────────────
          const _SectionLabel(label: '⚙️  Uygulama Ayarları'),
          const SizedBox(height: 10),

          _SettingsTile(
            icon: Icons.tune_rounded,
            iconColor: _kPrimary,
            title: 'Hatırlatıcı Saatleri',
            subtitle: 'Uyanma ve uyku saatlerinizi düzenleyin\n'
                '(ZAMANDILIMIHESAPLA algoritması)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PreferencesScreen()),
            ),
          ),
          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.show_chart_rounded,
            iconColor: Colors.indigo,
            title: 'Uyum Geçmişim',
            subtitle: 'Haftalık MPR grafiği ve davranışsal sapma analizi',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdherenceScreen()),
            ),
          ),
          const SizedBox(height: 24),

          // ── Uygulama Hakkında ─────────────────────────────────
          const _SectionLabel(label: 'ℹ️  Hakkında'),
          const SizedBox(height: 10),

          const _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: _kTextMid,
            title: 'SmartDoz v2.0.0',
            subtitle: 'Akıllı İlaç Takip Sistemi\nEK1_revize.pdf mimarisine uygun',
            onTap: null,
          ),

          const SizedBox(height: 32),

          // ── Çıkış Butonu ──────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Hesabımdan Çık',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kDanger,
                side: const BorderSide(color: _kDanger, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kullanıcı Bilgi Kartı ─────────────────────────────────────────

class _UserInfoCard extends StatelessWidget {
  final String firstName;
  final String lastName;
  final String email;
  const _UserInfoCard({
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  String get _initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty  ? lastName[0].toUpperCase()  : '';
    return '$f$l';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x401565C0),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              child: Text(
                _initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 20),
            // İsim & e-posta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$firstName $lastName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '✓  Aktif Kullanıcı',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ── Bölüm Etiketi ─────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _kTextMid,
          letterSpacing: 0.3,
        ),
      );
}

// ── Ayar Satırı ───────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kTextDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kTextMid,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.grey),
              ],
            ),
          ),
        ),
      );
}
