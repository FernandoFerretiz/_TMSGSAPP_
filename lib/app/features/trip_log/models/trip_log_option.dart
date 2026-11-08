/// Opción de estatus de la bitácora del viaje. Las opciones las administra el
/// backoffice (GET /api/mobile/trip-log/options); "Otro" es fija en la app y
/// abre un campo de texto libre.
class TripLogOption {
  final int? id;
  final String name;
  final String icon;
  final bool requiresComment;
  final bool isOther;

  const TripLogOption({
    this.id,
    required this.name,
    this.icon = '📍',
    this.requiresComment = false,
    this.isOther = false,
  });

  factory TripLogOption.fromJson(Map<String, dynamic> json) => TripLogOption(
        id: json['id'] as int?,
        name: (json['name'] ?? '').toString(),
        icon: (json['icon'] ?? '📍').toString(),
        requiresComment: json['requires_comment'] == true,
      );

  static const other = TripLogOption(
    name: 'Otro',
    icon: '✏️',
    requiresComment: true,
    isOther: true,
  );
}
