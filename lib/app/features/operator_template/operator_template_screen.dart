import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/design/sx_design.dart';
import '../../core/network/api_client.dart';
import '../../shared_components/sultan_share_dialog.dart';
import 'operator_template.dart';

/// Plantillas de operadores: lista los operadores activos con los datos de su
/// viaje abierto y permite compartir la plantilla de uno o varios.
class OperatorTemplateScreen extends StatefulWidget {
  const OperatorTemplateScreen({super.key});

  @override
  State<OperatorTemplateScreen> createState() => _OperatorTemplateScreenState();
}

class _OperatorTemplateScreenState extends State<OperatorTemplateScreen> {
  List<OperatorTemplate> _items = [];
  final Set<int> _selected = {};
  String _query = '';
  // Por defecto solo operadores activos; se piden todos y se filtra aquí.
  _StatusFilter _status = _StatusFilter.active;
  int? _transporterId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await Get.find<ApiClient>()
          .dio
          .get('/api/mobile/operator-templates', queryParameters: {'status': 'all'});
      final data = (response.data as Map<String, dynamic>)['data'] as List? ?? [];
      _items = data
          .map((e) => OperatorTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
      _selected.removeWhere((id) => !_items.any((t) => t.id == id));
    } catch (_) {
      _error = 'No se pudieron cargar las plantillas.';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<OperatorTemplate> get _visible => _items.where((t) {
        if (_status == _StatusFilter.active && !t.isActive) return false;
        if (_status == _StatusFilter.inactive && t.isActive) return false;
        if (_transporterId != null && t.transporterId != _transporterId) return false;
        return _query.isEmpty || t.matches(_query);
      }).toList();

  bool get _filtersApplied => _status != _StatusFilter.active || _transporterId != null;

  /// Transportistas presentes en la lista (id → nombre de línea).
  Map<int, String> get _transporters {
    final map = <int, String>{};
    for (final t in _items) {
      if (t.transporterId != null && t.linea.isNotEmpty) map[t.transporterId!] = t.linea;
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase())));
  }

  Future<void> _openFilters() async {
    final transporters = _transporters;
    var status = _status;
    int? transporterId = _transporterId;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtrar',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.navyBlue)),
              const SizedBox(height: 16),
              const Text('Status', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in _StatusFilter.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: status == s,
                      onSelected: (_) => setSheet(() => status = s),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Transportista', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                key: ValueKey(transporterId),
                initialValue: transporters.containsKey(transporterId) ? transporterId : null,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
                  for (final e in transporters.entries)
                    DropdownMenuItem<int?>(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setSheet(() => transporterId = v),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setSheet(() {
                        status = _StatusFilter.active;
                        transporterId = null;
                      }),
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Filtrar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (applied == true) {
      setState(() {
        _status = status;
        _transporterId = transporterId;
      });
    }
  }

  void _toggle(OperatorTemplate t) => setState(() {
        if (!_selected.add(t.id)) _selected.remove(t.id);
      });

  void _shareSelected() {
    final picked = _items.where((t) => _selected.contains(t.id));
    SultanShareDialog.showTextOnly(context, text: joinTemplates(picked));
  }

  @override
  Widget build(BuildContext context) {
    final selecting = _selected.isNotEmpty;
    return Scaffold(
      backgroundColor: Sx.pageBg,
      appBar: SxAppBar(
        title: Text(
          selecting ? '${_selected.length} seleccionados' : 'Plantillas de operadores',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            tooltip: 'Filtrar',
            icon: Badge(
              isLabelVisible: _filtersApplied,
              smallSize: 8,
              child: const Icon(Icons.filter_list_rounded),
            ),
            onPressed: _openFilters,
          ),
          if (selecting)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(_selected.clear),
            ),
        ],
      ),
      floatingActionButton: selecting
          ? FloatingActionButton.extended(
              onPressed: _shareSelected,
              backgroundColor: AppColors.royalBlue,
              icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
              label: const Text('Obtener plantilla',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Buscar operador, unidad, placas, línea...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.royalBlue));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    final items = _visible;
    if (items.isEmpty) {
      return const Center(child: Text('Sin operadores'));
    }
    return RefreshIndicator(
      color: AppColors.royalBlue,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _TemplateCard(
          item: items[i],
          selected: _selected.contains(items[i].id),
          selecting: _selected.isNotEmpty,
          onTap: () => _selected.isNotEmpty
              ? _toggle(items[i])
              : SultanShareDialog.showTextOnly(context, text: items[i].text),
          onLongPress: () => _toggle(items[i]),
        ),
      ),
    );
  }
}

enum _StatusFilter {
  active('Activos'),
  inactive('Inactivos'),
  all('Todos');

  final String label;
  const _StatusFilter(this.label);
}

class _TemplateCard extends StatelessWidget {
  final OperatorTemplate item;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TemplateCard({
    required this.item,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    String v(String s) => s.isEmpty ? '—' : s;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.royalBlue : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.operador,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.navyBlue)),
                    const SizedBox(height: 6),
                    Text('${v(item.linea)} · Unidad ${v(item.unidad)} · ${v(item.placas)}'),
                    Text('${v(item.trayecto)} · ${v(item.planta)} · Caja ${v(item.caja)}',
                        style: const TextStyle(color: AppColors.textMedium)),
                  ],
                ),
              ),
              if (selecting)
                Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: AppColors.royalBlue),
            ],
          ),
        ),
      ),
    );
  }
}
