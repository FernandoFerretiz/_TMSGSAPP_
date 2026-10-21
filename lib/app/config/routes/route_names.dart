/// Standalone route name constants — no imports, no circular dependencies.
abstract class RouteNames {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String activateAccount = '/activate-account';
  static const String home = '/home';
  static const String dashboard = '/dashboard';

  // Trip flow
  static const String startTrip = '/trip/start';
  static const String tripDocuments = '/trip/start/documents';
  static const String tripAdditionalMaterials =
      '/trip/start/additional-materials';
  static const String tripSeal = '/trip/start/seal';
  static const String tripChecklist = '/trip/start/checklist';
  static const String changeStatus = '/trip/change-status';
  static const String tripDetail = '/trip/detail';
  static const String reportIncident = '/trip/incident';
  static const String tripHistoryList = '/trips/history';
  static const String tripEventHistory = '/trips/history/detail';
  static const String lastEvents = '/events/recent';

  // Chatbot
  static const String chatbot = '/chatbot';

  // Alta de viajes de circuito (formulario, sin chatbot)
  static const String circuitTripForm = '/circuit-trips/new';

  // Cobertura de turno
  static const String shiftCoverageList = '/shift-coverage';
  static const String shiftCoverageStart = '/shift-coverage/start';
}
