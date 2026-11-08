import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/routes/route_names.dart';
import '../../../core/config/app_config.dart';
import '../../../core/design/sx_design.dart';
import '../controllers/internal_expense_controller.dart';
import '../models/internal_expense_models.dart';
import '../widgets/expense_ui.dart';

/// Calendario de vencimientos del mes. Cada día muestra puntos de color según su alerta (rojo, naranja,
/// azul o verde si ya se pagó); al tocar un día se listan sus vencimientos y cada uno abre el gasto.
class InternalExpenseCalendarScreen extends StatefulWidget {
  const InternalExpenseCalendarScreen({super.key});

  @override
  State<InternalExpenseCalendarScreen> createState() => _InternalExpenseCalendarScreenState();
}

class _InternalExpenseCalendarScreenState extends State<InternalExpenseCalendarScreen> {
  late final InternalExpenseController _c;
  String? _selected; // AAAA-MM-DD

  static const _months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
  static const _weekdays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    _c = Get.find<InternalExpenseController>();
    _selected = toIsoDate(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _c.calendarMonth.value = DateTime(DateTime.now().year, DateTime.now().month);
      _c.loadCalendar();
    });
  }

  Color _dot(CalendarEntry e) => switch (e.alert) {
        'danger' => const Color(0xFFC62828),
        'warning' => const Color(0xFFEF6C00),
        _ => e.stateKey == 'paid' ? const Color(0xFF2E7D32) : AppColors.royalBlue,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sx.pageBg,
      appBar: const SxAppBar(title: Text('Calendario de vencimientos')),
      body: Obx(() {
        final month = _c.calendarMonth.value;
        final entries = _c.calendarEntries;
        final byDay = <String, List<CalendarEntry>>{};
        for (final e in entries) {
          byDay.putIfAbsent(e.dueOn, () => []).add(e);
        }

        final first = DateTime(month.year, month.month, 1);
        final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
        final leading = first.weekday - 1; // lunes = 0
        final cells = leading + daysInMonth;
        final rows = (cells / 7).ceil();
        final todayIso = toIsoDate(DateTime.now());

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: Column(children: [
                Row(children: [
                  IconButton(onPressed: () => _c.moveCalendar(-1), icon: const Icon(Icons.chevron_left_rounded, color: AppColors.royalBlue)),
                  Expanded(
                    child: Text('${_months[month.month - 1]} ${month.year}',
                        textAlign: TextAlign.center, style: const TextStyle(color: AppColors.navyBlue, fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(onPressed: () => _c.moveCalendar(1), icon: const Icon(Icons.chevron_right_rounded, color: AppColors.royalBlue)),
                ]),
                const SizedBox(height: 6),
                Row(children: [for (final w in _weekdays) Expanded(child: Center(child: Text(w, style: const TextStyle(color: AppColors.textMedium, fontSize: 14, fontWeight: FontWeight.w700))))]),
                const SizedBox(height: 6),
                for (var r = 0; r < rows; r++)
                  Row(children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(child: _cell(r * 7 + col - leading + 1, daysInMonth, month, byDay, todayIso)),
                  ]),
                const SizedBox(height: 10),
                if (_c.isLoadingCalendar.value) const LinearProgressIndicator(color: AppColors.royalBlue),
                if (_c.calendarError.value.isNotEmpty) ErrorRow(_c.calendarError.value),
              ]),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 14, runSpacing: 6, children: const [
              _Legend(Color(0xFF0D6EFD), 'Pendiente'),
              _Legend(Color(0xFFEF6C00), 'Próximo a vencer'),
              _Legend(Color(0xFFC62828), 'Vencido / hoy'),
              _Legend(Color(0xFF2E7D32), 'Pagado'),
            ]),
            const SizedBox(height: 14),
            if (_selected != null) ..._dayList(byDay[_selected] ?? const []),
          ],
        );
      }),
    );
  }

  Widget _cell(int day, int daysInMonth, DateTime month, Map<String, List<CalendarEntry>> byDay, String todayIso) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 52);

    final iso = toIsoDate(DateTime(month.year, month.month, day));
    final list = byDay[iso] ?? const <CalendarEntry>[];
    final selected = _selected == iso;

    return GestureDetector(
      onTap: () => setState(() => _selected = iso),
      child: Container(
        height: 52,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected ? AppColors.royalBlue : (iso == todayIso ? AppColors.lightBlue.withValues(alpha: 0.5) : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$day', style: TextStyle(color: selected ? Colors.white : AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final e in list.take(3))
              Container(margin: const EdgeInsets.symmetric(horizontal: 1.5), width: 7, height: 7, decoration: BoxDecoration(color: selected ? Colors.white : _dot(e), shape: BoxShape.circle)),
          ]),
        ]),
      ),
    );
  }

  List<Widget> _dayList(List<CalendarEntry> list) {
    if (list.isEmpty) {
      return [const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('No hay vencimientos este día.', style: TextStyle(color: AppColors.textMedium, fontSize: 15))))];
    }

    return [
      for (final e in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Get.toNamed(RouteNames.internalExpenseDetail, arguments: e.expenseId),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: alertBackground(e.alert),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: alertBorder(e.alert)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.name, style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(money(e.amount, e.currencyCode), style: const TextStyle(color: AppColors.navyBlue, fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  StateChip(stateKey: e.stateKey, label: e.stateLabel),
                ]),
              ),
            ),
          ),
        ),
    ];
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend(this.color, this.label);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textMedium, fontSize: 14)),
      ]);
}
