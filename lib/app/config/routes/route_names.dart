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
  static const String reportHub = '/trip/report';
  static const String tripLogStatus = '/trip/report/status';
  static const String tripHistoryList = '/trips/history';
  static const String tripEventHistory = '/trips/history/detail';
  static const String lastEvents = '/events/recent';

  // Alta de viajes de circuito (formulario, sin chatbot)
  static const String circuitTripForm = '/circuit-trips/new';

  // Generar status de unidades (staff)
  static const String unitStatuses = '/unit-statuses';
  static const String staffReport = '/staff-report';

  // Plantillas de operadores (staff) — ya no se ofrece en el home; ruta sin uso
  static const String operatorTemplates = '/operator-templates';

  // Alertas con escalamiento (staff)
  static const String alerts = '/alerts';

  // Gastos internos (staff)
  static const String internalExpenses = '/internal-expenses';
  static const String internalExpenseDetail = '/internal-expenses/detail';
  static const String internalExpenseForm = '/internal-expenses/form';
  static const String internalExpenseCalendar = '/internal-expenses/calendar';

  // Cobertura de turno
  static const String shiftCoverageList = '/shift-coverage';
  static const String shiftCoverageStart = '/shift-coverage/start';
}
