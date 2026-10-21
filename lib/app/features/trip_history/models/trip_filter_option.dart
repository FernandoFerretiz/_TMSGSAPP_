/// Opción simple id+nombre para los selects de filtro (transportista,
/// operador) del historial de eventos — ver TripHistoryService.getFilterOptions().
class TripFilterOption {
  final int id;
  final String name;

  const TripFilterOption({required this.id, required this.name});

  factory TripFilterOption.fromJson(Map<String, dynamic> json) =>
      TripFilterOption(
        id: json['id'] as int,
        name: (json['name'] ?? '').toString(),
      );

  @override
  bool operator ==(Object other) =>
      other is TripFilterOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class TripFilterOptions {
  final List<TripFilterOption> transporters;
  final List<TripFilterOption> operators;

  const TripFilterOptions({
    this.transporters = const [],
    this.operators = const [],
  });

  factory TripFilterOptions.fromJson(Map<String, dynamic> json) =>
      TripFilterOptions(
        transporters: ((json['transporters'] as List?) ?? [])
            .map((e) => TripFilterOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        operators: ((json['operators'] as List?) ?? [])
            .map((e) => TripFilterOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Filtros activos de la lista de viajes — transportista/operador exactos
/// más rango de fecha de finalización (completion_datetime en el backend).
class TripHistoryFilters {
  final TripFilterOption? transporter;
  final TripFilterOption? operator;
  final DateTime? completionDateFrom;
  final DateTime? completionDateTo;

  const TripHistoryFilters({
    this.transporter,
    this.operator,
    this.completionDateFrom,
    this.completionDateTo,
  });

  bool get isEmpty =>
      transporter == null &&
      operator == null &&
      completionDateFrom == null &&
      completionDateTo == null;

  int get activeCount => [
        transporter,
        operator,
        completionDateFrom,
        completionDateTo,
      ].where((e) => e != null).length;

  TripHistoryFilters copyWith({
    TripFilterOption? Function()? transporter,
    TripFilterOption? Function()? operator,
    DateTime? Function()? completionDateFrom,
    DateTime? Function()? completionDateTo,
  }) {
    return TripHistoryFilters(
      transporter: transporter != null ? transporter() : this.transporter,
      operator: operator != null ? operator() : this.operator,
      completionDateFrom: completionDateFrom != null
          ? completionDateFrom()
          : this.completionDateFrom,
      completionDateTo:
          completionDateTo != null ? completionDateTo() : this.completionDateTo,
    );
  }

  Map<String, dynamic> toQueryParameters() {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return {
      if (transporter != null) 'transporter_id': transporter!.id,
      if (operator != null) 'operator_id': operator!.id,
      if (completionDateFrom != null)
        'completion_date_from': fmt(completionDateFrom!),
      if (completionDateTo != null) 'completion_date_to': fmt(completionDateTo!),
    };
  }
}
