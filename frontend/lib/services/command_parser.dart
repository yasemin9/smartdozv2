// SmartDoz - Kural Tabanlı Komut Ayrıştırıcı (Modül 6)
//
// Mimari:
//   • Groq / LLM bağımlılığı YOK — internet gerektirmez, anında yanıt verir.
//   • Her Intent için Türkçe regex desenleri öncelik sırasına göre eşleştirilir.
//   • extract() → tanımlanan niyet + varsa ilaç adı / zaman parametresi döner.
//
// Desteklenen Niyetler (VoiceIntent):
//   queryTaken       → "İlacımı aldım mı?",  "Aspirini içtim mi?"
//   queryNext        → "Sıradaki ilacım ne?", "Bir sonraki dozum ne zaman?"
//   queryWhen        → "Aspirini ne zaman alacağım?"
//   logTaken         → "Aspirin aldım",       "İlacımı içtim"
//   listMedications  → "İlaçlarımı listele",  "Hangi ilaçları kullanıyorum?"
//   addMedication    → "Aspirin ekle",        "Yeni ilaç ekle"
//   help             → "Yardım", "Ne yapabilirsin?"
//   unknown          → Hiçbir kural eşleşmedi (Güven skoru dışı fallback)

// ─────────────────────────────────────────────────────────────────────────────

enum VoiceIntent {
  queryTaken,
  queryNext,
  queryWhen,
  logTaken,
  listMedications,
  addMedication,
  help,
  unknown,
}

class ParsedCommand {
  final VoiceIntent intent;

  /// Tespit edilen ilaç adı (lowercase). Yoksa null.
  final String? medicationName;

  /// Ham transkript metnin normalize edilmiş hali.
  final String rawText;

  const ParsedCommand({
    required this.intent,
    required this.rawText,
    this.medicationName,
  });

  @override
  String toString() =>
      'ParsedCommand(intent: $intent, med: $medicationName, raw: "$rawText")';
}

// ─────────────────────────────────────────────────────────────────────────────

class CommandParser {
  // ── Sabit Regex Desenleri ──────────────────────────────────────────────────

  /// aldım mı / içtim mi / kullandım mı → queryTaken
  static final _rQueryTaken = RegExp(
    r'(ald[ıi]m\s*m[ıi]|içtim\s*mi|kulland[ıi]m\s*m[ıi]|aldım mı|içtim mi)',
    caseSensitive: false,
    unicode: true,
  );

  /// sıradaki / bir sonraki / sonraki doz → queryNext
  static final _rQueryNext = RegExp(
    r'(s[ıi]radaki|bir sonraki|sonraki\s*(ilaç|doz)|ne zaman\s*(almam|içmem)\s*gerek)',
    caseSensitive: false,
    unicode: true,
  );

  /// [ilaç] ne zaman / saat kaçta → queryWhen  (ilaç adı varsa)
  static final _rQueryWhen = RegExp(
    r'ne zaman\s*(alaca[gğ][ıi]m|içece[gğ][ıi]m|almam\s*gerek)|saat\s*kaçta',
    caseSensitive: false,
    unicode: true,
  );

  /// [ilaç] aldım / içtim / kullandım  (soru DEĞİL) → logTaken
  static final _rLogTaken = RegExp(
    r'\b(ald[ıi]m|içtim|kulland[ıi]m|ilaç[ıi]\s*ald[ıi]m|ilac[ıi]m[ıi]\s*içtim)\b',
    caseSensitive: false,
    unicode: true,
  );

  /// ilaçlarımı listele / hangi ilaç / ilaçlarım neler → listMedications
  static final _rListMedications = RegExp(
    r'(listele|hangi\s*ilaç|ilaçlar[ıi]m\s*neler|ilaç\s*listem)',
    caseSensitive: false,
    unicode: true,
  );

  /// [ilaç] ekle / yeni ilaç / ilaç ekle → addMedication
  static final _rAddMedication = RegExp(
    r'(ekle|yeni\s*ilaç|ilaç\s*ekle|kaydet)',
    caseSensitive: false,
    unicode: true,
  );

  /// yardım / ne yapabilirsin / komutlar → help
  static final _rHelp = RegExp(
    r'(yardım|ne yapabilirsin|komutlar|nasıl kullan)',
    caseSensitive: false,
    unicode: true,
  );

  // ── Türkçe yaygın ilaç stopword'lerini çıkarmak için kaldırılacak kelimeler
  static final _rStopwords = RegExp(
    r'\b(ilaç[ıi]m[ıi]?|ilac[ıi]m[ıi]?|ilac[ıi]n[ıi]?|için|bu|bir|ne|zaman|'
    r'saat|hangi|al[ıi]yor|alaca[gğ][ıi]m|içece[gğ][ıi]m|sıradaki|sonraki|'
    r'yeni|ekle|listele|kaydet|aldım|içtim|kullandım|mi|mı|mü|mu|ne|var)\b',
    caseSensitive: false,
    unicode: true,
  );

  // ─────────────────────────────────────────────────────────────────────────

  /// Ana giriş noktası. [text] ham transkripttir.
  /// Önce metni normalize eder, ardından kural zincirini çalıştırır.
  ParsedCommand parse(String text) {
    final normalized = _normalize(text);

    // Kural zinciri: önce spesifik, sonra genel
    if (_rQueryTaken.hasMatch(normalized)) {
      return ParsedCommand(
        intent: VoiceIntent.queryTaken,
        rawText: normalized,
        medicationName: _extractMedName(normalized),
      );
    }

    if (_rQueryNext.hasMatch(normalized)) {
      return ParsedCommand(
        intent: VoiceIntent.queryNext,
        rawText: normalized,
      );
    }

    if (_rQueryWhen.hasMatch(normalized)) {
      return ParsedCommand(
        intent: VoiceIntent.queryWhen,
        rawText: normalized,
        medicationName: _extractMedName(normalized),
      );
    }

    // logTaken: "aldım" varsa AMA soru ekiyle değilse (query önce kontrol edildi)
    if (_rLogTaken.hasMatch(normalized)) {
      return ParsedCommand(
        intent: VoiceIntent.logTaken,
        rawText: normalized,
        medicationName: _extractMedName(normalized),
      );
    }

    if (_rListMedications.hasMatch(normalized)) {
      return ParsedCommand(
        intent: VoiceIntent.listMedications,
        rawText: normalized,
      );
    }

    if (_rAddMedication.hasMatch(normalized)) {
      return ParsedCommand(
        intent: VoiceIntent.addMedication,
        rawText: normalized,
        medicationName: _extractMedName(normalized),
      );
    }

    if (_rHelp.hasMatch(normalized)) {
      return ParsedCommand(
        intent: VoiceIntent.help,
        rawText: normalized,
      );
    }

    return ParsedCommand(
      intent: VoiceIntent.unknown,
      rawText: normalized,
    );
  }

  // ── Yardımcı: Metni normalize et ────────────────────────────────────────

  String _normalize(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  // ── Yardımcı: İlaç adı çıkar ────────────────────────────────────────────
  //
  // Stopword maskeleme sonrası kalan tek token'ları ilaç adı adayı kabul eder.
  // Örn: "aspirini ne zaman içeceğim?" → stopwords sonrası "aspirin" kalır.

  String? _extractMedName(String text) {
    final cleaned = text
        .replaceAll(_rStopwords, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) return null;

    // 2 karakterden kısa token'lar muhtemelen bir ilaç adı değildir
    final tokens =
        cleaned.split(' ').where((t) => t.length >= 2).toList();

    if (tokens.isEmpty) return null;

    // En uzun token'ı ilaç adı adayı olarak seç (kısaltmalara karşı sağlam)
    tokens.sort((a, b) => b.length.compareTo(a.length));
    return tokens.first;
  }
}
