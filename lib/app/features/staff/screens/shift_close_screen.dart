import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/routes/route_names.dart';
import '../../../core/config/app_config.dart';
import '../../../core/design/sx_design.dart';
import '../../../core/network/api_client.dart';
import '../../circuit_trip/controllers/circuit_trip_form_controller.dart';

/// "Pendientes antes de cerrar turno": comentarios de relevo, viajes sin link de
/// evidencias y comprobación del último reporte de unidades. Devuelve true si el
/// turno se finalizó.
class ShiftCloseScreen extends StatefulWidget {
  const ShiftCloseScreen({super.key});

  @override
  State<ShiftCloseScreen> createState() => _ShiftCloseScreenState();
}

class _ShiftCloseScreenState extends State<ShiftCloseScreen> {
  final _dio = Get.find<ApiClient>().dio;
  final _noteCtrl = TextEditingController();
  final List<String> _notes = [];

  bool _loading = true;
  bool _closing = false;
  String? _error;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _confirmed = [];
  Map<String, dynamic> _report = {};
  final Set<int> _busyTrips = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _list(dynamic v) =>
      (v as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _dio.get('/api/mobile/shift/close-summary');
      final d = Map<String, dynamic>.from(r.data as Map);
      _pending = _list(d['pending_links']);
      _confirmed = _list(d['confirmed_no_link']);
      _report = Map<String, dynamic>.from(d['last_report'] as Map? ?? {});
    } catch (_) {
      _error = 'No se pudieron cargar los pendientes. Revisa tu conexión.';
    }
    if (mounted) setState(() => _loading = false);
  }

  String _message(Object e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) {
        if (data['errors'] is Map && (data['errors'] as Map).isNotEmpty) {
          final first = (data['errors'] as Map).values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
        }
        if (data['message'] != null) return data['message'].toString();
      }
    } catch (_) {}
    return 'No se pudo completar la acción. Inténtalo de nuevo.';
  }

  void _addNote() {
    final t = _noteCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _notes.add(t);
      _noteCtrl.clear();
    });
  }

  Future<void> _resolve(int tripId, Map<String, dynamic> body) async {
    setState(() => _busyTrips.add(tripId));
    try {
      await _dio.post('/api/mobile/trips/$tripId/evidence-link', data: body);
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
    if (mounted) setState(() => _busyTrips.remove(tripId));
  }

  Future<void> _askLink(Map<String, dynamic> trip) async {
    final link = await showDialog<String>(
      context: context,
      builder: (_) => _LinkDialog(tripNumber: '${trip['trip_number']}'),
    );
    if (link != null) await _resolve(trip['trip_id'] as int, {'link': link});
  }

  Future<void> _close() async {
    // Lo escrito en el campo sin agregar también cuenta.
    _addNote();
    setState(() {
      _closing = true;
      _error = null;
    });
    try {
      await _dio.post('/api/mobile/shift/end', data: {'handover_notes': _notes});
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _closing = false;
          _error = _message(e);
        });
        _load();
      }
    }
  }

  Widget _section(String title, {required Widget child, String? hint}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: AppColors.navyBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(hint,
                  style: const TextStyle(
                      color: AppColors.textMedium, fontSize: 12.5)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _notesSection() => _section(
        'Comentarios de fin de turno',
        hint: 'Los verá el siguiente turno hasta que los marque como enterado.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _notes.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: Text(_notes[i],
                            style: const TextStyle(
                                color: AppColors.textDark, fontSize: 14))),
                    InkWell(
                      onTap: () => setState(() => _notes.removeAt(i)),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: AppColors.textLight),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _noteCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Escribe un comentario para el siguiente turno',
                filled: true,
                fillColor: AppColors.fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.fieldBorder),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addNote,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Agregar comentario'),
              ),
            ),
          ],
        ),
      );

  Widget _tripRow(Map<String, dynamic> t, {required bool pending}) {
    final busy = _busyTrips.contains(t['trip_id']);
    final route = [t['origin'], t['destination']]
        .where((e) => e != null && '$e'.isNotEmpty)
        .join(' → ');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pending ? const Color(0xFFFFF4E5) : AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Viaje ${t['trip_number']} · ${t['client_name'] ?? ''}',
              style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          Text('${t['operator_name'] ?? ''}${route.isEmpty ? '' : '\n$route'}',
              style: const TextStyle(color: AppColors.textMedium, fontSize: 12.5)),
          const SizedBox(height: 6),
          if (pending)
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: busy ? null : () => _askLink(t),
                  child: const Text('Registrar link'),
                ),
                OutlinedButton(
                  onPressed:
                      busy ? null : () => _resolve(t['trip_id'] as int, {'confirm_none': true}),
                  child: const Text('Confirmar sin link'),
                ),
              ],
            )
          else
            const Text('Confirmado sin link: ya no se solicita',
                style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _linksSection() => _section(
        'Viajes sin link de evidencias',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_pending.isEmpty && _confirmed.isEmpty)
              const Text('Todos los viajes tienen su link.',
                  style: TextStyle(color: AppColors.textMedium)),
            if (_pending.isNotEmpty)
              Text(
                  _pending.length == 1
                      ? '1 viaje sigue sin link'
                      : '${_pending.length} viajes siguen sin link',
                  style: const TextStyle(
                      color: AppColors.errorRed, fontWeight: FontWeight.w800)),
            if (_pending.isNotEmpty) const SizedBox(height: 8),
            for (final t in _pending) _tripRow(t, pending: true),
            for (final t in _confirmed) _tripRow(t, pending: false),
          ],
        ),
      );

  Widget _reportSection() {
    final ok = _report['ok'] == true;
    final mins = _report['minutes_ago'];
    final max = _report['max_minutes'] ?? 20;
    final text = mins == null
        ? 'Aún no hay ningún reporte de unidades.'
        : ok
            ? 'Último reporte generado hace $mins min.'
            : 'El último reporte tiene más de $max min (hace $mins min).';
    return _section(
      'Último reporte de unidades',
      hint: 'Debe tener menos de $max minutos para poder cerrar turno.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: ok ? const Color(0xFF15803D) : AppColors.errorRed),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(text,
                      style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w700))),
            ],
          ),
          if (!ok)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                onPressed: () async {
                  await Get.toNamed(RouteNames.unitStatuses);
                  _load();
                },
                child: const Text('Generar reporte de unidades'),
              ),
            ),
          TextButton(onPressed: _load, child: const Text('Actualizar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canClose = !_loading && !_closing && _report['ok'] == true;
    return Scaffold(
      backgroundColor: Sx.pageBg,
      appBar: SxAppBar(title: const Text('Pendientes antes de cerrar turno')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _notesSection(),
                      _linksSection(),
                      _reportSection(),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_error!,
                              style: const TextStyle(color: AppColors.errorRed)),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.errorRed,
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: canClose ? _close : null,
                        child: Text(_closing ? 'Finalizando...' : 'Finalizar turno'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Diálogo para registrar el link; el controlador vive y muere con el diálogo.
class _LinkDialog extends StatefulWidget {
  final String tripNumber;
  const _LinkDialog({required this.tripNumber});

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _ctrl = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Link del viaje ${widget.tripNumber}'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(hintText: 'https://...', errorText: _err),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final v = CircuitTripFormController.validLink(_ctrl.text);
            if (v == null) {
              setState(() => _err = 'Escribe un link válido (https://...)');
              return;
            }
            Navigator.of(context).pop(v);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
