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

import '../models/dose_log.dart';
import '../services/api_service.dart';
import '../widgets/dose_tile.dart';
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
  Future<List<DoseLog>>? _selectedDayLogsFuture;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadMonth(_focusedDay);
    _loadSelectedDayLogs(_selectedDay!);
  }

  void _loadSelectedDayLogs(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    setState(() {
      _selectedDayLogsFuture =
          context.read<ApiService>().getDailyDoseLogs(normalized);
    });
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
    _loadSelectedDayLogs(selected);
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
              _loadSelectedDayLogs(today);
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

          // ── Seçili gün dozu: takvim tıklamasıyla anlık güncellenir
          Expanded(
            child: _SelectedDayDoseList(
              selectedDay: _selectedDay ?? DateTime.now(),
              logsFuture: _selectedDayLogsFuture,
              monthlySummary: _monthlySummary,
              onOpenDay: (date) => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DailyDosesScreen(date: date)),
              ),
              onRefresh: () {
                if (_selectedDay != null) {
                  _loadSelectedDayLogs(_selectedDay!);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedDayDoseList extends StatelessWidget {
  final DateTime selectedDay;
  final Future<List<DoseLog>>? logsFuture;
  final Map<String, dynamic> monthlySummary;
  final VoidCallback onRefresh;
  final void Function(DateTime date) onOpenDay;

  const _SelectedDayDoseList({
    required this.selectedDay,
    required this.logsFuture,
    required this.monthlySummary,
    required this.onRefresh,
    required this.onOpenDay,
  });

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(selectedDay);
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedSelected = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final isFuture = normalizedSelected.isAfter(normalizedToday);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
            child: Row(
              children: [
                const Icon(Icons.view_timeline_rounded,
                    size: 18, color: Color(0xFF455A64)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Yenile',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          if (isFuture)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Gelecek dozlar Planlandı olarak gösterilir; butonlar pasif durumda.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<DoseLog>>(
              future: logsFuture,
              builder: (context, snapshot) {
                if (logsFuture == null || snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Dozlar yüklenemedi: ${snapshot.error}',
                      style: const TextStyle(color: Color(0xFFC62828)),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final logs = snapshot.data ?? [];
                if (logs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Seçilen gün için doz kaydı bulunamadı.',
                      style: TextStyle(color: Color(0xFF607D8B)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: logs.length,
                  itemBuilder: (ctx, i) => DoseTile(
                    log: logs[i],
                    onTaken: null,
                    onMissed: null,
                    onSnooze: null,
                  ),
                );
              },
            ),
          ),
          if (monthlySummary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onOpenDay(selectedDay),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Detay Ekranını Aç'),
                ),
              ),
            ),
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
