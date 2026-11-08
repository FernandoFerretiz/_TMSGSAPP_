/// Plantilla de un operador (misma que la pantalla web "Plantillas de
/// operadores"): trayecto/planta/caja vienen de su viaje abierto.
class OperatorTemplate {
  final int id;
  final int? transporterId;
  final bool isActive;
  final String linea;
  final String unidad;
  final String operador;
  final String placas;
  final String trayecto;
  final String planta;
  final String caja;
  final String status;

  const OperatorTemplate({
    required this.id,
    this.transporterId,
    this.isActive = true,
    required this.linea,
    required this.unidad,
    required this.operador,
    required this.placas,
    required this.trayecto,
    required this.planta,
    required this.caja,
    required this.status,
  });

  factory OperatorTemplate.fromJson(Map<String, dynamic> json) {
    String s(String key) => (json[key] ?? '').toString();
    return OperatorTemplate(
      id: json['id'] as int,
      transporterId: (json['transporter_id'] as num?)?.toInt(),
      isActive: json['is_active'] != false,
      linea: s('linea'),
      unidad: s('unidad'),
      operador: s('operador'),
      placas: s('placas'),
      trayecto: s('trayecto'),
      planta: s('planta'),
      caja: s('caja'),
      status: s('status'),
    );
  }

  /// Bloque de texto a compartir (mismo formato que la web).
  String get text => 'Línea: $linea\n'
      'Unidad: $unidad\n'
      'Operador: $operador\n'
      'Placas: $placas\n'
      'Trayecto: $trayecto\n'
      'Planta: $planta\n'
      'Caja: $caja\n'
      'Status: $status';

  bool matches(String query) {
    final q = query.toLowerCase();
    return [linea, unidad, operador, placas, planta, caja]
        .any((v) => v.toLowerCase().contains(q));
  }
}

/// Varias plantillas separadas igual que en la web.
String joinTemplates(Iterable<OperatorTemplate> items) =>
    items.map((t) => t.text).join('\n\n-\n\n');
