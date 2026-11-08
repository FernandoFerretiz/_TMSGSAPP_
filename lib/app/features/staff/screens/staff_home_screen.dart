import '../../../core/design/sx_design.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../config/routes/route_names.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/widgets/home_action_card.dart';
import '../widgets/shift_card.dart';
import 'shift_handovers_screen.dart';

/// Landing screen of the staff flavor.
class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  final ValueNotifier<bool?> _onShift = ValueNotifier<bool?>(null);
  final GlobalKey<ShiftCardState> _shiftKey = GlobalKey<ShiftCardState>();
  final ValueNotifier<int> _handovers = ValueNotifier<int>(0);

  @override
  void dispose() {
    _onShift.dispose();
    _handovers.dispose();
    super.dispose();
  }

  /// Crear una asignación exige tener el turno iniciado; el estado del turno
  /// lo tiene el servidor, así que se consulta al momento.
  Future<void> _openCircuitTripForm() async {
    bool onShift;
    try {
      final Dio dio = Get.find<ApiClient>().dio;
      final response = await dio.get('/api/mobile/shift');
      onShift = (response.data as Map)['on_shift'] == true;
    } catch (_) {
      Get.snackbar(
        'No se pudo verificar el turno',
        'Revisa tu conexión e inténtalo de nuevo.',
        backgroundColor: AppColors.royalBlue,
        colorText: Colors.white,
      );
      return;
    }

    if (!onShift) {
      Get.snackbar(
        'Turno no iniciado',
        'Inicia tu turno para poder crear una asignación.',
        backgroundColor: AppColors.royalBlue,
        colorText: Colors.white,
      );
      return;
    }
    Get.toNamed(RouteNames.circuitTripForm);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sx.pageBg,
      appBar: SxAppBar(
        title: const Text('TMS Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: Get.find<AuthController>().logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _shiftKey.currentState?.refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShiftCard(
                  key: _shiftKey,
                  onShiftChanged: _onShift,
                  pendingHandovers: _handovers),
              const Text(
                'Acciones Rápidas',
                style: TextStyle(
                  color: AppColors.navyBlue,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              // Comentarios que dejó quien cerró turno; desaparece al confirmarlos todos.
              ValueListenableBuilder<int>(
                valueListenable: _handovers,
                builder: (context, count, _) => count == 0
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: HomeActionCard(
                          icon: Icons.assignment_late_rounded,
                          title: 'Pendientes turno anterior',
                          subtitle: count == 1
                              ? '1 pendiente por confirmar'
                              : '$count pendientes por confirmar',
                          highlight: true,
                          onTap: () async {
                            final done = await Get.to<bool>(
                                () => const ShiftHandoversScreen());
                            if (done == true) _handovers.value = 0;
                          },
                        ),
                      ),
              ),
              ValueListenableBuilder<bool?>(
                valueListenable: _onShift,
                builder: (context, onShift, _) => HomeActionCard(
                  icon: Icons.add_circle_rounded,
                  title: 'Crear asignación',
                  subtitle: onShift == false
                      ? 'Inicia tu turno para crear asignaciones'
                      : 'Dar de alta un nuevo viaje',
                  highlight: true,
                  disabled: onShift == false,
                  onTap: _openCircuitTripForm,
                ),
              ),
              const SizedBox(height: 14),
              HomeActionCard(
                icon: Icons.list_alt_rounded,
                title: 'Viajes',
                subtitle: 'Consultar viajes y su historial',
                onTap: () => Get.toNamed(RouteNames.tripHistoryList),
              ),
              const SizedBox(height: 14),
              HomeActionCard(
                icon: Icons.notification_important_rounded,
                title: 'Alertas',
                subtitle: 'Alertas abiertas: marcar que ya las atiendes',
                onTap: () => Get.toNamed(RouteNames.alerts),
              ),
              const SizedBox(height: 14),
              HomeActionCard(
                icon: Icons.event_note_rounded,
                title: 'Historial de eventos',
                subtitle: 'Cambios de estado, incidencias y detenciones',
                onTap: () => Get.toNamed(RouteNames.lastEvents),
              ),
              const SizedBox(height: 14),
              HomeActionCard(
                icon: Icons.fact_check_rounded,
                title: 'Reporte de unidades',
                subtitle:
                    'Status y sub status de los operadores con viaje activo',
                onTap: () => Get.toNamed(RouteNames.unitStatuses),
              ),
              const SizedBox(height: 14),
              HomeActionCard(
                icon: Icons.report_problem_rounded,
                iconColor: const Color(0xFFFFB74D),
                title: 'Reportar por el operador',
                subtitle:
                    'Registrar sub status o incidencia de un viaje sin finalizar',
                onTap: () => Get.toNamed(RouteNames.staffReport),
              ),
              // Gastos internos: solo para quien tenga el permiso (el servidor lo vuelve a exigir en cada llamada).
              if (Get.find<AuthController>()
                  .hasPermission('internal_expense.index')) ...[
                const SizedBox(height: 14),
                HomeActionCard(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Gastos internos',
                  subtitle: 'Resumen, vencimientos, pagos y calendario',
                  onTap: () => Get.toNamed(RouteNames.internalExpenses),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
