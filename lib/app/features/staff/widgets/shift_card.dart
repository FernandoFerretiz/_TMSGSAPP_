import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../utils/helpers/server_time.dart';
import '../screens/shift_close_screen.dart';

/// Start / end of the staff member's shift. The server owns the state (and the
/// history); shifts never close automatically, only when the user ends them.
class ShiftCard extends StatefulWidget {
  const ShiftCard({super.key, this.onShiftChanged, this.pendingHandovers});

  /// Avisa el estado del turno (null mientras carga o si no se pudo consultar).
  final ValueNotifier<bool?>? onShiftChanged;

  /// Avisa cuántos pendientes del turno anterior le faltan por confirmar a este usuario.
  final ValueNotifier<int>? pendingHandovers;

  @override
  State<ShiftCard> createState() => ShiftCardState();
}

class ShiftCardState extends State<ShiftCard> {
  final Dio _dio = Get.find<ApiClient>().dio;

  bool _loading = true;
  bool _busy = false;
  bool _failed = false;
  bool _onShift = false;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _call('get', '/api/mobile/shift');
  }

  /// Vuelve a consultar el turno y los pendientes (pull to refresh del inicio).
  Future<void> refresh() => _call('get', '/api/mobile/shift');

  Future<void> _call(String method, String path) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final response = method == 'get' ? await _dio.get(path) : await _dio.post(path);
      final data = Map<String, dynamic>.from(response.data as Map);
      _onShift = data['on_shift'] == true;
      widget.pendingHandovers?.value = (data['pending_handovers'] as num?)?.toInt() ?? 0;
      _startedAt = data['started_at'] != null
          ? parseServerDateTime(data['started_at'])
          : null;
    } catch (_) {
      _failed = true;
    } finally {
      widget.onShiftChanged?.value = _failed ? null : _onShift;
      if (mounted) {
        setState(() {
          _loading = false;
          _busy = false;
        });
      }
    }
  }

  /// Finalizar abre "Pendientes antes de cerrar turno"; el cierre se hace desde ahí.
  Future<void> _end() async {
    final closed = await Get.to<bool>(() => const ShiftCloseScreen());
    if (closed == true) await _call('get', '/api/mobile/shift');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final String status;
    if (_failed) {
      status = 'No se pudo consultar el turno';
    } else if (_onShift) {
      final since = _startedAt != null ? DateFormat('d MMM, HH:mm').format(_startedAt!) : '';
      status = since.isEmpty ? 'Turno iniciado' : 'Turno iniciado desde $since';
    } else {
      status = 'Sin turno iniciado';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _onShift ? AppColors.royalBlue : AppColors.fieldBorder),
      ),
      child: Row(
        children: [
          Icon(
            _onShift ? Icons.timer_rounded : Icons.timer_off_outlined,
            color: _onShift ? AppColors.royalBlue : AppColors.textMedium,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status,
              style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          if (_failed)
            FilledButton(
              onPressed: _busy ? null : () => _call('get', '/api/mobile/shift'),
              child: const Text('Reintentar'),
            )
          else if (_onShift)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
              onPressed: _busy ? null : _end,
              child: const Text('Finalizar turno'),
            )
          else
            FilledButton(
              onPressed: _busy ? null : () => _call('post', '/api/mobile/shift/start'),
              child: const Text('Iniciar turno'),
            ),
        ],
      ),
    );
  }
}
