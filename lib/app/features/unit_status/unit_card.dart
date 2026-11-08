import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import 'unit_status_models.dart';

/// Tarjeta de una unidad del reporte: operador, unidad/caja, trayecto, origen →
/// destino, y su status y sub status (cada uno con fecha y hora). Se usa al
/// registrar (con [onTap] para abrir la hoja de edición) y en los reportes
/// anteriores (solo lectura: sin [onTap] y con [showElapsed] en false, porque
/// "hace X" no aplica a algo ya guardado).
class UnitStatusCard extends StatelessWidget {
  final UnitStatusItem item;
  final String? comment;
  final VoidCallback? onTap;
  final bool showElapsed;
  const UnitStatusCard({
    super.key,
    required this.item,
    this.comment,
    this.onTap,
    this.showElapsed = true,
  });

  String _dash(String? v) => (v == null || v.trim().isEmpty) ? '—' : v;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  (item.operatorName == null ||
                          item.operatorName!.trim().isEmpty)
                      ? 'Pendiente por asignar'
                      : item.operatorName!,
                  style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _Meta(
                      icon: Icons.local_shipping_outlined,
                      text: 'Unidad ${_dash(item.unitNumber)}'),
                  _Meta(
                      icon: Icons.inventory_2_outlined,
                      text: 'Caja ${_dash(item.truckboxNum)}'),
                ],
              ),
              if (item.tripKind.isNotEmpty) ...[
                const SizedBox(height: 6),
                _Meta(icon: Icons.alt_route_rounded, text: item.tripKind),
              ],
              // ETA: entre la caja y el origen → destino.
              const SizedBox(height: 6),
              _Meta(
                icon: Icons.schedule_rounded,
                text: item.eta?.at == null
                    ? 'ETA —'
                    : 'ETA ${DateFormat('d MMM, HH:mm').format(item.eta!.at!)}',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    child: Text(_dash(item.origin),
                        style: const TextStyle(
                            color: AppColors.textMedium,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: AppColors.royalBlue),
                  ),
                  Flexible(
                    child: Text(_dash(item.destination),
                        style: const TextStyle(
                            color: AppColors.textMedium,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const Divider(height: 24),
              _StatusRow(
                  title: 'Status',
                  entry: item.status,
                  showElapsed: showElapsed,
                  color: AppColors.royalBlue),
              // Sin sub status registrado, no se muestra la fila.
              if (item.subStatus != null) ...[
                const SizedBox(height: 10),
                _StatusRow(
                    title: 'Sub status',
                    entry: item.subStatus,
                    showElapsed: showElapsed,
                    color: const Color(0xFFEF6C00)),
              ],
              if ((comment ?? item.comment ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.comment_rounded,
                        size: 14, color: AppColors.textLight),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text((comment ?? item.comment)!,
                          style: const TextStyle(
                              color: AppColors.textMedium, fontSize: 12.5)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String title;
  final UnitStatusEntry? entry;
  final Color color;
  final bool showElapsed;
  const _StatusRow({
    required this.title,
    required this.entry,
    required this.color,
    this.showElapsed = true,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (entry?.at != null) DateFormat('d MMM, HH:mm').format(entry!.at!),
      if (showElapsed && entry?.elapsed != null) entry!.elapsed!,
    ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 74,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: entry == null
              ? const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('Sin registro',
                      style: TextStyle(
                          color: AppColors.textLight, fontSize: 13.5)),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry!.label,
                        style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800)),
                    if (meta.isNotEmpty)
                      Text(meta,
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 12)),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textLight),
        const SizedBox(width: 5),
        Text(text,
            style: const TextStyle(
                color: AppColors.textMedium,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
