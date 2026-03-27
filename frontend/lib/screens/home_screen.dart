// SmartDoz - Ana Uygulama Kabuğu (Modül 1–8)
//
// 5 sekmeli NavigationBar ile tüm ekranları yönetir.
// IndexedStack sayesinde sekme geçişlerinde state (scroll, yüklü veri)
// korunur — kullanıcı her seferinde yeniden yükleme beklemiyor.
//
// Sekmeler:
//   0 → DashboardTab    – Günün özeti & çizelgesi
//   1 → CalendarScreen  – Aylık & geçmiş takvim
//   2 → MedicationsTab  – İlaç listesi & ekleme
//   3 → AIProfileScreen – Modül 8: YZ Akıllı Profil & Kararlar
//   4 → ProfileTab      – Kullanıcı & tercihler
// Modül 6: FAB → VoiceAssistantScreen
import 'package:flutter/material.dart';

import 'ai_profile_screen.dart';
import 'calendar_screen.dart';
import 'dashboard_tab.dart';
import 'medications_tab.dart';
import 'profile_tab.dart';
import 'voice_assistant_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // GlobalKey: ilaç eklenince DashboardTab'ı yenilemek için
  final _dashboardKey = GlobalKey<DashboardTabState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardTab(key: _dashboardKey),
      const CalendarScreen(),
      MedicationsTab(onGoHome: () {
        setState(() => _currentIndex = 0);
        // Yeni ilaç eklendi → bugünün doz çizelgesini yenile
        _dashboardKey.currentState?.refresh();
      }),
      const AIProfileScreen(),
      const ProfileTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack: her sekme görünmese de hafızada canlı kalır → state korunur
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      // ── Modül 6: Sesli Asistan FAB (İlaçlarım sekmesinde gizlenir) ────────
      floatingActionButton: _currentIndex == 2
          ? null
          : Semantics(
              label: 'Sesli asistanı aç',
              hint: 'Sesli komut vermek için düğmeye dokunun',
              button: true,
              child: FloatingActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VoiceAssistantScreen(),
                  ),
                ),
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                tooltip: 'Sesli Asistan',
                child: const Icon(Icons.mic_rounded, size: 28),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: Colors.white,
        elevation: 6,
        shadowColor: Colors.black26,
        indicatorColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Takvim',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication_rounded),
            label: 'İlaçlarım',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology_rounded),
            label: 'Akıllı',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
