/// SmartDoz – Profil Sekmesi
///
/// Kullanıcı bilgileri, 30 günlük uyum skoru, uygulama ayarları,
/// kurumsal hakkında bölümü ve çıkış.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import 'adherence_screen.dart';
import 'login_screen.dart';
import 'preferences_screen.dart';

// ── Renk sabitleri ─────────────────────────────────────────────────
const _kPrimary  = Color(0xFF1565C0);
const _kDanger   = Color(0xFFC62828);
const _kBg       = Color(0xFFF0F4FF);
const _kTextDark = Color(0xFF0D1B2A);
const _kTextMid  = Color(0xFF455A64);

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  double? _adherenceScore;

  @override
  void initState() {
    super.initState();
    _loadAdherence();
  }

  Future<void> _loadAdherence() async {
    try {
      final summary =
          await context.read<ApiService>().getAdherenceSummary(days: 30);
      if (mounted) setState(() => _adherenceScore = summary.adherenceScore);
    } catch (_) {
      // Skor alınamazsa ilerleme çubuğu gizli kalır.
    }
  }

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
            Text('Profilim', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Kullanıcı Bilgi Kartı ──────────────────────────────
          _UserInfoCard(
            firstName: user?.firstName ?? '',
            lastName: user?.lastName ?? '',
            email: user?.email ?? '',
            adherenceScore: _adherenceScore,
          ),

          const SizedBox(height: 24),

          // ── Ayarlar Bölümü ─────────────────────────────────────
          const _SectionLabel(label: '⚙️  Uygulama Ayarları'),
          const SizedBox(height: 10),

          _SettingsTile(
            icon: Icons.tune_rounded,
            iconColor: _kPrimary,
            title: 'Hatırlatıcı Saatleri',
            subtitle:
                'Uyanma ve uyku saatlerinize göre kişiselleştirilmiş hatırlatıcılar',
            semanticLabel: 'Hatırlatıcı saatlerini düzenle',
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
            subtitle:
                'Haftalık ilaç uyum grafiği ve kişisel davranış analiziniz',
            semanticLabel: 'Uyum geçmişini görüntüle',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdherenceScreen()),
            ),
          ),

          const SizedBox(height: 24),

          // ── Hakkında ───────────────────────────────────────────
          const _SectionLabel(label: 'ℹ️  Hakkında'),
          const SizedBox(height: 10),

          const _AboutCard(),

          const SizedBox(height: 32),

          // ── Çıkış Butonu ───────────────────────────────────────
          Semantics(
            label: 'Hesabımdan çık',
            button: true,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text(
                  'Hesabımdan Çık',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kDanger,
                  side: const BorderSide(color: _kDanger, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: _kDanger.withValues(alpha: 0.04),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
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
  final double? adherenceScore;

  const _UserInfoCard({
    required this.firstName,
    required this.lastName,
    required this.email,
    this.adherenceScore,
  });

  String get _initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty  ? lastName[0].toUpperCase()  : '';
    return '$f$l';
  }

  Color get _scoreColor {
    if (adherenceScore == null) return Colors.white54;
    if (adherenceScore! >= 0.80) return const Color(0xFF69F0AE);
    if (adherenceScore! >= 0.50) return const Color(0xFFFFD740);
    return const Color(0xFFFF6E6E);
  }

  String get _scoreLabel {
    if (adherenceScore == null) return 'Hesaplanıyor…';
    final pct = (adherenceScore! * 100).round();
    if (adherenceScore! >= 0.80) return '$pct% — Yüksek Uyum';
    if (adherenceScore! >= 0.50) return '$pct% — Orta Uyum';
    return '$pct% — Düşük Uyum';
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Kullanıcı profil kartı. $firstName $lastName. $email. '
            '30 günlük uyum skoru: $_scoreLabel.',
        child: Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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

              // ── 30 Günlük Uyum Skoru ─────────────────────────
              const SizedBox(height: 20),
              const Divider(color: Colors.white24, thickness: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '30 Günlük Uyum Skoru',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _scoreLabel,
                    style: TextStyle(
                      color: _scoreColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: adherenceScore ?? 0.0,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(_scoreColor),
                ),
              ),
            ],
          ),
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
  final String semanticLabel;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.semanticLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        button: onTap != null,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: iconColor, size: 26),
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
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kTextMid,
                              height: 1.45,
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
          ),
        ),
      );
}

// ── Hakkında Kartı ────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'SmartDoz hakkında bilgi',
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık satırı
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.local_pharmacy_rounded,
                        color: _kPrimary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SmartDoz',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _kTextDark,
                          ),
                        ),
                        Text(
                          'Yapay Zekâ Destekli Akıllı İlaç Takip Sistemi',
                          style: TextStyle(
                            fontSize: 12,
                            color: _kTextMid,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: Color(0xFFEEEEEE)),
              const SizedBox(height: 14),

              // Akademik köken
              const Text(
                'Ondokuz Mayıs Üniversitesi Bilgisayar Mühendisliği Bölümü '
                'bünyesinde geliştirilen, yapay zekâ destekli akademik bir '
                'ilaç yönetim projesidir.',
                style: TextStyle(
                  fontSize: 13,
                  color: _kTextMid,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 18),

              // Özellik modülleri
              const _AboutFeature(
                icon: Icons.security_rounded,
                color: Color(0xFF2E7D32),
                title: 'İlaç Güvenliği',
                description:
                    'TİTCK verileriyle entegre, etken madde bazlı ilaç '
                    'etkileşim analizi (DDI).',
              ),
              const SizedBox(height: 12),
              const _AboutFeature(
                icon: Icons.psychology_alt_rounded,
                color: Color(0xFF6A1B9A),
                title: 'Yapay Zekâ',
                description:
                    'Karmaşık prospektüsleri sadeleştiren NLP ve ilaç '
                    'kutularını tanıyan OCR teknolojisi.',
              ),
              const SizedBox(height: 12),
              const _AboutFeature(
                icon: Icons.accessibility_new_rounded,
                color: Color(0xFF00695C),
                title: 'Erişilebilirlik',
                description:
                    'Görme engelli ve yaşlı kullanıcılar için evrensel '
                    'tasarım ve sesli asistan desteği.',
              ),

              const SizedBox(height: 18),
              const Divider(color: Color(0xFFEEEEEE)),
              const SizedBox(height: 14),

              // Ekip ve danışman
              const _TeamSection(),
            ],
          ),
        ),
      );
}

// ── Özellik Satırı ────────────────────────────────────────────────

class _AboutFeature extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _AboutFeature({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kTextMid,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

// ── Ekip Bölümü ───────────────────────────────────────────────────

class _TeamSection extends StatelessWidget {
  const _TeamSection();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GELİŞTİRME EKİBİ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kTextMid,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          _teamMember('Rabia GÜLEÇ'),
          _teamMember('Esra Eser AKKURT'),
          _teamMember('Yasemin DELİCAN'),
          const SizedBox(height: 12),
          const Text(
            'DANIŞMAN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kTextMid,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          _teamMember('Prof. Dr. Erdal KILIÇ', isAdvisor: true),
        ],
      );

  Widget _teamMember(String name, {bool isAdvisor = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              isAdvisor
                  ? Icons.school_rounded
                  : Icons.person_outline_rounded,
              size: 17,
              color: isAdvisor ? _kPrimary : _kTextMid,
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                color: isAdvisor ? _kPrimary : _kTextDark,
                fontWeight:
                    isAdvisor ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}
