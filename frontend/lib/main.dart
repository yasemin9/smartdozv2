/// SmartDoz - Uygulama Giriş Noktası
///
/// Provider ile ApiService global durumu sağlar.
/// Oturum durumuna göre Login veya Dashboard ekranı gösterilir.
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Türkçe tarih formatı için intl locale başlatması
  await initializeDateFormatting('tr_TR', null);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ApiService(),
      child: const SmartDozApp(),
    ),
  );
}

class SmartDozApp extends StatelessWidget {
  const SmartDozApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartDoz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
      // Oturum durumuna göre ekran seçimi
      home: Consumer<ApiService>(
        builder: (context, apiService, _) {
          if (apiService.isAuthenticated) {
            return const DashboardScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
