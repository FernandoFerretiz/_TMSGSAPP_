import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../models/internal_expense_models.dart';

/// Piezas visuales compartidas de Gastos internos. Texto nunca menor a 13 (regla del proyecto: sin letra pequeña).

String money(num amount, String currency) =>
    '${NumberFormat('#,##0.00', 'es_MX').format(amount)} $currency';

/// 'AAAA-MM-DD' (o con hora) → 'dd/MM/aaaa'.
String formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return DateFormat('dd/MM/yyyy').format(d);
}

String toIsoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Fondo del renglón según la alerta que decide el servidor: rojo = vencido/vence hoy, naranja = próximo a vencer.
Color alertBackground(String? alert) => switch (alert) {
      'danger' => const Color(0xFFFBD5D5),
      'warning' => const Color(0xFFFFE0C2),
      _ => Colors.white,
    };

Color alertBorder(String? alert) => switch (alert) {
      'danger' => const Color(0xFFE57373),
      'warning' => const Color(0xFFFFB74D),
      _ => Colors.transparent,
    };

Color stateColor(String key) => switch (key) {
      'overdue' || 'due_today' => const Color(0xFFC62828),
      'due_soon' => const Color(0xFFEF6C00),
      'paid' || 'up_to_date' => const Color(0xFF2E7D32),
      'pending' => AppColors.royalBlue,
      _ => AppColors.textMedium, // paused, finished, cancelled
    };

class StateChip extends StatelessWidget {
  final String stateKey;
  final String label;

  const StateChip({super.key, required this.stateKey, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = stateColor(stateKey);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const SectionCard({super.key, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(title, style: const TextStyle(color: AppColors.navyBlue, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 128, child: Text(label, style: const TextStyle(color: AppColors.textMedium, fontSize: 14))),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(color: AppColors.navyBlue, fontSize: 14, fontWeight: FontWeight.w600)),
      );
}

InputDecoration fieldDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
      filled: true,
      fillColor: AppColors.fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.fieldBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.royalBlue, width: 2)),
    );

class ErrorRow extends StatelessWidget {
  final String message;

  const ErrorRow(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.errorRed, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.errorRed, fontSize: 14, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const PrimaryButton({super.key, required this.label, required this.isLoading, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.buttonGradient : const LinearGradient(colors: [Color(0xFF90A4AE), Color(0xFFB0BEC5)]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
        ),
      ),
    );
  }
}

/// Select con búsqueda opcional (mismo estilo y paquete que el formulario de viajes de circuito).
class OptionSelect extends StatefulWidget {
  final List<Option> options;
  final String? value;
  final String hint;
  final bool searchable;
  final ValueChanged<String?> onChanged;

  const OptionSelect({
    super.key,
    required this.options,
    required this.value,
    required this.hint,
    required this.onChanged,
    this.searchable = false,
  });

  @override
  State<OptionSelect> createState() => _OptionSelectState();
}

class _OptionSelectState extends State<OptionSelect> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeValue = widget.options.any((o) => o.value == widget.value) ? widget.value : null;

    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        value: safeValue,
        isExpanded: true,
        hint: Text(widget.hint, style: const TextStyle(color: AppColors.textLight, fontSize: 14)),
        iconStyleData: const IconStyleData(icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.royalBlue)),
        items: widget.options
            .map((o) => DropdownMenuItem<String>(
                  value: o.value,
                  child: Text(o.label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w500)),
                ))
            .toList(),
        onChanged: widget.options.isEmpty ? null : widget.onChanged,
        buttonStyleData: ButtonStyleData(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.fieldBorder)),
        ),
        menuItemStyleData: const MenuItemStyleData(height: 46),
        dropdownStyleData: DropdownStyleData(maxHeight: 320, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
        dropdownSearchData: widget.searchable
            ? DropdownSearchData<String>(
                searchController: _search,
                searchInnerWidgetHeight: 54,
                searchInnerWidget: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextFormField(
                    controller: _search,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Buscar…',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                searchMatchFn: (item, term) =>
                    widget.options.firstWhere((o) => o.value == item.value, orElse: () => const Option('', '')).label.toLowerCase().contains(term.toLowerCase()),
              )
            : null,
        onMenuStateChange: (open) {
          if (!open) _search.clear();
        },
      ),
    );
  }
}

/// Campo de fecha con el selector nativo del sistema; el valor viaja como 'AAAA-MM-DD'.
class DateField extends StatelessWidget {
  final String? value;
  final String hint;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool clearable;
  final ValueChanged<String?> onChanged;

  DateField({
    super.key,
    required this.value,
    required this.hint,
    required this.onChanged,
    this.clearable = false,
    DateTime? firstDate,
    DateTime? lastDate,
  })  : firstDate = firstDate ?? DateTime(2020),
        lastDate = lastDate ?? DateTime(2100);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final initial = DateTime.tryParse(value ?? '') ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initial.isBefore(firstDate) ? firstDate : (initial.isAfter(lastDate) ? lastDate : initial),
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (picked != null) onChanged(toIsoDate(picked));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.fieldBorder)),
        child: Row(children: [
          const Icon(Icons.event_rounded, color: AppColors.royalBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value == null || value!.isEmpty ? hint : formatDate(value),
              style: TextStyle(color: value == null || value!.isEmpty ? AppColors.textLight : AppColors.textDark, fontSize: 14),
            ),
          ),
          if (clearable && value != null && value!.isNotEmpty)
            GestureDetector(onTap: () => onChanged(null), child: const Icon(Icons.close_rounded, color: AppColors.textLight, size: 20)),
        ]),
      ),
    );
  }
}
