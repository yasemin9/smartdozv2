/// SmartDoz - Aylık Takvim Ekranı
///
/// table_calendar ile aylık görünüm sağlar.
/// Her güne renkli nokta (event marker) ekler:
///   Tüm alındı    → yeşil
///   Gecikmiş/atlandı var → kırmızı
///   Karışık       → turuncu
///   Sadece bekliyor → mavi
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/api_service.dart';
import 'daily_doses_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  // {dateStr → summary map}
  Map<String, dynamic> _monthlySummary = {};
  bool _loadingMonth = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadMonth(_focusedDay);
  }

  Future<void> _loadMonth(DateTime month) async {
    setState(() => _loadingMonth = true);
    try {
      final summary = await context
          .read<ApiService>()
          .getMonthlySummary(month.year, month.month);
      if (mounted) setState(() => _monthlySummary = summary);
    } catch (_) {
      // Sessizce geç — nokta gösterilmez, detay ekranı çalışır
    } finally {
      if (mounted) setState(() => _loadingMonth = false);
    }
  }

  // ── Bir güne ait özet varsa noktaların rengini belirle
  Color? _dotColorForDay(DateTime day) {
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final info = _monthlySummary[key];
    if (info == null) return null;

    final taken    = (info['taken']    as num?)?.toInt() ?? 0;
    final missed   = (info['missed']   as num?)?.toInt() ?? 0;
    final total    = (info['total']    as num?)?.toInt() ?? 0;
    final pending  = (info['pending']  as num?)?.toInt() ?? 0;

    if (total == 0) return null;
    if (taken == total) return const Color(0xFF2E7D32);         // Tümü alındı → yeşil
    if (missed > 0 && taken == 0) return const Color(0xFFC62828); // Hepsi atlandı → kırmızı
    if (missed > 0) return const Color(0xFFE65100);              // Karışık → turuncu
    if (pending == total) return const Color(0xFF1565C0);        // Tümü bekliyor → mavi
    return const Color(0xFFE65100);                              // Kısmen alındı → turuncu
  }

  void _onDaySelected(DateTime selected, DateTime focused) {
    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
    });
    // Gelecek tarihler sadece görüntülenebilir; işaretleme yapılamaz
    final today = DateTime.now();
    final isFuture = selected.isAfter(DateTime(today.year, today.month, today.day));
    if (isFuture) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gelecek tarihler için işaretleme yapılamaz.'),
          backgroundColor: const Color(0xFFE65100),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyDosesScreen(date: selected),
      ),
    );
  }

  void _onPageChanged(DateTime focusedDay) {
    _focusedDay = focusedDay;
    _loadMonth(focusedDay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.calendar_month_rounded, size: 22),
            SizedBox(width: 8),
            Text('Doz Takvimi', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          if (_loadingMonth)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: 'Bugüne Git',
            onPressed: () {
              final today = DateTime.now();
              setState(() {
                _focusedDay = today;
                _selectedDay = today;
              });
              _loadMonth(today);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Takvim Bileşeni
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TableCalendar(
              locale: 'tr_TR',
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2027, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
              onDaySelected: _onDaySelected,
              onPageChanged: _onPageChanged,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                weekendTextStyle: const TextStyle(color: Color(0xFFC62828)),
                outsideDaysVisible: false,
              ),
              // Her güne renkli nokta ekle
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, _) {
                  final color = _dotColorForDay(day);
                  if (color == null) return const SizedBox.shrink();
                  return Positioned(
                    bottom: 4,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Renk Açıklaması
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _LegendDot(color: Color(0xFF2E7D32), label: 'Tümü Alındı'),
                SizedBox(width: 16),
                _LegendDot(color: Color(0xFFC62828), label: 'Atlandı'),
                SizedBox(width: 16),
                _LegendDot(color: Color(0xFFE65100), label: 'Kısmi'),
                SizedBox(width: 16),
                _LegendDot(color: Color(0xFF1565C0), label: 'Bekliyor'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Aylık Uyum Özeti
          Expanded(child: _MonthlySummaryList(summary: _monthlySummary)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// Renk açıklama noktası
// ────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );
}

// ────────────────────────────────────────────────────
// Aylık özet listesi
// ────────────────────────────────────────────────────
class _MonthlySummaryList extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _MonthlySummaryList({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 52, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'Bu ay için doz kaydı yok.',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final entries = summary.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)); // Yeniden eskiye

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final key = entries[i].key;
        final info = entries[i].value as Map<String, dynamic>;
        final taken   = (info['taken']   as num?)?.toInt() ?? 0;
        final total   = (info['total']   as num?)?.toInt() ?? 0;
        final rate    = (info['compliance_rate'] as num?)?.toDouble() ?? 0;
        final missed  = (info['missed']  as num?)?.toInt() ?? 0;

        final dateObj = DateTime.parse(key);
        final label   = DateFormat('d MMMM, EEEE', 'tr_TR').format(dateObj);
        final rateStr = '${(rate * 100).round()}%';

        Color barColor = const Color(0xFF2E7D32);
        if (rate < 0.5) barColor = const Color(0xFFC62828);
        else if (rate < 0.8) barColor = const Color(0xFFE65100);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: LinearProgressIndicator(
              value: rate,
              backgroundColor: Colors.grey[200],
              color: barColor,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$taken/$total doz',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Text(
                  rateStr,
                  style:
                      TextStyle(fontSize: 12, color: barColor),
                ),
                if (missed > 0)
                  Text(
                    '$missed atlandı',
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFFC62828)),
                  ),
              ],
            ),
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(
                  builder: (_) => DailyDosesScreen(date: dateObj)),
            ),
          ),
        );
      },
    );
  }
}
