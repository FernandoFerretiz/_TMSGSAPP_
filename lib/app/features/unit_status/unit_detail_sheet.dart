import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import 'unit_status_models.dart';

/// Resultado de la hoja de una unidad.
class UnitSheetResult {
  /// Comentario adicional para el reporte (puede quedar vacío).
  final String comment;

  /// true si se registró un sub status o una incidencia (hay que refrescar la lista).
  final bool changed;
  const UnitSheetResult({required this.comment, required this.changed});
}

class _OpStatus {
  final int id;
  final String name;
  const _OpStatus({required this.id, required this.name});
}

class _LogOption {
  final int? id; // null = "Otro"
  final String name;
  final bool requiresComment;
  const _LogOption({this.id, required this.name, this.requiresComment = false});

  bool get isOther => id == null;
}

class _ExtraField {
  final String key;
  final String label;
  final bool required;
  final bool numeric;
  const _ExtraField(
      {required this.key,
      required this.label,
      this.required = false,
      this.numeric = false});
}

class _IncidentType {
  final int id;
  final String name;
  final String? description;
  final bool requiresPhoto;
  final bool requiresCanContinue;
  final List<_ExtraField> extraFields;
  const _IncidentType({
    required this.id,
    required this.name,
    this.description,
    this.requiresPhoto = false,
    this.requiresCanContinue = false,
    this.extraFields = const [],
  });
}

class _IncidentCategory {
  final String name;
  final List<_IncidentType> types;
  const _IncidentCategory({required this.name, required this.types});
}

/// Hoja de una unidad del reporte: comentario adicional y, por si el operador
/// no lo registró, agregar un sub status o una incidencia. "Guardar" aplica todo.
class UnitDetailSheet extends StatefulWidget {
  final UnitStatusItem item;
  final String initialComment;

  /// Solo sub status / incidencia: sin cambio de status ni ETA.
  final bool reportOnly;
  const UnitDetailSheet(
      {super.key,
      required this.item,
      required this.initialComment,
      this.reportOnly = false});

  static Future<UnitSheetResult?> show(
    BuildContext context, {
    required UnitStatusItem item,
    required String initialComment,
    bool reportOnly = false,
  }) {
    return showModalBottomSheet<UnitSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => UnitDetailSheet(
          item: item,
          initialComment: initialComment,
          reportOnly: reportOnly),
    );
  }

  @override
  State<UnitDetailSheet> createState() => _UnitDetailSheetState();
}

class _UnitDetailSheetState extends State<UnitDetailSheet> {
  late final _comment = TextEditingController(text: widget.initialComment);
  final _extraCtrls = <String, TextEditingController>{};

  List<_OpStatus>? _statuses;
  List<_LogOption>? _options;
  List<_IncidentCategory>? _categories;

  // ETA capturada a mano (hora de pared de Monterrey); se aplica al guardar.
  DateTime? _manualEta;

  bool _changeStatus = false;
  _OpStatus? _newStatus;

  bool _addSubStatus = false;
  _LogOption? _option;

  bool _addIncident = false;
  _IncidentCategory? _category;
  _IncidentType? _type;
  bool? _canContinue;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    for (final c in _extraCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStatuses() async {
    if (_statuses != null) return;
    try {
      final res = await Get.find<ApiClient>()
          .dio
          .get('/api/mobile/trips/${widget.item.tripId}/statuses');
      final data = res.data['data'] as Map<String, dynamic>;
      // operational_status es varchar en la BD: llega como texto ("2"), no como número.
      final current = int.tryParse(data['current_status_id']?.toString() ?? '');
      final list = (data['statuses'] as List? ?? [])
          .map((e) {
            final m = e as Map<String, dynamic>;
            return _OpStatus(
                id: int.parse(m['id'].toString()),
                name: (m['name'] ?? '').toString());
          })
          // Cambiar al status que ya tiene no tiene sentido.
          .where((st) => st.id != current)
          .toList();
      if (mounted) setState(() => _statuses = list);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudieron cargar los status.');
    }
  }

  Future<void> _loadOptions() async {
    if (_options != null) return;
    try {
      final res =
          await Get.find<ApiClient>().dio.get('/api/mobile/trip-log/options');
      final list = (res.data['data'] as List? ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return _LogOption(
          id: (m['id'] as num).toInt(),
          name: (m['name'] ?? '').toString(),
          requiresComment: m['requires_comment'] == true,
        );
      }).toList();
      if (mounted)
        setState(() => _options = [
              ...list,
              const _LogOption(name: 'Otro', requiresComment: true)
            ]);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'No se pudieron cargar los sub status.');
    }
  }

  Future<void> _loadCatalog() async {
    if (_categories != null) return;
    try {
      final res =
          await Get.find<ApiClient>().dio.get('/api/mobile/incident-catalog');
      final list = (res.data['data'] as List? ?? []).map((c) {
        final m = c as Map<String, dynamic>;
        return _IncidentCategory(
          name: (m['name'] ?? '').toString(),
          types: (m['types'] as List? ?? []).map((t) {
            final x = t as Map<String, dynamic>;
            return _IncidentType(
              id: (x['id'] as num).toInt(),
              name: (x['name'] ?? '').toString(),
              description: x['description']?.toString(),
              requiresPhoto: x['requires_photo'] == true,
              requiresCanContinue: x['requires_can_continue_trip'] == true,
              extraFields: (x['extra_fields'] as List? ?? []).map((f) {
                final y = f as Map<String, dynamic>;
                return _ExtraField(
                  key: (y['key'] ?? '').toString(),
                  label: (y['label'] ?? '').toString(),
                  required: y['required'] == true,
                  numeric: y['type'] == 'number',
                );
              }).toList(),
            );
          }).toList(),
        );
      }).toList();
      if (mounted) setState(() => _categories = list);
    } catch (_) {
      if (mounted)
        setState(
            () => _error = 'No se pudo cargar el catálogo de incidencias.');
    }
  }

  Future<T?> _pick<T>(
      String title, List<T> items, String Function(T) label, T? selected) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(title,
                    style: const TextStyle(
                        color: AppColors.navyBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final isSel = items[i] == selected;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      tileColor: isSel ? const Color(0xFFE3EEFF) : null,
                      title: Text(label(items[i]),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      trailing: isSel
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.royalBlue)
                          : null,
                      onTap: () => Navigator.of(ctx).pop(items[i]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editEta() async {
    final base = _manualEta ?? widget.item.eta?.at ?? DateTime.now();
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
      helpText: 'Fecha de la ETA',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: 'Hora de la ETA',
    );
    if (time == null || !mounted) return;

    setState(() {
      _manualEta =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _error = null;
    });
  }

  String? _validate() {
    final comment = _comment.text.trim();
    if (_changeStatus && _newStatus == null) return 'Elige el nuevo status.';
    if (_addSubStatus) {
      if (_option == null) return 'Elige el sub status.';
      if (_option!.requiresComment && comment.isEmpty) {
        return _option!.isOther
            ? 'Escribe en el comentario el sub status que quieres registrar.'
            : 'Este sub status requiere un comentario.';
      }
    }
    if (_addIncident) {
      if (_type == null) return 'Elige el tipo de incidencia.';
      if (_type!.requiresPhoto) {
        return 'Este tipo de incidencia requiere fotografía y no se puede registrar desde aquí.';
      }
      if (_type!.requiresCanContinue && _canContinue == null) {
        return 'Indica si es posible continuar el viaje.';
      }
      for (final f in _type!.extraFields) {
        if (f.required && (_extraCtrls[f.key]?.text.trim().isEmpty ?? true)) {
          return 'Completa "${f.label}".';
        }
      }
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final dio = Get.find<ApiClient>().dio;
    final comment = _comment.text.trim();
    var changed = false;

    try {
      if (_manualEta != null) {
        await dio.post('/api/mobile/trips/${widget.item.tripId}/eta', data: {
          'eta_at': DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(_manualEta!),
        });
        changed = true;
        // Ya aplicada: si algo posterior falla, no se vuelve a mandar.
        _manualEta = null;
      }

      if (_changeStatus && _newStatus != null) {
        await dio.post(
            '/api/mobile/trips/${widget.item.tripId}/status-override',
            data: {
              'status_id': _newStatus!.id,
              if (comment.isNotEmpty) 'comments': comment,
            });
        changed = true;
        // Ya aplicado: si algo posterior falla, no se vuelve a mandar.
        _changeStatus = false;
      }

      if (_addSubStatus && _option != null) {
        await dio.post('/api/mobile/trips/${widget.item.tripId}/log', data: {
          if (_option!.isOther) 'other': true else 'option_id': _option!.id,
          if (comment.isNotEmpty) 'comment': comment,
        });
        changed = true;
      }

      if (_addIncident && _type != null) {
        await dio
            .post('/api/mobile/trips/${widget.item.tripId}/incidents', data: {
          'incident_type_id': _type!.id,
          if (comment.isNotEmpty) 'description': comment,
          if (_type!.requiresCanContinue)
            'can_continue_trip': _canContinue == true,
          'extra_data': {
            for (final f in _type!.extraFields)
              if ((_extraCtrls[f.key]?.text.trim() ?? '').isNotEmpty)
                f.key: _extraCtrls[f.key]!.text.trim(),
          },
        });
        changed = true;
      }

      if (mounted)
        Navigator.of(context)
            .pop(UnitSheetResult(comment: comment, changed: changed));
    } catch (e) {
      // Si el sub status ya se guardó y la incidencia falló, hay que refrescar igual.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _message(e);
          if (changed) {
            _changeStatus = false;
            _addSubStatus = false;
          }
        });
      }
    }
  }

  String _message(Object e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) {
        if (data['errors'] is Map && (data['errors'] as Map).isNotEmpty) {
          final first = (data['errors'] as Map).values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
          return first.toString();
        }
        if (data['message'] != null) return data['message'].toString();
      }
    } catch (_) {}
    return 'No se pudo guardar. Inténtalo de nuevo.';
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.fieldBorder),
        ),
      );

  Widget _selector(
      {required String label,
      required String? value,
      required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(value ?? label,
                  style: TextStyle(
                    color: value == null
                        ? AppColors.textLight
                        : AppColors.textDark,
                    fontSize: 14,
                    fontWeight:
                        value == null ? FontWeight.w500 : FontWeight.w700,
                  )),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.royalBlue),
          ],
        ),
      ),
    );
  }

  Widget _sectionSwitch(
      String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: _saving ? null : onChanged,
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppColors.royalBlue,
      title: Text(title,
          style: const TextStyle(
              color: AppColors.navyBlue,
              fontSize: 14.5,
              fontWeight: FontWeight.w800)),
    );
  }

  Widget _statusLine(String title, UnitStatusEntry? e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: '$title: ',
            style: const TextStyle(
                color: AppColors.textMedium,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        TextSpan(
            text: e?.label ?? 'Sin registro',
            style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.operatorName ?? '—',
                  style: const TextStyle(
                      color: AppColors.navyBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                  'Unidad ${item.unitNumber ?? '—'} · Caja ${item.truckboxNum ?? '—'}',
                  style: const TextStyle(
                      color: AppColors.textMedium, fontSize: 13)),
              const SizedBox(height: 12),
              _statusLine('Status', item.status),
              if (item.subStatus != null)
                _statusLine('Sub status', item.subStatus),
              const Divider(height: 28),
              if (!widget.reportOnly)
              _sectionSwitch('Cambiar status', _changeStatus, (v) {
                setState(() => _changeStatus = v);
                if (v) _loadStatuses();
              }),
              if (!widget.reportOnly && _changeStatus) ...[
                _selector(
                  label: 'Elige el nuevo status',
                  value: _newStatus?.name,
                  onTap: _statuses == null
                      ? null
                      : () async {
                          final picked = await _pick<_OpStatus>('Nuevo status',
                              _statuses!, (st) => st.name, _newStatus);
                          if (picked != null)
                            setState(() => _newStatus = picked);
                        },
                ),
                const SizedBox(height: 6),
              ],
              _sectionSwitch('Cambiar sub status', _addSubStatus, (v) {
                setState(() => _addSubStatus = v);
                if (v) _loadOptions();
              }),
              if (_addSubStatus) ...[
                _selector(
                  label: 'Elige el sub status',
                  value: _option?.name,
                  onTap: _options == null
                      ? null
                      : () async {
                          final picked = await _pick<_LogOption>(
                              'Sub status', _options!, (o) => o.name, _option);
                          if (picked != null) setState(() => _option = picked);
                        },
                ),
                if (_option?.requiresComment == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _option!.isOther
                          ? 'Escribe el sub status en el comentario.'
                          : 'Este sub status requiere comentario.',
                      style: const TextStyle(
                          color: AppColors.errorRed, fontSize: 12.5),
                    ),
                  ),
                const SizedBox(height: 6),
              ],
              _sectionSwitch('Reportar incidencia', _addIncident, (v) {
                setState(() => _addIncident = v);
                if (v) _loadCatalog();
              }),
              if (_addIncident) ...[
                _selector(
                  label: 'Categoría',
                  value: _category?.name,
                  onTap: _categories == null
                      ? null
                      : () async {
                          final picked = await _pick<_IncidentCategory>(
                              'Categoría',
                              _categories!,
                              (c) => c.name,
                              _category);
                          if (picked != null && picked != _category) {
                            setState(() {
                              _category = picked;
                              _type = null;
                              _canContinue = null;
                            });
                          }
                        },
                ),
                const SizedBox(height: 8),
                _selector(
                  label: 'Tipo de incidencia',
                  value: _type?.name,
                  onTap: _category == null
                      ? null
                      : () async {
                          final picked = await _pick<_IncidentType>(
                              'Tipo de incidencia',
                              _category!.types,
                              (t) => t.name,
                              _type);
                          if (picked != null) {
                            setState(() {
                              _type = picked;
                              _canContinue = null;
                              for (final c in _extraCtrls.values) {
                                c.clear();
                              }
                            });
                          }
                        },
                ),
                if (_type != null) ...[
                  if (_type!.description != null &&
                      _type!.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_type!.description!,
                          style: const TextStyle(
                              color: AppColors.textMedium, fontSize: 12.5)),
                    ),
                  if (_type!.requiresPhoto)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Este tipo requiere fotografía: no se puede registrar desde aquí.',
                        style: TextStyle(
                            color: AppColors.errorRed, fontSize: 12.5),
                      ),
                    ),
                  for (final f in _type!.extraFields) ...[
                    const SizedBox(height: 10),
                    Text('${f.label}${f.required ? ' *' : ''}',
                        style: const TextStyle(
                            color: AppColors.navyBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _extraCtrls.putIfAbsent(
                          f.key, () => TextEditingController()),
                      keyboardType:
                          f.numeric ? TextInputType.number : TextInputType.text,
                      decoration: _dec(f.label),
                    ),
                  ],
                  if (_type!.requiresCanContinue) ...[
                    const SizedBox(height: 10),
                    const Text('¿Es posible continuar el viaje? *',
                        style: TextStyle(
                            color: AppColors.navyBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(
                          child: _yesNo('Sí', _canContinue == true,
                              () => setState(() => _canContinue = true))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _yesNo('No', _canContinue == false,
                              () => setState(() => _canContinue = false))),
                    ]),
                  ],
                ],
              ],
              const Divider(height: 28),
              if (!widget.reportOnly)
              Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 18, color: AppColors.royalBlue),
                  const SizedBox(width: 8),
                  const Text('ETA',
                      style: TextStyle(
                          color: AppColors.navyBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Builder(builder: (_) {
                      final shown = _manualEta ?? item.eta?.at;
                      return Text.rich(TextSpan(children: [
                        TextSpan(
                          text: shown == null
                              ? 'Aún sin calcular'
                              : DateFormat("d MMM, HH:mm", 'es').format(shown),
                          style: TextStyle(
                            color: shown == null
                                ? AppColors.textLight
                                : AppColors.textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_manualEta != null)
                          const TextSpan(
                            text: '  (manual, se aplica al guardar)',
                            style: TextStyle(
                                color: Color(0xFFEF6C00), fontSize: 12),
                          ),
                      ]));
                    }),
                  ),
                  IconButton(
                    tooltip: 'Editar ETA',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_rounded,
                        size: 20, color: AppColors.royalBlue),
                    onPressed: _saving ? null : _editEta,
                  ),
                ],
              ),
              if (!widget.reportOnly) const SizedBox(height: 10),
              const Text('Comentario adicional',
                  style: TextStyle(
                      color: AppColors.navyBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: _comment,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                decoration: _dec('Escribe aquí un comentario para el reporte…'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.errorRed, fontSize: 13)),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.royalBlue,
                        side: const BorderSide(color: AppColors.royalBlue),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancelar',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.royalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Guardar',
                              style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _yesNo(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.royalBlue : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.royalBlue : AppColors.fieldBorder,
              width: 1.5),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textMedium,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}
