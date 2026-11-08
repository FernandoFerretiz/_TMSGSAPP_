import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/design/sx_design.dart';
import '../../../core/network/api_client.dart';
import '../../../utils/helpers/server_time.dart';

/// "Pendientes turno anterior": comentarios que dejó quien cerró turno. Hay que
/// marcar cada uno como enterado y confirmar. Devuelve true si se confirmó.
class ShiftHandoversScreen extends StatefulWidget {
  const ShiftHandoversScreen({super.key});

  @override
  State<ShiftHandoversScreen> createState() => _ShiftHandoversScreenState();
}

class _ShiftHandoversScreenState extends State<ShiftHandoversScreen> {
  final _dio = Get.find<ApiClient>().dio;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  final Set<int> _checked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _dio.get('/api/mobile/shift/handovers');
      _items = ((r.data as Map)['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      _error = 'No se pudieron cargar los pendientes. Revisa tu conexión.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _confirm() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _dio.post('/api/mobile/shift/handovers/acknowledge',
          data: {'ids': _items.map((e) => e['id']).toList()});
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo confirmar. Inténtalo de nuevo.';
        });
      }
    }
  }

  String _when(dynamic v) {
    final d = parseServerDateTime(v?.toString());
    return d == null ? '' : DateFormat('d MMM, HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final all = _items.isNotEmpty && _checked.length == _items.length;
    return Scaffold(
      backgroundColor: Sx.pageBg,
      appBar: SxAppBar(title: const Text('Pendientes turno anterior')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final n in _items)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: CheckboxListTile(
                            value: _checked.contains(n['id']),
                            onChanged: (v) => setState(() => v == true
                                ? _checked.add(n['id'] as int)
                                : _checked.remove(n['id'])),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text('${n['body']}',
                                style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(
                                '${n['author'] ?? ''} · ${_when(n['created_at'])}\nMarcar como enterado',
                                style: const TextStyle(
                                    color: AppColors.textLight, fontSize: 12)),
                            isThreeLine: true,
                          ),
                        ),
                      if (_items.isEmpty)
                        const Center(
                            child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No hay pendientes del turno anterior.'),
                        )),
                      if (_error != null)
                        Text(_error!,
                            style: const TextStyle(color: AppColors.errorRed)),
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
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: all && !_saving ? _confirm : null,
                        child: Text(_saving ? 'Confirmando...' : 'Confirmar enterado'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
