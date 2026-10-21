import 'package:get/get.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/activate_account_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/bindings/home_binding.dart';
import '../../features/trips/screens/start_trip_screen.dart';
import '../../features/trips/screens/trip_checklist_screen.dart';
import '../../features/trips/screens/trip_detail_screen.dart';
import '../../features/trips/screens/trip_documents_screen.dart';
import '../../features/trips/screens/trip_additional_materials_screen.dart';
import '../../features/trips/screens/seal_capture_screen.dart';
// DashboardBinding is declared as `part of dashboard` inside dashboard_screen.dart
import '../../features/dashboard/views/screens/dashboard_screen.dart';
import '../../features/chatbot/screens/chatbot_screen.dart';
import '../../features/chatbot/bindings/chatbot_binding.dart';
import '../../features/incidents/screens/report_incident_screen.dart';
import '../../features/incidents/bindings/incident_binding.dart';
import '../../features/trip_history/screens/trip_history_list_screen.dart';
import '../../features/trip_history/screens/trip_event_history_screen.dart';
import '../../features/trip_history/screens/last_events_screen.dart';
import '../../features/circuit_trip/screens/circuit_trip_form_screen.dart';
import '../../features/circuit_trip/bindings/circuit_trip_binding.dart';
import '../../features/trip_history/bindings/trip_history_binding.dart';
import '../../features/shift_coverage/screens/shift_coverage_list_screen.dart';
import '../../features/shift_coverage/screens/start_coverage_screen.dart';
import '../../features/shift_coverage/bindings/shift_coverage_binding.dart';
import '../../features/staff/screens/staff_home_screen.dart';
import '../app_flavor.dart';
import 'route_names.dart';

part 'app_routes.dart';

class AppPages {
  static const initial = RouteNames.splash;

  static List<GetPage> get routes => [
        ..._commonRoutes,
        ...(AppFlavor.current.isStaff ? _staffRoutes : _operatorRoutes),
      ];

  static final _commonRoutes = <GetPage>[
    GetPage(
      name: _Paths.splash,
      page: () => const SplashScreen(),
    ),
    GetPage(
      name: _Paths.login,
      page: () => const LoginScreen(),
    ),
    GetPage(
      name: _Paths.activateAccount,
      page: () => const ActivateAccountScreen(),
    ),
  ];

  /// Historial de eventos, consulta de viajes y alta de asignaciones.
  static final _staffAndOperatorRoutes = <GetPage>[
    GetPage(
      name: _Paths.tripHistoryList,
      page: () => const TripHistoryListScreen(),
      binding: TripHistoryBinding(),
    ),
    GetPage(
      name: _Paths.tripEventHistory,
      page: () => const TripEventHistoryScreen(),
      binding: TripHistoryBinding(),
    ),
    GetPage(
      name: _Paths.lastEvents,
      page: () => const LastEventsScreen(),
      binding: TripHistoryBinding(),
    ),
    GetPage(
      name: _Paths.circuitTripForm,
      page: () => const CircuitTripFormScreen(),
      binding: CircuitTripBinding(),
    ),
  ];

  static final _staffRoutes = <GetPage>[
    ..._staffAndOperatorRoutes,
    GetPage(
      name: _Paths.home,
      page: () => const StaffHomeScreen(),
    ),
  ];

  static final _operatorRoutes = <GetPage>[
    ..._staffAndOperatorRoutes,
    GetPage(
      name: _Paths.home,
      page: () => const HomeScreen(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.startTrip,
      page: () => const StartTripScreen(),
    ),
    GetPage(
      name: _Paths.tripDocuments,
      page: () => const TripDocumentsScreen(),
    ),
    GetPage(
      name: _Paths.tripAdditionalMaterials,
      page: () => const TripAdditionalMaterialsScreen(),
    ),
    GetPage(
      name: _Paths.tripSeal,
      page: () => const SealCaptureScreen(),
    ),
    GetPage(
      name: _Paths.tripChecklist,
      page: () => const TripChecklistScreen(),
    ),
    GetPage(
      name: _Paths.changeStatus,
      page: () => const ChangeStatusScreen(),
    ),
    GetPage(
      name: _Paths.dashboard,
      page: () => const DashboardScreen(),
      binding: DashboardBinding(),
    ),
    GetPage(
      name: _Paths.tripDetail,
      page: () => const TripDetailScreen(),
    ),
    GetPage(
      name: _Paths.reportIncident,
      page: () => const ReportIncidentScreen(),
      binding: IncidentBinding(),
    ),
    GetPage(
      name: _Paths.chatbot,
      page: () => const ChatBotScreen(),
      binding: ChatBotBinding(),
    ),
    GetPage(
      name: _Paths.shiftCoverageList,
      page: () => const ShiftCoverageListScreen(),
      binding: ShiftCoverageBinding(),
    ),
    GetPage(
      name: _Paths.shiftCoverageStart,
      page: () => const StartCoverageScreen(),
      binding: ShiftCoverageBinding(),
    ),
  ];
}
