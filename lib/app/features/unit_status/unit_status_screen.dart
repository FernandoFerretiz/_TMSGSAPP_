import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/design/sx_design.dart';
import '../../core/network/api_client.dart';
import 'unit_card.dart';
import 'unit_detail_sheet.dart';
import 'unit_reports_tab.dart';
import 'unit_report_draft_store.dart';
import 'unit_status_models.dart';

/// Reporte de unidades (staff): se elige el cliente y se listan los operadores
/// con viaje activo con ese cliente, con su status y su sub status. Cada tarjeta
/// se puede abrir para comentar o registrar un sub status / incidencia, y al
/// final "Generar reporte" guarda el status de todas las unidades.
class UnitStatusScreen extends StatefulWidget {
  /// Modo "Reportar por el operador": se elige cliente y un viaje registrado que
  /// no esté finalizado, y solo se registra un sub status o una incidencia (sin
  /// reporte de unidades, ETA ni cambio de status).
  final bool reportOnly;
  const UnitStatusScreen({super.key, this.reportOnly = false});

  @override
  State<UnitStatusScreen> createState() => _UnitStatusScreenState();
}

class _UnitStatusScreenState extends State<UnitStatusScreen> {
  List<UnitStatusClient> _clients = [];
  UnitStatusClient? _client;
  List<UnitStatusItem> _items = [];
  bool _loadingClients = true;
  bool _loadingItems = false;
  bool _generating = false;
  // Comentario adicional por viaje (se guarda en el reporte al generarlo).
  final Map<int, String> _comments = {};
  final _drafts = UnitReportDraftStore();
  // Avisa a la pestaña de reportes anteriores que hay uno nuevo.
  final _reportsRefresh = ValueNotifier<int>(0);
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() {
      _loadingClients = true;
      _error = null;
    });
    try {
      final res = await Get.find<ApiClient>().dio.get(widget.reportOnly
          ? '/api/mobile/staff-report/clients'
          : '/api/mobile/unit-statuses/clients');
      _clients = (res.data['data'] as List? ?? [])
          .map((e) => UnitStatusClient.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _error = 'No se pudieron cargar los clientes.';
    }
    if (mounted) setState(() => _loadingClients = false);
  }

  Future<void> _loadItems({bool silent = false}) async {
    final client = _client;
    if (client == null) return;
    if (!silent) {
      setState(() {
        _loadingItems = true;
        _error = null;
      });
    }
    try {
      final res = await Get.find<ApiClient>().dio.get(
          widget.reportOnly
              ? '/api/mobile/staff-report/trips'
              : '/api/mobile/unit-statuses',
          queryParameters: {'client_id': client.id});
      _items = (res.data['data'] as List? ?? [])
          .map((e) => UnitStatusItem.fromJson(e as Map<String, dynamic>))
          .toList();
      // Comentarios de viajes que ya no están activos ya no aplican.
      final ids = _items.map((i) => i.tripId).toSet();
      if (_comments.keys.any((id) => !ids.contains(id))) {
        _comments.removeWhere((id, _) => !ids.contains(id));
        _drafts.save(client.id, _comments);
      }
      _error = null;
    } catch (_) {
      _error = 'No se pudieron cargar los operadores.';
    }
    if (mounted) setState(() => _loadingItems = false);
  }

  Future<void> _pickClient() async {
    final picked = await showModalBottomSheet<UnitStatusClient>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ClientSheet(clients: _clients, selected: _client),
    );
    if (picked == null || picked.id == _client?.id) return;
    setState(() {
      _client = picked;
      _items = [];
      _comments.clear();
    });
    // Recupera los comentarios que quedaron sin generar el reporte.
    if (!widget.reportOnly) {
      final saved = await _drafts.load(picked.id);
      if (mounted && _client?.id == picked.id) {
        setState(() => _comments.addAll(saved));
      }
    }
    _loadItems();
  }

  Future<void> _openUnit(UnitStatusItem item) async {
    final result = await UnitDetailSheet.show(
      context,
      item: item,
      initialComment: _comments[item.tripId] ?? '',
      reportOnly: widget.reportOnly,
    );
    if (result == null || !mounted) return;
    if (widget.reportOnly) {
      if (result.changed) {
        Get.snackbar('Registrado', 'Se guardó el reporte del viaje.',
            backgroundColor: AppColors.royalBlue, colorText: Colors.white);
        _loadItems(silent: true);
      }
      return;
    }

    setState(() {
      if (result.comment.isEmpty) {
        _comments.remove(item.tripId);
      } else {
        _comments[item.tripId] = result.comment;
      }
    });
    if (_client != null) _drafts.save(_client!.id, _comments);
    if (result.changed) _loadItems(silent: true);
  }

  Future<void> _generateReport() async {
    final client = _client;
    if (client == null || _items.isEmpty || _generating) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Generar reporte',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text(
          'Se guardará el status y el sub status de las ${_items.length} '
          '${_items.length == 1 ? 'unidad' : 'unidades'} de ${client.name}.',
          style: const TextStyle(color: AppColors.textMedium, height: 1.4),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.royalBlue,
                foregroundColor: Colors.white),
            child: const Text('Generar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _generating = true);
    try {
      await Get.find<ApiClient>()
          .dio
          .post('/api/mobile/unit-statuses/report', data: {
        'client_id': client.id,
        'items': [
          for (final i in _items)
            {
              'trip_id': i.tripId,
              if ((_comments[i.tripId] ?? '').isNotEmpty)
                'comment': _comments[i.tripId]
            },
        ],
      });
      _comments.clear();
      await _drafts.clear(client.id);
      _reportsRefresh.value++;
      Get.snackbar('Reporte generado',
          'Se guardó el status de ${_items.length} unidades.',
          backgroundColor: AppColors.royalBlue, colorText: Colors.white);
    } catch (_) {
      Get.snackbar(
          'No se pudo generar', 'Revisa tu conexión e inténtalo de nuevo.',
          backgroundColor: AppColors.errorRed, colorText: Colors.white);
    }
    if (mounted) setState(() => _generating = false);
  }

  @override
  @override
  void dispose() {
    _reportsRefresh.dispose();
    super.dispose();
  }

  Widget _registerTab() {
    if (_loadingClients) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.royalBlue));
    }
    return RefreshIndicator(
      color: AppColors.royalBlue,
      onRefresh: () =>
          _client == null ? _loadClients() : _loadItems(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _ClientField(
              client: _client, onTap: _clients.isEmpty ? null : _pickClient),
          const SizedBox(height: 16),
          ..._body(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reportOnly) {
      return Scaffold(
        backgroundColor: Sx.pageBg,
        appBar: const SxAppBar(
          title: Text('Reportar por el operador',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        ),
        body: _registerTab(),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Sx.pageBg,
        appBar: const SxAppBar(
          title: Text('Reporte de unidades',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        ),
        body: Column(
          children: [
            Material(
              color: Colors.white,
              elevation: 1,
              child: TabBar(
                labelColor: AppColors.royalBlue,
                unselectedLabelColor: AppColors.textLight,
                indicatorColor: AppColors.royalBlue,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                tabs: const [
                  Tab(text: 'Registrar'),
                  Tab(text: 'Reportes anteriores')
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _registerTab(),
                  UnitReportsTab(refreshSignal: _reportsRefresh),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body() {
    if (_error != null) {
      return [_Message(icon: Icons.error_outline_rounded, text: _error!)];
    }
    if (_clients.isEmpty) {
      return [
        _Message(
          icon: Icons.inbox_outlined,
          text: widget.reportOnly
              ? 'No hay clientes con viajes sin finalizar.'
              : 'No hay clientes con operadores en viaje activo.',
        ),
      ];
    }
    if (_client == null) {
      return [
        _Message(
          icon: Icons.touch_app_rounded,
          text: widget.reportOnly
              ? 'Elige un cliente y luego el viaje del que quieres reportar.'
              : 'Elige un cliente para ver sus operadores con viaje activo.',
        ),
      ];
    }
    if (_loadingItems) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(
              child: CircularProgressIndicator(color: AppColors.royalBlue)),
        ),
      ];
    }
    if (_items.isEmpty) {
      return [
        _Message(
          icon: Icons.inbox_outlined,
          text: widget.reportOnly
              ? 'Este cliente no tiene viajes sin finalizar.'
              : 'Este cliente no tiene operadores con viaje activo.',
        ),
      ];
    }
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(
          widget.reportOnly
              ? 'Toca un viaje para reportar sub status o incidencia'
              : '${_items.length} ${_items.length == 1 ? 'viaje activo' : 'viajes activos'}',
          style: const TextStyle(
              color: AppColors.textMedium,
              fontSize: 12.5,
              fontWeight: FontWeight.w700),
        ),
      ),
      for (final item in _items)
        UnitStatusCard(
          item: item,
          comment: _comments[item.tripId],
          onTap: () => _openUnit(item),
        ),
      if (!widget.reportOnly) ...[
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _generating ? null : _generateReport,
          icon: _generating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.assignment_turned_in_rounded),
          label: const Text('Generar Reporte'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.royalBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      ],
    ];
  }
}

class _ClientField extends StatelessWidget {
  final UnitStatusClient? client;
  final VoidCallback? onTap;
  const _ClientField({required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.fieldBorder, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.business_rounded,
                color: AppColors.royalBlue, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cliente',
                      style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    client?.name ?? 'Selecciona un cliente',
                    style: TextStyle(
                      color: client == null
                          ? AppColors.textMedium
                          : AppColors.textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.royalBlue),
          ],
        ),
      ),
    );
  }
}

class _ClientSheet extends StatelessWidget {
  final List<UnitStatusClient> clients;
  final UnitStatusClient? selected;
  const _ClientSheet({required this.clients, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Elige el cliente',
                  style: TextStyle(
                      color: AppColors.navyBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: clients.length,
                itemBuilder: (_, i) {
                  final c = clients[i];
                  final isSelected = c.id == selected?.id;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    tileColor: isSelected ? const Color(0xFFE3EEFF) : null,
                    title: Text(c.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.royalBlue)
                        : null,
                    onTap: () => Navigator.of(context).pop(c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.royalBlue),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textMedium, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}
