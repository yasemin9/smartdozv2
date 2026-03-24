/// SmartDoz - Ana Uygulama Kabuğu (Modül 1 + 2)
///
/// 4 sekmeli NavigationBar ile tüm ekranları yönetir.
/// IndexedStack sayesinde sekme geçişlerinde state (scroll, yüklü veri)
/// korunur — kullanıcı her seferinde yeniden yükleme beklemiyor.
///
/// Sekmeler:
///   0 → DashboardTab   – Günün özeti & çizelgesi
///   1 → CalendarScreen – Aylık & geçmiş takvim
///   2 → MedicationsTab – İlaç listesi & ekleme
///   3 → ProfileTab     – Kullanıcı & tercihler
import 'package:flutter/material.dart';

import 'calendar_screen.dart';
import 'dashboard_tab.dart';
import 'medications_tab.dart';
import 'profile_tab.dart';

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
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
