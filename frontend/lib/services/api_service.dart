/// SmartDoz - API Servis Katmanı
///
/// Tüm HTTP isteklerini yönetir. ChangeNotifier ile Provider
/// entegrasyonu sağlar; oturum durumu değiştiğinde UI güncellenir.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dose_log.dart';
import '../models/global_medication.dart';
import '../models/medication.dart';
import '../models/user.dart';
import '../models/user_preference.dart';

/// Uygulama içinde tek bir noktada API base URL'ini yönetir.
/// Flutter Web için backend adresi.
const String _kBaseUrl = 'http://localhost:8000';
const String _kTokenKey = 'smartdoz_access_token';

class ApiService extends ChangeNotifier {
  String? _token;
  User? _currentUser;

  bool get isAuthenticated => _token != null;
  User? get currentUser => _currentUser;

  ApiService() {
    _restoreSession();
  }

  // ────────────────────────────────────────────────────
  // Oturum Yönetimi
  // ────────────────────────────────────────────────────

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_kTokenKey);
    if (_token != null) {
      try {
        _currentUser = await _fetchMe();
      } catch (_) {
        // Token geçersizse oturumu temizle
        await _clearSession(prefs);
      }
    }
    notifyListeners();
  }

  Future<void> _persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
    _token = token;
  }

  Future<void> _clearSession([SharedPreferences? prefs]) async {
    prefs ??= await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    _token = null;
    _currentUser = null;
  }

  Future<void> logout() async {
    await _clearSession();
    notifyListeners();
  }

  // ────────────────────────────────────────────────────
  // Ortak yardımcılar
  // ────────────────────────────────────────────────────

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// HTTP yanıt gövdesini UTF-8 ile decode eder ve JSON parse eder.
  dynamic _parseBody(http.Response response) =>
      jsonDecode(utf8.decode(response.bodyBytes));

  /// 401 durumunda oturumu sonlandırır ve istisna fırlatır.
  Future<void> _handleUnauthorized() async {
    await _clearSession();
    notifyListeners();
    throw const ApiException('Oturum süresi doldu. Lütfen tekrar giriş yapın.');
  }

  // ────────────────────────────────────────────────────
  // Kimlik Doğrulama
  // ────────────────────────────────────────────────────

  /// Yeni kullanıcı kaydı oluşturur.
  Future<User> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_kBaseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
      }),
    );

    final data = _parseBody(response);
    if (response.statusCode == 201) {
      return User.fromJson(data as Map<String, dynamic>);
    }
    throw ApiException(_extractDetail(data));
  }

  /// Kullanıcı girişi yapar ve token'ı saklar.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_kBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = _parseBody(response);
    if (response.statusCode == 200) {
      await _persistToken(data['access_token'] as String);
      _currentUser = await _fetchMe();
      notifyListeners();
      return;
    }
    throw ApiException(_extractDetail(data));
  }

  /// Oturumdaki kullanıcı bilgisini backend'den çeker.
  Future<User> _fetchMe() async {
    final response = await http.get(
      Uri.parse('$_kBaseUrl/auth/me'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      return User.fromJson(_parseBody(response) as Map<String, dynamic>);
    }
    throw const ApiException('Kullanıcı bilgisi alınamadı.');
  }

  // ────────────────────────────────────────────────────
  // İlaç İşlemleri
  // ────────────────────────────────────────────────────

  /// Kullanıcıya ait ilaç listesini döner.
  Future<List<Medication>> getMedications() async {
    final response = await http.get(
      Uri.parse('$_kBaseUrl/medications/'),
      headers: _authHeaders,
    );

    if (response.statusCode == 200) {
      final list = _parseBody(response) as List<dynamic>;
      return list
          .map((e) => Medication.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (response.statusCode == 401) await _handleUnauthorized();
    throw const ApiException('İlaçlar yüklenemedi.');
  }

  /// Yeni ilaç kaydı oluşturur.
  Future<Medication> createMedication(Medication medication) async {
    final response = await http.post(
      Uri.parse('$_kBaseUrl/medications/'),
      headers: _authHeaders,
      body: jsonEncode(medication.toJson()),
    );

    if (response.statusCode == 201) {
      return Medication.fromJson(
          _parseBody(response) as Map<String, dynamic>);
    }
    if (response.statusCode == 401) await _handleUnauthorized();
    throw ApiException(_extractDetail(_parseBody(response)));
  }

  /// Yeni ilaç için etkileşim ön kontrolü yapar (kaydetmeden).
  Future<List<InteractionWarning>> previewMedicationInteractions(
    Medication medication,
  ) async {
    final response = await http.post(
      Uri.parse('$_kBaseUrl/medications/interactions/check'),
      headers: _authHeaders,
      body: jsonEncode(medication.toJson()),
    );

    if (response.statusCode == 200) {
      final list = _parseBody(response) as List<dynamic>;
      return list
          .map((e) => InteractionWarning.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (response.statusCode == 401) await _handleUnauthorized();
    throw const ApiException('Etkileşim ön kontrolü yapılamadı.');
  }

  /// Global ilaç kataloğunda arama yapar (TypeAhead + Infinite Scroll).
  ///
  /// [query]  Kullanıcının yazdığı metin (min 2 karakter).
  /// [limit]  Sayfa başına max sonuç (varsayılan 20).
  /// [offset] Sonsuz kaydırma için başlangıç ofseti.
  Future<List<GlobalMedication>> searchGlobalMedications({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    if (query.trim().length < 2) return [];
    final uri = Uri.parse('$_kBaseUrl/medications/global-search').replace(
      queryParameters: {
        'query': query.trim(),
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );
    final response = await http.get(uri, headers: _authHeaders);
    if (response.statusCode == 200) {
      final list = _parseBody(response) as List<dynamic>;
      return list
          .map((e) => GlobalMedication.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (response.statusCode == 401) await _handleUnauthorized();
    return [];
  }

  /// Ana sayfa için kritik ikili etkileşim uyarılarını döner.
  Future<List<CriticalInteractionWarning>> getCriticalInteractionWarnings() async {
    final response = await http.get(
      Uri.parse('$_kBaseUrl/medications/interactions/critical'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final list = _parseBody(response) as List<dynamic>;
      return list
          .map((e) => CriticalInteractionWarning.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (response.statusCode == 401) await _handleUnauthorized();
    return [];
  }

  /// İlaç kaydını siler.
  Future<void> deleteMedication(int id) async {
    final response = await http.delete(
      Uri.parse('$_kBaseUrl/medications/$id'),
      headers: _authHeaders,
    );

    if (response.statusCode == 204) return;
    if (response.statusCode == 401) await _handleUnauthorized();
    throw const ApiException('İlaç silinemedi.');
  }

  // ────────────────────────────────────────────────────
  // Kullanıcı Tercihleri
  // ────────────────────────────────────────────────────

  /// Uyanma / uyuma tercihlerini döner.
  Future<UserPreference> getPreferences() async {
    final response = await http.get(
      Uri.parse('$_kBaseUrl/preferences/'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      return UserPreference.fromJson(_parseBody(response) as Map<String, dynamic>);
    }
    if (response.statusCode == 401) await _handleUnauthorized();
    throw const ApiException('Tercihler yüklenemedi.');
  }

  /// Uyanma / uyuma tercihlerini günceller.
  Future<UserPreference> updatePreferences(UserPreference pref) async {
    final response = await http.put(
      Uri.parse('$_kBaseUrl/preferences/'),
      headers: _authHeaders,
      body: jsonEncode(pref.toJson()),
    );
    if (response.statusCode == 200) {
      return UserPreference.fromJson(_parseBody(response) as Map<String, dynamic>);
    }
    if (response.statusCode == 401) await _handleUnauthorized();
    throw ApiException(_extractDetail(_parseBody(response)));
  }

  // ────────────────────────────────────────────────────
  // Takvim & Doz Takibi
  // ────────────────────────────────────────────────────

  /// Belirtilen gün için doz loglarını döner.
  Future<List<DoseLog>> getDailyDoseLogs(DateTime day) async {
    final dateStr =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final response = await http.get(
      Uri.parse('$_kBaseUrl/medications/schedule/$dateStr'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final body = _parseBody(response) as Map<String, dynamic>;
      final list = body['dose_logs'] as List<dynamic>;
      return list.map((e) => DoseLog.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (response.statusCode == 401) await _handleUnauthorized();
    throw const ApiException('Günlük dozlar yüklenemedi.');
  }

  /// Aylık özet döner: {date_str → {taken, missed, pending, total, compliance_rate}}
  Future<Map<String, dynamic>> getMonthlySummary(int year, int month) async {
    final response = await http.get(
      Uri.parse('$_kBaseUrl/calendar/monthly/$year/$month'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final body = _parseBody(response) as Map<String, dynamic>;
      return body['summary'] as Map<String, dynamic>;
    }
    if (response.statusCode == 401) await _handleUnauthorized();
    throw const ApiException('Aylık özet yüklenemedi.');
  }

  /// Doz durumunu günceller (Alındı / Atlandı / Ertelendi).
  Future<DoseLog> updateDoseStatus(int doseLogId, String status, {String? notes}) async {
    final response = await http.patch(
      Uri.parse('$_kBaseUrl/dose-logs/$doseLogId'),
      headers: _authHeaders,
      body: jsonEncode({
        'status': status,
        if (notes != null) 'notes': notes,
      }),
    );
    if (response.statusCode == 200) {
      return DoseLog.fromJson(_parseBody(response) as Map<String, dynamic>);
    }
    if (response.statusCode == 401) await _handleUnauthorized();
    throw ApiException(_extractDetail(_parseBody(response)));
  }

  // ────────────────────────────────────────────────────
  // Bildirimler
  // ────────────────────────────────────────────────────

  /// Önümüzdeki ~15 dakika içinde zamanı gelmiş doz loglarını döner.
  /// Aynı ID için tekrar bildirim gösterimi frontend'de yönetilir.
  Future<List<DoseLog>> getPendingNotifications() async {
    final response = await http.get(
      Uri.parse('$_kBaseUrl/notifications/pending'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final list = _parseBody(response) as List<dynamic>;
      return list
          .map((e) => DoseLog.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (response.statusCode == 401) await _handleUnauthorized();
    throw const ApiException('Bildirimler alınamadı.');
  }

  // ────────────────────────────────────────────────────
  // Yardımcı
  // ────────────────────────────────────────────────────

  String _extractDetail(dynamic data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) return first['msg']?.toString() ?? 'Bir hata oluştu.';
      }
    }
    return 'Bir hata oluştu.';
  }
}

/// API katmanından fırlatılan tipli istisna.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}
