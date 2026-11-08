import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/design/sx_design.dart';
import '../../../core/network/api_client.dart';
import '../../../utils/helpers/server_time.dart';

/// Open operational alerts sent to the staff member. "Ya lo estoy atendiendo"
/// stops the escalation chain on the server; "Resolver" closes the alert.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final Dio _dio = Get.find<ApiClient>().dio;

  List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;
  bool _failed = false;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final response = await _dio.get('/api/mobile/alerts');
      final data = (response.data as Map)['data'] as List;
      _alerts = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      _failed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(int id, String action) async {
    setState(() => _busy.add(id));
    try {
      await _dio.post('/api/mobile/alerts/$id/$action');
      await _load();
    } catch (_) {
      Get.snackbar('Alertas', 'No se pudo completar la acción. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sx.pageBg,
      appBar: SxAppBar(title: const Text('Alertas')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _failed
                ? ListView(children: [
                    const SizedBox(height: 120),
                    const Center(child: Text('No se pudieron cargar las alertas')),
                    Center(child: TextButton(onPressed: _load, child: const Text('Reintentar'))),
                  ])
                : _alerts.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No tienes alertas abiertas')),
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _alerts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _card(_alerts[i]),
                      ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> alert) {
    final id = alert['id'] as int;
    final inAttention = alert['status'] == 'in_attention';
    final mine = alert['acknowledged_by_me'] == true;
    final created = parseServerDateTime(alert['created_at']);
    final busy = _busy.contains(id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: inAttention ? AppColors.royalBlue : AppColors.errorRed),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alert['title']?.toString() ?? '',
            style: const TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if ((alert['body']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(alert['body'].toString(), style: const TextStyle(color: AppColors.textMedium)),
          ],
          const SizedBox(height: 4),
          Text(
            [
              'Viaje #${alert['trip_number'] ?? alert['trip_id']}',
              if (created != null) DateFormat('d MMM, HH:mm').format(created),
            ].join(' · '),
            style: const TextStyle(color: AppColors.textLight),
          ),
          const SizedBox(height: 12),
          if (inAttention)
            Text(
              mine ? 'La estás atendiendo' : 'La atiende ${alert['acknowledged_by'] ?? 'otra persona'}',
              style: const TextStyle(color: AppColors.royalBlue, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (!inAttention)
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => _act(id, 'acknowledge'),
                    child: const Text('Ya lo estoy atendiendo'),
                  ),
                ),
              if (!inAttention) const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.textMedium),
                  onPressed: busy ? null : () => _act(id, 'resolve'),
                  child: const Text('Resolver'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
