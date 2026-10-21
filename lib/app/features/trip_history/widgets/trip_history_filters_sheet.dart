import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../models/trip_filter_option.dart';

/// Bottom sheet "Filtros" del historial de eventos: transportista, operador
/// y rango de fecha de finalización. Mantiene su propia selección temporal
/// y solo reporta hacia arriba (onApply) al confirmar — igual que el resto
/// de formularios de la app, que no tocan el controller hasta el submit.
Future<TripHistoryFilters?> showTripHistoryFiltersSheet(
  BuildContext context, {
  required TripHistoryFilters current,
  required TripFilterOptions options,
  bool showOwnerFilters = true,
}) {
  return showModalBottomSheet<TripHistoryFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TripHistoryFiltersSheet(
      current: current,
      options: options,
      showOwnerFilters: showOwnerFilters,
    ),
  );
}

class _TripHistoryFiltersSheet extends StatefulWidget {
  final TripHistoryFilters current;
  final TripFilterOptions options;
  // El operador ve solo sus propios viajes (scope forzado en el backend), no
  // tiene sentido que filtre por transportista/operador.
  final bool showOwnerFilters;

  const _TripHistoryFiltersSheet({
    required this.current,
    required this.options,
    this.showOwnerFilters = true,
  });

  @override
  State<_TripHistoryFiltersSheet> createState() => _TripHistoryFiltersSheetState();
}

class _TripHistoryFiltersSheetState extends State<_TripHistoryFiltersSheet> {
  late TripFilterOption? _transporter = widget.current.transporter;
  late TripFilterOption? _operator = widget.current.operator;
  late DateTime? _dateFrom = widget.current.completionDateFrom;
  late DateTime? _dateTo = widget.current.completionDateTo;

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = (isFrom ? _dateFrom : _dateTo) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = date;
      } else {
        _dateTo = date;
      }
    });
  }

  void _clear() {
    setState(() {
      _transporter = null;
      _operator = null;
      _dateFrom = null;
      _dateTo = null;
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      TripHistoryFilters(
        transporter: _transporter,
        operator: _operator,
        completionDateFrom: _dateFrom,
        completionDateTo: _dateTo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.fieldBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Filtros',
                style: TextStyle(
                  color: AppColors.navyBlue,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.showOwnerFilters) ...[
                const SizedBox(height: 18),
                const _Label('Transportista'),
                const SizedBox(height: 8),
                _StyledDropdown<TripFilterOption>(
                  value: _transporter,
                  hint: 'Todos',
                  items: widget.options.transporters,
                  itemLabel: (o) => o.name,
                  onChanged: (v) => setState(() => _transporter = v),
                ),
                const SizedBox(height: 18),
                const _Label('Operador'),
                const SizedBox(height: 8),
                _StyledDropdown<TripFilterOption>(
                  value: _operator,
                  hint: 'Todos',
                  items: widget.options.operators,
                  itemLabel: (o) => o.name,
                  onChanged: (v) => setState(() => _operator = v),
                ),
              ],
              const SizedBox(height: 18),
              const _Label('Fecha de finalización'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Desde',
                      value: _dateFrom,
                      onTap: () => _pickDate(isFrom: true),
                      onClear: () => setState(() => _dateFrom = null),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateField(
                      label: 'Hasta',
                      value: _dateTo,
                      onTap: () => _pickDate(isFrom: false),
                      onClear: () => setState(() => _dateTo = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clear,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.fieldBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Limpiar',
                        style: TextStyle(
                          color: AppColors.textMedium,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.royalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Aplicar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.navyBlue,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _StyledDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = items.contains(value) ? value : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: safeValue,
          isExpanded: true,
          hint: Text(hint,
              style: const TextStyle(color: AppColors.textLight, fontSize: 13)),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.royalBlue),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemLabel(item),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ))
              .toList(),
          onChanged: items.isEmpty ? null : onChanged,
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  String _format(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_rounded, color: AppColors.royalBlue, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value != null ? _format(value!) : label,
                style: TextStyle(
                  color: value != null ? AppColors.textDark : AppColors.textLight,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded, color: AppColors.textLight, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}
